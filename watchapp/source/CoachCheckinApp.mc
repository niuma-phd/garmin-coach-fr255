import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Background;
import Toybox.System;
import Toybox.Time;

// Interactive coach check-in app. Foreground = menus/countdown/alerts;
// background ServiceDelegate = 5-min sedentary poll + throttled queue flush.
// NOT annotated (:background) as a whole — only the service + CoachNet are, so
// the UI code is excluded from the background scope (where WatchUi is absent).
class CoachCheckinApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
        coachNet().deviceId();   // pin a stable device id on first run
        registerBg();
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    // Entry view: smoking-first main menu, UNLESS the background just flagged a
    // fresh sedentary nudge (then open the STAND alert).
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var wake = Application.Storage.getValue("wakeMove");
        if (wake != null) {
            Application.Storage.deleteValue("wakeMove");
            var fresh = (Time.now().value() - wake) < 600;  // ignore stale flags (>10 min)
            // Re-check sleep here too: a wake requested while awake may be honored by the
            // OS minutes later, after the user dozed off — don't even light the screen then.
            if (fresh && proactiveAllowed()) {
                var v = new SedentaryView();
                return [v, new SedentaryDelegate(v)];
            }
        }
        return [buildMainMenu(), new MainMenuDelegate()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new CoachService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        // Background flush already trims the Storage queue in place; nothing to merge.
    }

    function registerBg() as Void {
        if (!(Toybox has :Background)) { return; }
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(300));  // 5-min floor
        }
    }
}
