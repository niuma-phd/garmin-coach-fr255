import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;

const COUNTDOWN_SECS = 90;

// Set by GiveUpConfirm on YES; consumed by CountdownView.onShow to exit cleanly
// after the confirmation dismisses (avoids fragile double-pop ordering).
var gGiveUp as Lang.Boolean = false;

// Urge interception: optimistically log "resisted" the instant the user chooses
// to ride it out (MVP Q4 — kept even on give-up; no count, no cancel event), then
// run a visible 90s countdown. Reaching 0 = a small win cue.
class CountdownView extends WatchUi.View {
    var _timer as Timer.Timer?;
    var _left as Lang.Number;
    var _logged as Lang.Boolean;

    function initialize() {
        View.initialize();
        _left = COUNTDOWN_SECS;
        _logged = false;
    }

    function onShow() as Void {
        if (gGiveUp) {            // returned here after GIVE UP? → YES; leave countdown
            gGiveUp = false;
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        if (!_logged) {
            logSmoke("resisted");
            _logged = true;
        }
        _timer = new Timer.Timer();
        _timer.start(method(:tick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function tick() as Void {
        _left = _left - 1;
        if (_left <= 0) {
            if (_timer != null) { _timer.stop(); _timer = null; }
            vibe(:win);
            WatchUi.switchToView(new ToastView("挺住了"), new ToastDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2 - 12;
        var pct = _left.toFloat() / COUNTDOWN_SECS;

        dc.setPenWidth(10);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        var endDeg = 90 - 360 * pct;
        if (endDeg < 0) { endDeg += 360; }
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 6, Graphics.FONT_SYSTEM_NUMBER_MEDIUM, _left.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 40, Graphics.FONT_SYSTEM_XTINY, "撑住", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class CountdownDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    // BACK during countdown → confirm exit (the resist is already logged; MVP keeps it).
    function onBack() as Lang.Boolean {
        WatchUi.pushView(new WatchUi.Confirmation("放弃？"), new GiveUpConfirm(), WatchUi.SLIDE_LEFT);
        return true;
    }
}

class GiveUpConfirm extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }
    function onResponse(resp as WatchUi.Confirm) as Lang.Boolean {
        if (resp == WatchUi.CONFIRM_YES) {
            gGiveUp = true;  // countdown's onShow will pop itself once this dialog closes
        }
        return true;
    }
}
