using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Background;
using Toybox.Time;
using Toybox.Lang;

// The whole app class is tagged (:background) so it is included in the
// background scope (needed for getServiceDelegate / onBackgroundData).
(:background)
class CoachFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        registerBackground();
    }

    function onStop(state) {
    }

    // The watch face view.
    function getInitialView() {
        return [ new CoachFaceView() ];
    }

    // Background service that fetches coach metrics from the user's server.
    function getServiceDelegate() {
        return [ new CoachBackground() ];
    }

    // Result delivered from the background service -> persist and redraw.
    function onBackgroundData(data) {
        if (data != null) {
            Application.Storage.setValue("coach", data);
            Application.Storage.setValue("coachTs", Time.now().value());
        }
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        registerBackground();
        WatchUi.requestUpdate();
    }

    // Poll the coach server every 5 minutes, but only if a URL is configured.
    // (5 min is the shortest interval Garmin allows for a watch-face background.)
    function registerBackground() {
        if (!(Toybox has :Background)) {
            return;
        }
        var url = coachUrl();
        if (url.length() > 0) {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        } else {
            try {
                Background.deleteTemporalEvent();
            } catch (e) {
            }
        }
    }
}
