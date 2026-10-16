pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Util.js" as Util

// Night light for X11. Wayland noctalia drives wlr-gamma-control; here we use, in order of
// preference: redshift, gammastep, sct, or plain `xrandr --gamma` on every connected output.
Singleton {
    id: root

    readonly property bool configEnabled: Config.get("nightlight.enabled", false) === true
    readonly property bool enabled: ShellState.get("nightlight_enabled", configEnabled) === true
    readonly property bool forced: ShellState.get("nightlight_force", Config.get("nightlight.force", false)) === true
    readonly property int dayTemp: Number(Config.get("nightlight.temperature_day", 6500))
    readonly property int nightTemp: Number(Config.get("nightlight.temperature_night", 4000))

    property bool isNight: false
    property string backend: ""
    readonly property bool active: forced || (enabled && isNight)
    readonly property int currentTemp: active ? nightTemp : dayTemp

    signal toggled(bool on)

    onCurrentTempChanged: apply()
    onBackendChanged: apply()

    function setEnabled(on) {
        ShellState.set("nightlight_enabled", on === true);
        if (!on)
            ShellState.set("nightlight_force", false);
        toggled(on === true);
    }
    function toggle() {
        setEnabled(!enabled);
    }
    function toggleForce() {
        ShellState.set("nightlight_force", !forced);
        toggled(!forced);
    }

    function updateSchedule() {
        var now = new Date();
        var mins = now.getHours() * 60 + now.getMinutes();
        var custom = Config.get("location.custom_schedule", false) === true;
        var sunset = Util.parseHm(Config.get("location.sunset", "20:30"), 20 * 60 + 30);
        var sunrise = Util.parseHm(Config.get("location.sunrise", "07:30"), 7 * 60 + 30);
        if (!custom && Weather.hasLocation) {
            var t = Util.sunTimes(now, Weather.latitude, Weather.longitude);
            if (t) {
                sunrise = t.sunrise.getHours() * 60 + t.sunrise.getMinutes();
                sunset = t.sunset.getHours() * 60 + t.sunset.getMinutes();
            }
        }
        isNight = sunset > sunrise ? (mins >= sunset || mins < sunrise) : (mins >= sunset && mins < sunrise);
        Theme.autoIsNight = isNight;
    }

    // Kelvin -> RGB multipliers (Tanner Helland approximation)
    function kelvinRgb(k) {
        var t = k / 100;
        var r, g, b;
        if (t <= 66) {
            r = 255;
            g = 99.4708025861 * Math.log(t) - 161.1195681661;
            b = t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        } else {
            r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
            g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
            b = 255;
        }
        return [r, g, b].map(v => Math.max(0.1, Math.min(255, v)) / 255);
    }

    property bool appliedWarm: false

    function apply() {
        if (backend === "")
            return;
        var k = currentTemp;
        var neutral = k >= 6500;
        // never touch gamma unless we changed it before (do not fight other tools)
        if (neutral && !appliedWarm)
            return;
        appliedWarm = !neutral;
        var cmd;
        switch (backend) {
        case "redshift":
            cmd = neutral ? "redshift -x" : "redshift -P -O " + k;
            break;
        case "gammastep":
            cmd = neutral ? "gammastep -x" : "gammastep -P -O " + k;
            break;
        case "sct":
            cmd = neutral ? "sct" : "sct " + k;
            break;
        case "xrandr":
            var rgb = neutral ? [1, 1, 1] : kelvinRgb(k);
            var g = rgb.map(v => v.toFixed(3)).join(":");
            cmd = "for o in $(xrandr --query | awk '/ connected/{print $1}'); do xrandr --output \"$o\" --gamma " + g + "; done";
            break;
        default:
            return;
        }
        Quickshell.execDetached(["sh", "-c", cmd + " >/dev/null 2>&1"]);
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateSchedule()
    }

    Connections {
        target: Weather
        function onHasLocationChanged() {
            root.updateSchedule();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "for b in redshift gammastep sct xrandr; do command -v $b >/dev/null 2>&1 && { echo $b; exit 0; }; done"]
        stdout: StdioCollector {
            onStreamFinished: root.backend = text.trim()
        }
    }
}
