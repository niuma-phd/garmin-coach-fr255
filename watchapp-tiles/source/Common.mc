import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Timer;

// Shared foreground helpers for the tile apps: log an action (enqueue + immediate
// foreground flush; offline → stays queued, retried next launch), a vibe cue, and a
// brief auto-dismissing toast (popping the last view exits the app back to the face).

function logSmoke(value as Lang.String) as Void {
    coachNet().enqueue({ "action" => "smoke", "value" => value });
    coachNet().flush();
}

function logCheckin(item as Lang.String, value as Lang.String) as Void {
    coachNet().enqueue({ "action" => "checkin", "item" => item, "value" => value });
    coachNet().flush();
}

function vibe(kind as Lang.Symbol) as Void {
    if (!(Attention has :vibrate)) { return; }
    var prof;
    if (kind == :win) {
        prof = [new Attention.VibeProfile(80, 200), new Attention.VibeProfile(0, 90), new Attention.VibeProfile(80, 200)];
    } else if (kind == :alert) {
        prof = [new Attention.VibeProfile(100, 400)];
    } else {  // :ok
        prof = [new Attention.VibeProfile(60, 200)];
    }
    Attention.vibrate(prof);
}

// Brief "已记录 <msg>" that auto-dismisses; popping the last view exits the app.
class ToastView extends WatchUi.View {
    var _msg as Lang.String;
    var _timer as Timer.Timer?;
    function initialize(msg as Lang.String) {
        View.initialize();
        _msg = msg;
    }
    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:done), 1100, false);
    }
    function onHide() as Void {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }
    function done() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 34, Graphics.FONT_SYSTEM_SMALL, "已记录", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 2, Graphics.FONT_SYSTEM_MEDIUM, _msg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class ToastDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
