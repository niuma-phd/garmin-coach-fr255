import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Shown when the background poll wakes the app for a sit-too-long nudge.
// Vibrates on show; any confirm press logs sit_done=done.
class SedentaryView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }
    function onShow() as Void {
        if (proactiveAllowed()) { vibe(:alert); }  // stay silent if user fell asleep meanwhile
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 42, Graphics.FONT_SYSTEM_SMALL, "久坐了", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_SYSTEM_LARGE, "起来动",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 38, Graphics.FONT_SYSTEM_XTINY, "按键 = 已站起", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SedentaryDelegate extends WatchUi.BehaviorDelegate {
    var _view as SedentaryView;
    function initialize(view as SedentaryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }
    // START/SELECT = acknowledge stood up
    function onSelect() as Lang.Boolean {
        logCheckin("sit_done", "done");
        vibe(:ok);
        WatchUi.switchToView(new ToastView("站起来"), new ToastDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
    // BACK = dismiss without logging
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
