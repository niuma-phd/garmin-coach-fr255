import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Background;
import Toybox.System;
import Toybox.Time;

// Interactive coach check-in app. Foreground = menus / urge countdown;
// background ServiceDelegate = throttled flush of the offline check-in queue.
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

    // Entry view: the main check-in menu (smoking actions first).
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
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
