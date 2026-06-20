using Toybox.System;
using Toybox.Background;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Lang;

// Background service: runs roughly every 5 minutes (when a URL is set),
// GETs a small JSON object from the coach server, and hands it back to the
// app via Background.exit(). Phone must be in BLE range for this to succeed;
// on failure the face simply keeps showing the last value / placeholders.
//
// Expected JSON shape (all keys optional):
//   { "streak": 12, "smokeFreeDays": 8, "toGoalKg": -9.2, "deficitKcal": 380 }

// Effective coach URL: a user-set CoachApiUrl property wins; if it's empty (the
// usual case for a USB-sideloaded face, which has NO phone settings UI), fall
// back to the URL baked in at build time (Secret.FACE_URL, gitignored). Empty
// string => run as a pure native face (no background calls).
(:background)
function coachUrl() as Lang.String {
    var url = Application.Properties.getValue("CoachApiUrl");
    if (url != null && (url instanceof Lang.String) && url.length() > 0) {
        return url;
    }
    return Secret.FACE_URL;
}

(:background)
class CoachBackground extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
        var url = coachUrl();
        if (url.length() == 0) {
            Background.exit(null);
            return;
        }
        Communications.makeWebRequest(
            url,
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => { "Accept" => "application/json" },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Toybox.PersistedContent.Iterator or Null
    ) as Void {
        if (responseCode == 200 && data != null) {
            Background.exit(data);
        } else {
            Background.exit(null);
        }
    }
}
