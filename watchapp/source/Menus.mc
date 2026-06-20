import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Attention;
import Toybox.System;
import Toybox.Timer;

// ── shared helpers ─────────────────────────────────────────────────────────

// Enqueue + immediate (foreground) flush. Offline → stays queued, retried later.
function logSmoke(value as Lang.String) as Void {
    coachNet().enqueue({ "action" => "smoke", "value" => value });
    coachNet().flush(false);
}
function logCheckin(item as Lang.String, value as Lang.String) as Void {
    coachNet().enqueue({ "action" => "checkin", "item" => item, "value" => value });
    coachNet().flush(false);
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

// ── main menu (Chinese — rendered via the device Noto Sans SC font when the
//    watch language is Simplified Chinese; numbers use the digit fonts) ──────

function buildMainMenu() as WatchUi.Menu2 {
    var m = new WatchUi.Menu2({ :title => "教练" });
    m.addItem(new WatchUi.MenuItem("忍住",   "扛过去了",  :resist, null));
    m.addItem(new WatchUi.MenuItem("撑一下", "倒计时",    :hold,   null));
    m.addItem(new WatchUi.MenuItem("抽了",   "记一支",    :smoked, null));
    m.addItem(new WatchUi.MenuItem("喝水",   "加一杯",    :water,  null));
    return m;
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resist) {
            logSmoke("resisted");
            vibe(:ok);
            WatchUi.pushView(new ToastView("忍住"), new ToastDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :hold) {
            WatchUi.pushView(new CountdownView(), new CountdownDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :smoked) {
            WatchUi.pushView(new WatchUi.Confirmation("记一支？"), new SmokedConfirm(), WatchUi.SLIDE_LEFT);
        } else if (id == :water) {
            logCheckin("water", "1");
            vibe(:ok);
            WatchUi.pushView(new ToastView("喝水 +1"), new ToastDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

// ── confirmations ──────────────────────────────────────────────────────────

class SmokedConfirm extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }
    function onResponse(resp as WatchUi.Confirm) as Lang.Boolean {
        if (resp == WatchUi.CONFIRM_YES) {
            logSmoke("smoked");
            vibe(:ok);
        }
        return true;
    }
}

// ── toast: brief "已记录 <msg>" that auto-dismisses ─────────────────────────

class ToastView extends WatchUi.View {
    var _msg as Lang.String;
    var _timer as Timer.Timer?;
    function initialize(msg as Lang.String) {
        View.initialize();
        _msg = msg;
    }
    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:done), 900, false);
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
