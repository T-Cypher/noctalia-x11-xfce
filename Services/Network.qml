pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// NetworkManager state through nmcli (event driven via `nmcli monitor`).
Singleton {
    id: root

    property bool available: false
    property bool wifiEnabled: false
    property bool wifiHardware: true
    property string connectivity: "unknown"
    property string primaryType: ""       // wifi | ethernet | ""
    property string primaryName: ""       // SSID / connection name
    property string primaryDevice: ""
    property int signal: 0
    property bool vpnActive: false
    property string vpnName: ""
    property string ipAddress: ""
    property var accessPoints: []         // [{ssid, signal, security, active, freq, known}]
    property var knownConnections: []
    property bool scanning: false
    property string connectingSsid: ""
    property string lastError: ""

    readonly property bool connected: primaryType !== ""

    signal wifiToggled(bool enabled)

    // noctalia's network_display glyphs
    function glyph() {
        if (primaryType === "ethernet")
            return "ethernet";
        if (!available || !wifiEnabled)
            return primaryType === "" && !wifiHardware ? "ethernet-off" : "wifi-off";
        if (primaryType === "wifi") {
            if (signal >= 80)
                return "wifi";
            if (signal >= 60)
                return "wifi-3";
            if (signal >= 35)
                return "wifi-2";
            if (signal >= 15)
                return "wifi-1";
            return "wifi-0";
        }
        return "wifi-exclamation";
    }

    // network-toggle: disconnect the active network, or reconnect when nothing is connected.
    property string lastDevice: ""
    function toggleConnection() {
        if (connected && primaryDevice !== "") {
            lastDevice = primaryDevice;
            disconnect();
        } else if (lastDevice !== "") {
            Quickshell.execDetached(["nmcli", "device", "connect", lastDevice]);
            refreshTimer.restart();
        } else {
            Quickshell.execDetached(["sh", "-c", "d=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | awk -F: '($2==\"wifi\"||$2==\"ethernet\") && $3==\"disconnected\" {print $1; exit}'); [ -n \"$d\" ] && exec nmcli device connect \"$d\""]);
            refreshTimer.restart();
        }
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function scan() {
        if (scanProc.running)
            return;
        scanning = true;
        scanProc.running = true;
    }

    function setWifi(enabled) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
        wifiEnabled = enabled;
        wifiToggled(enabled);
        refreshTimer.restart();
    }

    function toggleWifi() {
        setWifi(!wifiEnabled);
    }

    function connect(ssid, password) {
        connectingSsid = ssid;
        lastError = "";
        var known = knownConnections.indexOf(ssid) >= 0;
        if (known && !password)
            connectProc.command = ["nmcli", "connection", "up", "id", ssid];
        else if (password)
            connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        else
            connectProc.command = ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    function disconnect() {
        if (primaryDevice !== "")
            Quickshell.execDetached(["nmcli", "device", "disconnect", primaryDevice]);
        refreshTimer.restart();
    }

    function forget(ssid) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
        refreshTimer.restart();
    }

    function splitTerse(line) {
        // nmcli -t escapes ':' as '\:'
        var out = [], cur = "";
        for (var i = 0; i < line.length; i++) {
            var c = line.charAt(i);
            if (c === "\\" && i + 1 < line.length) {
                cur += line.charAt(++i);
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    Process {
        id: statusProc
        running: true
        command: ["sh", "-c", "command -v nmcli >/dev/null || exit 3; " + "echo '#radio'; nmcli -t -f WIFI-HW,WIFI radio 2>/dev/null; " + "echo '#conn'; nmcli -t -f CONNECTIVITY general 2>/dev/null; " + "echo '#dev'; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null; " + "echo '#active'; nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null; " + "echo '#wifi'; nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep '^yes' | head -n1; " + "echo '#ip'; ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -n1; " + "echo '#known'; nmcli -t -f NAME,TYPE connection show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
        onExited: (code, status) => {
            if (code === 3)
                root.available = false;
        }
    }

    function parseStatus(text) {
        var section = "";
        var lines = text.split("\n");
        var pType = "", pName = "", pDev = "", sig = 0, vpn = false, vpnN = "", ip = "", known = [];
        var wifiOn = false, hw = true, conn = "unknown";
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (l.length === 0)
                continue;
            if (l.charAt(0) === "#") {
                section = l.slice(1);
                continue;
            }
            var f = splitTerse(l);
            if (section === "radio") {
                hw = f[0] === "enabled";
                wifiOn = f[1] === "enabled";
            } else if (section === "conn") {
                conn = f[0];
            } else if (section === "dev") {
                if (f[2] === "connected" && pType === "" && (f[1] === "ethernet" || f[1] === "wifi")) {
                    pType = f[1];
                    pName = f[3];
                    pDev = f[0];
                }
            } else if (section === "active") {
                if (f[1] === "vpn" || f[1] === "wireguard" || f[1] === "tun") {
                    vpn = true;
                    vpnN = f[0];
                }
            } else if (section === "wifi") {
                sig = parseInt(f[1]) || 0;
                if (pType === "wifi" && f[2])
                    pName = f[2];
            } else if (section === "ip") {
                ip = l.trim();
            } else if (section === "known") {
                if (f[1] === "802-11-wireless")
                    known.push(f[0]);
            }
        }
        var wasEnabled = wifiEnabled;
        available = true;
        wifiHardware = hw;
        wifiEnabled = wifiOn;
        connectivity = conn;
        primaryType = pType;
        primaryName = pName;
        primaryDevice = pDev;
        signal = sig;
        vpnActive = vpn;
        vpnName = vpnN;
        ipAddress = ip;
        knownConnections = known;
        if (wasEnabled !== wifiOn)
            wifiToggled(wifiOn);
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,FREQ,SSID", "device", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {};
                var list = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue;
                    var f = root.splitTerse(lines[i]);
                    var ssid = f.slice(4).join(":");
                    if (!ssid)
                        continue;
                    var entry = {
                        ssid: ssid,
                        active: f[0] === "*",
                        signal: parseInt(f[1]) || 0,
                        security: f[2] && f[2] !== "--" ? f[2] : "",
                        freq: f[3] || "",
                        known: root.knownConnections.indexOf(ssid) >= 0
                    };
                    if (seen[ssid] === undefined || entry.active || entry.signal > list[seen[ssid]].signal) {
                        if (seen[ssid] === undefined) {
                            seen[ssid] = list.length;
                            list.push(entry);
                        } else {
                            list[seen[ssid]] = entry;
                        }
                    }
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.accessPoints = list;
                root.scanning = false;
            }
        }
        onExited: root.scanning = false
    }

    Process {
        id: connectProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: connectErr
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.lastError = connectErr.text.trim() || ("nmcli exited with " + code);
                Notifications.notifyInternal(I18n.tr("notifications.internal.network-connect-failed-title", "Could not connect to {ssid}", { ssid: root.connectingSsid }), root.lastError, "wifi-off");
            }
            root.connectingSsid = "";
            root.refresh();
        }
    }

    // Event-driven refresh: any nmcli monitor line triggers a debounced status update.
    Process {
        id: monitor
        running: true
        command: ["sh", "-c", "command -v nmcli >/dev/null && exec nmcli monitor"]
        stdout: SplitParser {
            onRead: refreshTimer.restart()
        }
        onExited: monitorRestart.start()
    }

    Timer {
        id: monitorRestart
        interval: 10000
        onTriggered: monitor.running = true
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        // signal strength drifts without nmcli monitor events
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
