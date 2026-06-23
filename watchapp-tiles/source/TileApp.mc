import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

// One shared app class for all 4 single-action tiles. The action is fixed per build by
// Tile.ACTION (injected into source-gen/TileFg.mc); the manifest gives each tile a distinct
// app id + name. Launching opens straight into the action; the glance card (one per app —
// CIQ allows only one) shows the designed launcher icon + a text label (TileGlanceView).
//
// GLANCE SAFETY — the bug that cost several device rounds (CIQ_LOG ground truth):
// on a non-music FR255 the glance runs through the off-screen "Background UI Update"
// lifecycle, which starts the app in the restricted (:glance) VM and calls
// AppBase.onStart() → getGlanceView() → GlanceView.onUpdate(). onStart() therefore MUST
// NOT invoke any symbol that isn't compiled into the glance scope. The old onStart called
// the foreground-only coachNet(), which crashed every tile in glance with
//   "Illegal Access (Out of Bounds): Failed invoking <symbol>"  (stack: TileApp.onStart)
// → the firmware silently fell back to the bare launcher icon, so the glance text never
// drew. Fix: keep onStart empty; do foreground-only setup in getInitialView (never run in
// glance). The earlier "glance needs a Background service" theory was WRONG — the SDK's
// glance lifecycle is not gated on a background presence (see Glances.html) — so the tiles
// are pure foreground apps again (no TileService / no Background permission).
class TileApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Runs in BOTH a foreground launch AND the glance lifecycle → must stay glance-safe:
    // do NOT call coachNet() or any other foreground-only symbol here.
    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    // Foreground entry — never called in glance mode, so foreground code is safe here.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        coachNet().deviceId();   // pin a stable device id on first foreground run
        var a = Tile.ACTION;
        if (a.equals("smoked")) {
            var sv = new SmokedConfirmView();
            return [sv, new SmokedConfirmDelegate(sv)];
        } else if (a.equals("hold")) {
            return [new CountdownView(), new CountdownDelegate()];
        }
        return [new TileActionView(), new TileActionDelegate()];
    }

    // CIQ allows exactly one glance per app → one card per tile. Draws text only
    // (TileGlanceView); the designed icon is the launcher PNG the system shows in the row.
    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new TileGlanceView()];
    }
}
