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
        // flush returns true iff a request was issued; if so, onReceive calls
        // Background.exit once it settles. Otherwise end the run now.
        if (!coachNet().flush(true)) {
            Background.exit(null);
        }
    }
}
