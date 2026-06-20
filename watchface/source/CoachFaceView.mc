using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.Application;

// Coach Face — ZEN / 极简 layout for the Forerunner 255 (round MIP, 260x260, 64
// colors, always-on), Chinese-first. One truth dominates: consecutive smoke-free
// days, a giant green number. Everything else whispers.
//
//   time (digits, top)            ← no label
//   「坚持」                        ← the only emotional label
//   128  (HERO, NUMBER_HOT green)
//   「天」                          ← single-char unit
//   ♥ 62   ⚡ 78   ▮ 84%          ← icon+number vitals (icons drawn in code,
//                                     never depend on a CJK font → never boxes)
//   6月20日 周五                    ← Chinese date footer
//   + rim step ring & a bottom sedentary wedge (orange/red), native + offline.
//
// Why icons for the vitals: a Chinese label like 心率 sits on a square em-box and
// is ~2-3x wider than "HR", so text labels crowd a small round screen. Icons keep
// the face uncluttered AND render regardless of the device language/font. Chinese
// is spent only where it earns its width: the hero label and the date.
class CoachFaceView extends WatchUi.WatchFace {

    private var _w;
    private var _h;
    private var _cx;
    private var _cy;
    private var _accent;
    private var _wk as Lang.Array<Lang.String>;

    function initialize() {
        WatchFace.initialize();
        _w = 260;
        _h = 260;
        _cx = 130;
        _cy = 130;
        _accent = Graphics.COLOR_GREEN;
        _wk = ["日", "一", "二", "三", "四", "五", "六"];
    }

    function onLayout(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
    }

    function onShow() {
    }

    function onUpdate(dc) {
        _accent = readAccent();
        var coach = readCoach();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawStepRing(dc);     // rim ring + sedentary wedge (native, offline)
        drawClock(dc);        // top digits, no label
        drawHero(dc, coach);  // 坚持 / big number / 天
        drawStats(dc);        // ♥ / ⚡ / ▮  icon+number vitals
        drawDate(dc);         // Chinese date footer
    }

    function onEnterSleep() {
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        WatchUi.requestUpdate();
    }

    // ---- top clock (secondary in zen, but still readable) ------------------

    function drawClock(dc) {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var str = hour.format("%02d") + ":" + clock.min.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 15 / 100, Graphics.FONT_SYSTEM_NUMBER_MILD, str,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- hero: the one number that matters ---------------------------------

    function drawHero(dc, coach) {
        var heroMetric = readHeroMetric();   // 0 = smoke-free days, 1 = kg-to-goal
        var val = null;
        if (coach != null) {
            val = numOrNull(coach, (heroMetric == 1) ? "toGoalKg" : "smokeFreeDays");
        }
        var labelY = _h * 31 / 100;
        var numY = _h * 49 / 100;
        var unitY = _h * 66 / 100;

        if (val == null) {
            // day-one / degraded: a calm gray "--", no broken giant glyph
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, labelY, Graphics.FONT_SYSTEM_SMALL, "同步中",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(_cx, numY, Graphics.FONT_SYSTEM_NUMBER_MILD, "--",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var label = (heroMetric == 1) ? "减重" : "坚持";
        var unit = (heroMetric == 1) ? "公斤" : "天";
        var numStr = (heroMetric == 1) ? val.format("%.1f") : val.format("%d");
        var numColor = (heroMetric == 1) ? Graphics.COLOR_ORANGE : _accent;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, labelY, Graphics.FONT_SYSTEM_SMALL, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(numColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, numY, Graphics.FONT_SYSTEM_NUMBER_HOT, numStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, unitY, Graphics.FONT_SYSTEM_SMALL, unit,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- vitals: heart rate / Body Battery / watch battery -----------------

    function drawStats(dc) {
        var y = _h * 79 / 100;
        var hr = readHeartRate();
        var bb = readSensorLatest(:getBodyBatteryHistory);
        var batt = System.getSystemStats().battery;
        var battN = (batt != null) ? batt.toNumber() : 0;
        var bc = (battN <= 10) ? Graphics.COLOR_RED
               : ((battN <= 25) ? Graphics.COLOR_ORANGE : Graphics.COLOR_GREEN);

        drawStat(dc, _w * 27 / 100, y, :hr,   (hr == null) ? null : hr.format("%d"), Graphics.COLOR_RED,  0);
        drawStat(dc, _w * 50 / 100, y, :bb,   (bb == null) ? null : bb.format("%d"), Graphics.COLOR_BLUE, 0);
        drawStat(dc, _w * 73 / 100, y, :batt, battN.format("%d") + "%",              bc,                  battN);
    }

    // icon + number, the pair centered on (cx, cy)
    function drawStat(dc, cx, cy, kind, valStr, iconColor, pct) {
        var degraded = (valStr == null);
        var txt = degraded ? "--" : valStr;
        var f = Graphics.FONT_SYSTEM_TINY;
        var numW = dc.getTextWidthInPixels(txt, f);
        var iconW = (kind == :batt) ? 20 : 16;
        var gap = 3;
        var total = iconW + gap + numW;
        var sx = cx - total / 2;
        var icx = sx + iconW / 2;
        var ic = degraded ? Graphics.COLOR_DK_GRAY : iconColor;

        if (kind == :hr) {
            drawHeart(dc, icx, cy, 8, ic);
        } else if (kind == :bb) {
            drawBolt(dc, icx, cy, 9, ic);
        } else {
            drawBatteryIcon(dc, icx, cy, ic, pct);
        }

        dc.setColor(degraded ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx + iconW + gap, cy, f, txt,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setPenWidth(1);
    }

    // ---- icon primitives (drawn in code — font-independent) ----------------

    function drawHeart(dc, hx, hy, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = (s * 0.55).toNumber();
        var off = (s * 0.45).toNumber();
        var up = (s * 0.30).toNumber();
        dc.fillCircle(hx - off, hy - up, r);
        dc.fillCircle(hx + off, hy - up, r);
        dc.fillPolygon([
            [hx - s, hy - (s * 0.15).toNumber()],
            [hx + s, hy - (s * 0.15).toNumber()],
            [hx, hy + s]
        ]);
    }

    function drawBolt(dc, bx, by, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var w = (s * 0.7).toNumber();
        var m = (s * 0.15).toNumber();
        dc.fillPolygon([
            [bx + (w * 0.2).toNumber(), by - s],
            [bx - w,                    by + m],
            [bx - (w * 0.1).toNumber(), by + m],
            [bx - (w * 0.2).toNumber(), by + s],
            [bx + w,                    by - m],
            [bx + (w * 0.1).toNumber(), by - m]
        ]);
    }

    function drawBatteryIcon(dc, bx, by, color, pct) {
        var w = 18;
        var h = 10;
        var x = bx - w / 2;
        var y = by - h / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, y, w, h);
        dc.fillRectangle(x + w, y + h / 4, 2, h / 2);   // terminal nub
        var fillW = ((w - 2) * pct / 100).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(x + 1, y + 1, fillW, h - 2);
        }
    }

    // ---- Chinese date footer (deterministic; not locale-dependent) ---------

    function drawDate(dc) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var idx = info.day_of_week - 1;     // 1=Sun..7=Sat with FORMAT_SHORT
        if (idx < 0 || idx > 6) { idx = 0; }
        var str = info.month.format("%d") + "月" + info.day.format("%d") + "日 周" + _wk[idx];
        var color = Graphics.COLOR_DK_GRAY;
        // stale-coach tag: last successful fetch older than 36h
        var ts = Application.Storage.getValue("coachTs");
        if (ts != null && ts instanceof Lang.Number && (Time.now().value() - ts) > 129600) {
            str = str + " 旧";
            color = Graphics.COLOR_ORANGE;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_SYSTEM_XTINY, str,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- rim step ring + sedentary wedge -----------------------------------

    function drawStepRing(dc) {
        var am = ActivityMonitor.getInfo();
        var steps = (am != null && am.steps != null) ? am.steps : 0;
        var goal = readStepGoal(am);
        var pct = 0.0;
        if (goal > 0) {
            pct = steps.toFloat() / goal.toFloat();
            if (pct > 1.0) { pct = 1.0; }
        }
        var r = (_w / 2) - 6;

        dc.setPenWidth(8);
        // track
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r);
        // progress (green, clockwise from 12 o'clock)
        if (pct > 0.0) {
            dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
            if (pct >= 0.999) {
                dc.drawCircle(_cx, _cy, r);
            } else {
                var endDeg = 90.0 - 360.0 * pct;
                if (endDeg < 0) { endDeg += 360.0; }
                dc.drawArc(_cx, _cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg);
            }
        }
        // sedentary wedge at 6 o'clock — grows with the move bar
        var lvl = (am != null && am.moveBarLevel != null) ? am.moveBarLevel : 0;
        if (lvl > 5) { lvl = 5; }
        if (lvl > 0) {
            var span = 18 * lvl;
            dc.setColor((lvl >= 3) ? Graphics.COLOR_RED : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(_cx, _cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 270 - span, 270 + span);
        }
        dc.setPenWidth(1);
    }

    // ---- data readers ------------------------------------------------------

    function readCoach() {
        var c = Application.Storage.getValue("coach");
        if (c != null && c instanceof Lang.Dictionary) { return c; }
        return null;
    }

    function readHeroMetric() {
        var v = Application.Properties.getValue("HeroMetric");
        if (v != null && v instanceof Lang.Number) { return v; }
        return 0;
    }

    function readStepGoal(am) {
        if (am != null && am.stepGoal != null && am.stepGoal > 0) {
            return am.stepGoal;
        }
        var p = Application.Properties.getValue("StepGoal");
        return (p != null && p instanceof Lang.Number && p > 0) ? p : 8000;
    }

    function readHeartRate() {
        var act = Activity.getActivityInfo();
        if (act != null && act.currentHeartRate != null) {
            return act.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            if (it != null) {
                var s = it.next();
                if (s != null && s.heartRate != null
                        && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    return s.heartRate;
                }
            }
        }
        return null;
    }

    function readSensorLatest(which) {
        if (!(Toybox has :SensorHistory)) {
            return null;
        }
        var it = null;
        if (which == :getBodyBatteryHistory
                && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            it = Toybox.SensorHistory.getBodyBatteryHistory({ :period => 1 });
        } else if (which == :getStressHistory
                && (Toybox.SensorHistory has :getStressHistory)) {
            it = Toybox.SensorHistory.getStressHistory({ :period => 1 });
        }
        if (it != null) {
            var s = it.next();
            if (s != null && s.data != null) {
                return s.data.toNumber();
            }
        }
        return null;
    }

    function readAccent() {
        var c = Application.Properties.getValue("AccentColor");
        if (c != null && c instanceof Lang.Number) {
            return c;
        }
        return Graphics.COLOR_GREEN;
    }

    function numOrNull(dict, key) {
        if (dict != null && dict instanceof Lang.Dictionary
                && dict.hasKey(key) && dict[key] != null) {
            var v = dict[key];
            if (v instanceof Lang.Number || v instanceof Lang.Float) { return v; }
        }
        return null;
    }
}
