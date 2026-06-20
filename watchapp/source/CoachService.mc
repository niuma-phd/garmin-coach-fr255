import Toybox.Background;
import Toybox.System;
import Toybox.Lang;

// Background entry: runs every ~5 min. Sole job now = a best-effort flush of the
// offline check-in queue (smoking / water events that failed to upload in the
// foreground). Only this class + CoachNet live in the background scope.
//
// Sedentary nudging was intentionally REMOVED: the FR255 already has a native
// Move alert, and the move bar is derivable from Garmin Connect — so per the
// principle "don't add a manual feature for what the watch already tracks", the
// coach backend reads sit/activity/sleep state from native data instead of a
// custom watch check-in.
(:background)
class CoachService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // 夜间停轮询 / 省电 (§5, issue #5): skip the offline-queue retry while the
        // watch is in sleep mode — Garmin's own "asleep" signal, no hardcoded hours.
        // Late events still upload on the next awake wake; the backend dates by
        // ts_local so nothing is mis-dated.
        var ds = System.getDeviceSettings();
        if ((ds has :isSleepMode) && ds.isSleepMode) {
            Background.exit(null);
            return;
        }
        // flush returns true iff a request was issued; if so, onReceive calls
        // Background.exit once it settles. Otherwise end the run now.
        if (!coachNet().flush(true)) {
            Background.exit(null);
        }
    }
}
