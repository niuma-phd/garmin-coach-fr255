import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Communications;
import Toybox.Application;
import Toybox.Math;
import Toybox.Background;

// ── tunables ──────────────────────────────────────────────────────────────
(:background) const Q_KEY = "q";          // Storage key: pending event queue (Array<Dict>)
(:background) const Q_MAX = 60;           // hard cap; oldest trimmed past this
(:background) const FLUSH_THROTTLE = 600; // background won't re-POST within 10 min

// Singleton per VM (foreground and background are separate VMs → each builds its own).
(:background) var gNet as CoachNet? = null;

(:background)
function coachNet() as CoachNet {
    if (gNet == null) { gNet = new CoachNet(); }
    return gNet as CoachNet;
}

// Offline-first event queue + idempotent batch upload to the coach ingest endpoint.
// Contract: POST {events:[{event_id, ts_local, tz_offset_min, device_id, value:{...}}]}
//           Bearer auth; 200 → {applied,duplicates,rejected[{event_id,reason}]}.
// Any of the three buckets means "stop retrying that event" → trim from queue.
(:background)
class CoachNet {
    var _busy as Lang.Boolean;   // a request is in flight (avoid overlap)
    var _bg as Lang.Boolean;     // current in-flight request was started from the background VM

    function initialize() {
        _busy = false;
        _bg = false;
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

    // UUID-ish idempotency key: device salt + monotonic persisted counter.
    // Survives reboot (counter in Storage); never collides across this device.
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

    // ISO-8601 with explicit offset, e.g. 2026-06-20T09:00:00+08:00
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

    function pending() as Lang.Number {
        return _queue().size();
    }

    // value = the inner {action, ...} dict; wraps it into a full event and stores it.
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

    // ── send ──────────────────────────────────────────────────────────────
    // Returns true iff a web request was actually issued (caller may need to know
    // so the background VM can defer Background.exit to onReceive).
    function flush(isBackground as Lang.Boolean) as Lang.Boolean {
        if (_busy) { return false; }
        var q = _queue();
        if (q.size() == 0) { return false; }
        if (Secret.COACH_TOKEN.equals("")) { return false; }  // not provisioned
        if (isBackground) {
            var last = Application.Storage.getValue("lastSend") as Lang.Number?;
            var nowS = Time.now().value();
            if (last != null && (nowS - last) < FLUSH_THROTTLE) { return false; }
        }
        _busy = true;
        _bg = isBackground;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Authorization" => "Bearer " + Secret.COACH_TOKEN
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(Secret.COACH_URL, { "events" => q }, options, method(:onReceive));
        return true;
    }

    function onReceive(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        _busy = false;
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            _trim(data);
            Application.Storage.setValue("lastSend", Time.now().value());
        }
        // else: -104 offline / 401 / 5xx → keep queue, retry on next flush.
        if (_bg) {
            _bg = false;
            Background.exit(null);  // end the background run now the upload settled
        }
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
