import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Communications;
import Toybox.Application;
import Toybox.Math;

// Trimmed, FOREGROUND-ONLY offline queue + idempotent upload for the single-action
// tile apps. No background service (these apps are launched, fire one action, and
// auto-close), so events are sent on launch; anything not confirmed stays queued in
// this app's Storage and is retried (+ deduped server-side by event_id) next launch.
// Each tile app has its OWN app id → its OWN Storage/queue/counter (CIQ isolates
// Storage per app); the backend is idempotent so cross-app duplicates are harmless.

const Q_KEY = "q";          // Storage key: pending event queue (Array<Dict>)
const Q_MAX = 60;           // hard cap; oldest trimmed past this

var gNet as CoachNet? = null;

function coachNet() as CoachNet {
    if (gNet == null) { gNet = new CoachNet(); }
    return gNet as CoachNet;
}

class CoachNet {
    var _busy as Lang.Boolean;

    function initialize() {
        _busy = false;
    }

    // ── identity / time ───────────────────────────────────────────────────
    function deviceId() as Lang.String {
        var v = Application.Storage.getValue("devId");
        if (v != null) { return v as Lang.String; }
        var id;
        var ds = System.getDeviceSettings();
        if (ds has :uniqueIdentifier && ds.uniqueIdentifier != null) {
            id = ds.uniqueIdentifier;
        } else {
            id = "fr255-" + (Math.rand() % 1000000).format("%06d");
        }
        Application.Storage.setValue("devId", id);
        return id as Lang.String;
    }

    // device salt + monotonic persisted counter → collision-safe idempotency key.
    function nextEventId() as Lang.String {
        var stored = Application.Storage.getValue("eid");
        var c = (stored == null) ? 0 : stored as Lang.Number;
        c = c + 1;
        Application.Storage.setValue("eid", c);
        return deviceId() + "-" + c.format("%d");
    }

    function tzOffsetSec() as Lang.Number {
        return System.getClockTime().timeZoneOffset;
    }

    // ISO-8601 with explicit offset, e.g. 2026-06-22T09:00:00+08:00
    function tsLocal() as Lang.String {
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var off = tzOffsetSec();
        var sign = (off < 0) ? "-" : "+";
        var a = (off < 0) ? -off : off;
        var oh = a / 3600;
        var om = (a % 3600) / 60;
        return g.year.format("%04d") + "-" + g.month.format("%02d") + "-" + g.day.format("%02d")
            + "T" + g.hour.format("%02d") + ":" + g.min.format("%02d") + ":" + g.sec.format("%02d")
            + sign + oh.format("%02d") + ":" + om.format("%02d");
    }

    // ── queue ─────────────────────────────────────────────────────────────
    function _queue() as Lang.Array {
        var q = Application.Storage.getValue(Q_KEY);
        if (q == null) { return []; }
        return q as Lang.Array;
    }

    function enqueue(value as Lang.Dictionary) as Void {
        var ev = {
            "event_id" => nextEventId(),
            "ts_local" => tsLocal(),
            "tz_offset_min" => tzOffsetSec() / 60,
            "device_id" => deviceId(),
            "value" => value
        };
        var q = _queue();
        q.add(ev);
        while (q.size() > Q_MAX) {
            q = q.slice(1, q.size());  // drop oldest
        }
        Application.Storage.setValue(Q_KEY, q);
    }

    // ── send (foreground) ───────────────────────────────────────────────────
    function flush() as Void {
        if (_busy) { return; }
        var q = _queue();
        if (q.size() == 0) { return; }
        if (Secret.COACH_TOKEN.equals("")) { return; }  // not provisioned
        _busy = true;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Authorization" => "Bearer " + Secret.COACH_TOKEN
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(Secret.COACH_URL, { "events" => q }, options, method(:onReceive));
    }

    function onReceive(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        _busy = false;
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            _trim(data);
        }
        // else: -104 offline / 401 / 5xx → keep queue, retry on next launch.
    }

    // Remove every queued event whose id appears in applied|duplicates|rejected.
    function _trim(data as Lang.Dictionary) as Void {
        var done = {};
        _collect(done, data["applied"]);
        _collect(done, data["duplicates"]);
        var rej = data["rejected"];
        if (rej instanceof Lang.Array) {
            for (var i = 0; i < rej.size(); i++) {
                var r = rej[i];
                if (r instanceof Lang.Dictionary && r["event_id"] != null) {
                    done.put(r["event_id"], true);
                }
            }
        }
        if (done.size() == 0) { return; }
        var q = _queue();
        var keep = [];
        for (var i = 0; i < q.size(); i++) {
            var item = q[i] as Lang.Dictionary;
            if (!done.hasKey(item["event_id"])) { keep.add(item); }
        }
        Application.Storage.setValue(Q_KEY, keep);
    }

    function _collect(into as Lang.Dictionary, arr as Lang.Array or Null) as Void {
        if (arr instanceof Lang.Array) {
            for (var i = 0; i < arr.size(); i++) {
                into.put(arr[i], true);
            }
        }
    }
}
