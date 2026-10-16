pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Backlight brightness through brightnessctl (sysfs + logind, works on X11).
// Optional DDC/CI external monitors via ddcutil when [brightness].enable_ddcutil = true.
Singleton {
    id: root

    property bool available: false
    property real brightness: 0      // 0..1
    property string device: ""
    property int maxRaw: 0
    readonly property real minimum: Math.max(0, Number(Config.get("brightness.minimum_brightness", 0)))
    readonly property real step: Math.max(0.01, Number(Config.get("brightness.step", 5)) / 100)

    signal adjusted

    function refresh() {
        if (!probe.running)
            probe.running = true;
    }

    function setBrightness(v) {
        if (!available)
            return;
        var clamped = Math.max(minimum, Math.min(1, v));
        brightness = clamped;
        setter.command = ["brightnessctl", "--quiet", "set", Math.round(clamped * 100) + "%"];
        setter.running = true;
        adjusted();
    }

    function change(delta) {
        setBrightness(brightness + delta);
    }

    // brightnessctl -m: device,class,current,percent,max
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -m -c backlight info 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) {
                    root.available = false;
                    return;
                }
                var f = t.split(",");
                if (f.length >= 5) {
                    root.device = f[0];
                    var cur = parseInt(f[2]);
                    root.maxRaw = parseInt(f[4]);
                    if (root.maxRaw > 0)
                        root.brightness = cur / root.maxRaw;
                    root.available = true;
                }
            }
        }
    }

    Process {
        id: setter
        onExited: refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refresh()
    }

    // Track external changes (Fn keys handled by xfce4-power-manager etc.)
    FileView {
        id: sysfs
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/actual_brightness" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(text());
            if (!isNaN(v) && root.maxRaw > 0) {
                var nb = v / root.maxRaw;
                if (Math.abs(nb - root.brightness) > 0.005) {
                    root.brightness = nb;
                    root.adjusted();
                }
            }
        }
    }

    Timer {
        // sysfs backlight files do not always emit inotify events; poll gently.
        interval: 3000
        running: root.available
        repeat: true
        onTriggered: sysfs.reload()
    }
}
