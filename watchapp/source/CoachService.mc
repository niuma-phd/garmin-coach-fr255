import Toybox.Background;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.UserProfile;

// Background entry: runs every ~5 min. Two jobs:
//   1) sedentary nudge — if the move bar has built up during waking hours,
//      flag + requestApplicationWake so the foreground STAND alert can fire;
//   2) throttled queue flush — push any offline-queued check-ins.
// Only this class + CoachNet live in the background scope (no WatchUi here).
(:background)
class CoachService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        checkSedentary();
        // flush returns true iff a request was issued; if so, onReceive calls
        // Background.exit once it settles. Otherwise end the run now.
        if (!coachNet().flush(true)) {
            Background.exit(null);
        }
    }

    function checkSedentary() as Void {
        if (!proactiveAllowed()) { return; }   // never disturb during sleep / DND

        if (!(Toybox has :ActivityMonitor)) { return; }
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :moveBarLevel)) { return; }
        var lvl = info.moveBarLevel;
        if (lvl == null || lvl < 1) { return; }    // move bar not raised yet

        var nowS = Time.now().value();
        var last = Application.Storage.getValue("lastMove") as Lang.Number?;
        if (last != null && (nowS - last) < 1800) { return; }  // at most one nudge / 30 min
        Application.Storage.setValue("lastMove", nowS);

        Application.Storage.setValue("wakeMove", nowS);
        if (Background has :requestApplicationWake) {
            Background.requestApplicationWake("MOVE");
        }
    }
}

// True only when it's OK to proactively disturb the user (wake the app / vibrate).
// Shared by the background sedentary check AND the foreground alert/view gate, so it
// carries NO (:background) tag — it must live in both scopes (no excludeAnnotations).
// Returns FALSE during sleep so the watch stays completely silent:
//   · DeviceSettings.isSleepMode  — Garmin Sleep Mode (the watch's own awake/asleep call)
//   · DeviceSettings.doNotDisturb — DND on (manual, naps, meetings)
//   · outside the user's configured wake..sleep window (UserProfile, belt-and-suspenders)
function proactiveAllowed() as Lang.Boolean {
    var ds = System.getDeviceSettings();
    if ((ds has :isSleepMode) && ds.isSleepMode) { return false; }
    if ((ds has :doNotDisturb) && ds.doNotDisturb) { return false; }

    if (Toybox has :UserProfile) {
        var p = UserProfile.getProfile();
        if (p != null && (p has :sleepTime) && (p has :wakeTime)
                && p.sleepTime != null && p.wakeTime != null) {
            var ct = System.getClockTime();
            var now = ct.hour * 3600 + ct.min * 60 + ct.sec;
            var sleep = p.sleepTime.value();   // seconds since midnight
            var wake = p.wakeTime.value();
            if (sleep == wake) { return true; }  // zero-width window is undefined → treat as awake
            var asleep;
            if (sleep > wake) {                  // bedtime before midnight: awake [wake, sleep), window wraps
                asleep = (now >= sleep) || (now < wake);
            } else {                             // bedtime after midnight (e.g. sleep 00:30 .. wake 07:00), no wrap
                asleep = (now >= sleep) && (now < wake);
            }
            if (asleep) { return false; }
        }
    }
    return true;
}
