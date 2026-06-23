import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;

// One-shot action screen for the instant tiles (忍住 / 喝水): on show it logs the
// action once, vibrates, shows a brief "已记录" confirmation, then auto-exits to the
// watch face (~1.5s gives the foreground upload time to land before we close).
class TileActionView extends WatchUi.View {
    var _timer as Timer.Timer?;
    var _done as Lang.Boolean;

    function initialize() {
        View.initialize();
        _done = false;
    }

    function onShow() as Void {
        if (!_done) {
            _done = true;
            var a = Tile.ACTION;
            if (a.equals("resist")) {
                logSmoke("resisted");
            } else if (a.equals("water")) {
                logCheckin("water", "1");
            }
            vibe(:ok);
        }
        _timer = new Timer.Timer();
        _timer.start(method(:bye), 1500, false);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function bye() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);   // last view → app exits to face
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var label = Tile.ACTION.equals("water") ? "喝水 +1" : "忍住";
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 34, Graphics.FONT_SYSTEM_SMALL, "已记录", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 2, Graphics.FONT_SYSTEM_MEDIUM, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class TileActionDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

// "抽了" tile: confirm first (防误触). A custom one-view confirm so that after START
// we hold ~1.5s (logs + shows 已记录 + lets the upload land) before exiting; BACK
// cancels without recording. (A system Confirmation would close instantly on YES,
// killing the in-flight upload.)
class SmokedConfirmView extends WatchUi.View {
    var _timer as Timer.Timer?;
    var _recorded as Lang.Boolean;

    function initialize() {
        View.initialize();
        _recorded = false;
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function confirm() as Void {
        if (_recorded) { return; }
        _recorded = true;
        logSmoke("smoked");
        vibe(:ok);
        WatchUi.requestUpdate();
        _timer = new Timer.Timer();
        _timer.start(method(:bye), 1500, false);
    }

    function bye() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_recorded) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 34, Graphics.FONT_SYSTEM_SMALL, "已记录", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 + 2, Graphics.FONT_SYSTEM_MEDIUM, "抽了",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2 - 18, Graphics.FONT_SYSTEM_MEDIUM, "记一支？",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 44, Graphics.FONT_SYSTEM_XTINY, "START 确认 · BACK 取消",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class SmokedConfirmDelegate extends WatchUi.BehaviorDelegate {
    var _view as SmokedConfirmView;
    function initialize(view as SmokedConfirmView) {
        BehaviorDelegate.initialize();
        _view = view;
    }
    function onSelect() as Lang.Boolean {   // START
        _view.confirm();
        return true;
    }
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
