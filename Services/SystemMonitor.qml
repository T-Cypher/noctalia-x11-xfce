pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// CPU / memory / network / disk / temperature sampling from /proc and /sys
// (same sources as noctalia's system monitor; intervals from [system.monitor]).
Singleton {
    id: root

    property int consumers: 0                 // widgets/tabs that need data
    readonly property bool active: consumers > 0 && Config.get("system.monitor.enabled", true) !== false

    property real cpuUsage: 0                 // 0..100
    property real cpuTemp: 0                  // °C
    property real memUsed: 0                  // bytes
    property real memTotal: 0
    property real memPercent: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real netRx: 0                    // bytes/s
    property real netTx: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real diskPercent: 0
    property string loadAvg: ""
    property real uptimeSeconds: 0
    property var cpuHistory: []
    property var memHistory: []
    property var rxHistory: []
    property var txHistory: []
    readonly property int historyLength: 60

    property var _lastCpu: null
    property var _lastNet: null
    property string _tempPath: ""

    function push(arr, v) {
        var a = arr.slice(Math.max(0, arr.length - historyLength + 1));
        a.push(v);
        return a;
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            var line = text().split("\n")[0].trim().split(/\s+/);
            var vals = line.slice(1).map(Number);
            var idle = vals[3] + (vals[4] || 0);
            var total = vals.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                var dt = total - root._lastCpu.total;
                var di = idle - root._lastCpu.idle;
                if (dt > 0) {
                    root.cpuUsage = Math.max(0, Math.min(100, (1 - di / dt) * 100));
                    root.cpuHistory = root.push(root.cpuHistory, root.cpuUsage);
                }
            }
            root._lastCpu = {
                total: total,
                idle: idle
            };
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            var m = {};
            text().split("\n").forEach(l => {
                var p = l.split(":");
                if (p.length === 2)
                    m[p[0].trim()] = parseInt(p[1]) * 1024;
            });
            root.memTotal = m.MemTotal || 0;
            root.memUsed = (m.MemTotal || 0) - (m.MemAvailable || 0);
            root.memPercent = root.memTotal > 0 ? root.memUsed / root.memTotal * 100 : 0;
            root.swapTotal = m.SwapTotal || 0;
            root.swapUsed = (m.SwapTotal || 0) - (m.SwapFree || 0);
            root.memHistory = root.push(root.memHistory, root.memPercent);
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            var rx = 0, tx = 0;
            var lines = text().split("\n").slice(2);
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i].trim();
                if (!l)
                    continue;
                var parts = l.split(":");
                var iface = parts[0].trim();
                if (iface === "lo" || iface.indexOf("veth") === 0 || iface.indexOf("docker") === 0 || iface.indexOf("br-") === 0 || iface.indexOf("virbr") === 0)
                    continue;
                var f = parts[1].trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            var now = Date.now();
            if (root._lastNet) {
                var dt = (now - root._lastNet.t) / 1000;
                if (dt > 0) {
                    root.netRx = Math.max(0, (rx - root._lastNet.rx) / dt);
                    root.netTx = Math.max(0, (tx - root._lastNet.tx) / dt);
                    root.rxHistory = root.push(root.rxHistory, root.netRx);
                    root.txHistory = root.push(root.txHistory, root.netTx);
                }
            }
            root._lastNet = {
                rx: rx,
                tx: tx,
                t: now
            };
        }
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        printErrors: false
        onLoaded: root.loadAvg = text().split(" ").slice(0, 3).join(" ")
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = parseFloat(text().split(" ")[0]) || 0
    }

    FileView {
        id: tempFile
        path: root._tempPath
        printErrors: false
        onLoaded: {
            var v = parseInt(text());
            if (!isNaN(v))
                root.cpuTemp = v / 1000;
        }
    }

    // Find a CPU temperature sensor (coretemp / k10temp / zenpower / cpu_thermal / acpitz)
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); case $n in coretemp|k10temp|zenpower|cpu_thermal|soc_thermal|acpitz) for f in $h/temp1_input $h/temp*_input; do [ -r $f ] && { echo $f; exit 0; }; done;; esac; done; for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type 2>/dev/null); case $t in x86_pkg_temp|cpu*|acpitz|soc*) echo $z/temp; exit 0;; esac; done"]
        stdout: StdioCollector {
            // [system.monitor] cpu_temp_sensor_path overrides the auto-detected sensor
            onStreamFinished: root._tempPath = String(Config.get("system.monitor.cpu_temp_sensor_path", "")) !== "" ? Config.expandPath(Config.get("system.monitor.cpu_temp_sensor_path", "")) : text.trim()
        }
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n");
                if (l.length >= 2) {
                    var f = l[1].trim().split(/\s+/).map(Number);
                    root.diskUsed = f[0];
                    root.diskTotal = f[1];
                    root.diskPercent = f[1] > 0 ? f[0] / f[1] * 100 : 0;
                }
            }
        }
    }

    Timer {
        // noctalia: 0 disables the metric; other values are clamped to 1..120 s
        readonly property real seconds: Number(Config.get("system.monitor.cpu_poll_seconds", 2))
        interval: Math.max(1000, Math.min(120000, seconds * 1000))
        running: root.active && seconds > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            loadFile.reload();
            uptimeFile.reload();
            if (root._tempPath !== "")
                tempFile.reload();
        }
    }
    Timer {
        // noctalia: 0 disables the metric; other values are clamped to 1..120 s
        readonly property real seconds: Number(Config.get("system.monitor.memory_poll_seconds", 2))
        interval: Math.max(1000, Math.min(120000, seconds * 1000))
        running: root.active && seconds > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: memFile.reload()
    }
    Timer {
        // noctalia: 0 disables the metric; other values are clamped to 1..120 s
        readonly property real seconds: Number(Config.get("system.monitor.network_poll_seconds", 3))
        interval: Math.max(1000, Math.min(120000, seconds * 1000))
        running: root.active && seconds > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: netFile.reload()
    }
    Timer {
        // noctalia: 0 disables the metric; other values are clamped to 1..120 s
        readonly property real seconds: Number(Config.get("system.monitor.disk_poll_seconds", 10))
        interval: Math.max(1000, Math.min(120000, seconds * 1000))
        running: root.active && seconds > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: dfProc.running = true
    }
    Timer {
        // uptime for the control-center profile card even without sysmon consumers
        interval: 60000
        running: !root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }
}
