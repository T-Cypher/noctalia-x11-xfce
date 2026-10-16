pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Display brightness, following noctalia's BrightnessService model:
//  * backlight devices through brightnessctl (sysfs + logind, works on X11 without root),
//  * external monitors over DDC/CI through ddcutil when [brightness] enable_ddcutil = true,
//  * [brightness.monitor.<x>] overrides: match, backend (auto|none|backlight|ddcutil),
//    backlight_device, ddc_bus; minimum_brightness, sync_all_monitors, ignore_mmids.
// Targets: current (the invoking / focused monitor), all, *, a display id
// ("intel_backlight", "ddc:6") or a monitor selector.
Singleton {
    id: root

    // [{id, kind: "backlight"|"ddc", device|bus, screen, label, brightness, max, controllable}]
    property var displays: []
    property var backlightDevices: []
    readonly property bool available: displays.some(d => d.controllable)
    readonly property real minimum: Math.max(0, Math.min(1, Number(Config.get("brightness.minimum_brightness", 0))))
    readonly property bool ddcEnabled: Config.get("brightness.enable_ddcutil", false) === true
    readonly property real step: 0.05   // noctalia's kDefaultBrightnessStep
    // Brightness of the display on the focused screen (or the first display) for widgets.
    readonly property var primary: {
        var aw = X11.activeWindow;
        var scr = aw ? X11.screenOf(aw) : null;
        var d = scr ? displayForScreen(scr) : null;
        return d || (displays.length > 0 ? displays[0] : null);
    }
    readonly property real brightness: primary ? primary.brightness : 0

    signal adjusted(real level)

    function displayForScreen(screen) {
        if (!screen)
            return null;
        for (var i = 0; i < displays.length; i++)
            if (displays[i].screen === screen.name && displays[i].controllable)
                return displays[i];
        return null;
    }

    function findDisplay(id) {
        for (var i = 0; i < displays.length; i++)
            if (displays[i].id === id)
                return displays[i];
        return null;
    }

    // Resolve an IPC target to display ids: {ids} or {error}.
    function resolveTargets(token, invokingScreen) {
        if (!available)
            return {
                error: "error: brightness control unavailable"
            };
        var ids = [];
        if (!token || token === "current") {
            var scr = invokingScreen;
            if (!scr) {
                var aw = X11.activeWindow;
                scr = aw ? X11.screenOf(aw) : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
            }
            var d = displayForScreen(scr);
            // single-display systems: the only display is the current one
            if (!d && displays.filter(x => x.controllable).length === 1)
                d = displays.filter(x => x.controllable)[0];
            if (!d)
                return {
                    error: "error: current output has no brightness control"
                };
            ids.push(d.id);
        } else if (token === "all" || token === "*") {
            ids = displays.filter(x => x.controllable).map(x => x.id);
        } else {
            var byId = findDisplay(token);
            if (byId) {
                if (!byId.controllable)
                    return {
                        error: "error: brightness target '" + token + "' has no brightness control"
                    };
                ids.push(byId.id);
            } else {
                var screens = Quickshell.screens;
                for (var i = 0; i < screens.length; i++) {
                    if (!Config.screenMatches(token, screens[i]))
                        continue;
                    var sd = displayForScreen(screens[i]);
                    if (sd && ids.indexOf(sd.id) < 0)
                        ids.push(sd.id);
                }
            }
            if (ids.length === 0)
                return {
                    error: "error: unknown brightness target '" + token + "' (available: " + displays.map(x => x.id).join(", ") + ")"
                };
        }
        if (Config.get("brightness.sync_all_monitors", false) === true)
            ids = displays.filter(x => x.controllable).map(x => x.id);
        return {
            ids: ids
        };
    }

    // Apply fn(currentLevel) -> newLevel to each display id.
    function setLevels(ids, fn) {
        var list = displays.slice();
        var last = -1;
        for (var i = 0; i < list.length; i++) {
            if (ids.indexOf(list[i].id) < 0 || !list[i].controllable)
                continue;
            var v = Math.max(minimum, Math.min(1, fn(list[i].brightness)));
            list[i] = Object.assign({}, list[i], {
                brightness: v
            });
            apply(list[i], v);
            last = v;
        }
        displays = list;
        if (last >= 0)
            adjusted(last);
    }

    // Widget / control-center helpers (focused display, or a given display id)
    function setBrightness(v, id) {
        var d = id ? findDisplay(id) : primary;
        if (d)
            setLevels([d.id], function () {
                return v;
            });
    }
    function change(delta, id) {
        var d = id ? findDisplay(id) : primary;
        if (d)
            setLevels([d.id], function (c) {
                return c + delta;
            });
    }

    function apply(d, v) {
        if (d.kind === "backlight") {
            backlightSetter.pending[d.device] = Math.round(v * 100);
            backlightSetter.flush();
        } else if (d.kind === "ddc") {
            ddcSetter.pending[d.bus] = Math.round(v * d.max);
            ddcSetter.flush();
        }
    }

    function refresh() {
        if (!backlightProbe.running)
            backlightProbe.running = true;
        if (ddcEnabled && !ddcProbe.running)
            ddcProbe.running = true;
    }

    // ------------------------------------------------------------------ model building
    property var backlightInfo: []   // [{device, current, max}]
    property var ddcInfo: []         // [{bus, connector, mmid, current, max}]

    function monitorOverrideFor(screen) {
        var mons = Config.get("brightness.monitor", {});
        var keys = Object.keys(mons).sort();
        for (var i = 0; i < keys.length; i++) {
            var m = mons[keys[i]];
            if (m && typeof m === "object" && Config.screenMatches(m.match !== undefined ? String(m.match) : keys[i], screen))
                return m;
        }
        return null;
    }

    function rebuild() {
        var screens = Quickshell.screens;
        var out = [];
        // keep the latest known level of existing displays (set or watched since the last probe)
        var known = {};
        for (var p = 0; p < displays.length; p++)
            known[displays[p].id] = displays[p].brightness;
        var usedScreens = {};
        var ignore = Config.get("brightness.ignore_mmids", []);
        // overrides first: they pin a backend / device to a screen
        function overrideFor(name) {
            for (var s = 0; s < screens.length; s++)
                if (screens[s].name === name)
                    return monitorOverrideFor(screens[s]);
            return null;
        }
        // DDC displays (associated through the DRM connector name, e.g. card1-DP-1 -> DP-1)
        if (ddcEnabled) {
            for (var i = 0; i < ddcInfo.length; i++) {
                var dd = ddcInfo[i];
                if (Array.isArray(ignore) && ignore.indexOf(dd.mmid) >= 0)
                    continue;
                var conn = String(dd.connector || "").replace(/^card\d+-/, "");
                var screenName = "";
                for (var j = 0; j < screens.length; j++) {
                    var ov = monitorOverrideFor(screens[j]);
                    if (ov && ov.ddc_bus !== undefined && Number(ov.ddc_bus) === dd.bus) {
                        screenName = screens[j].name;
                        break;
                    }
                    var a = screens[j].name.replace(/-/g, "").toLowerCase(), b = conn.replace(/-/g, "").toLowerCase();
                    if (screens[j].name === conn || (a !== "" && a === b))
                        screenName = screens[j].name;
                }
                var o = screenName !== "" ? overrideFor(screenName) : null;
                var backendOk = !o || o.backend === undefined || o.backend === "auto" || o.backend === "ddcutil";
                out.push({
                    id: "ddc:" + dd.bus,
                    kind: "ddc",
                    bus: dd.bus,
                    screen: screenName,
                    label: dd.mmid || ("DDC bus " + dd.bus),
                    brightness: known["ddc:" + dd.bus] !== undefined ? known["ddc:" + dd.bus] : (dd.max > 0 ? dd.current / dd.max : 0),
                    max: dd.max,
                    controllable: backendOk && dd.max > 0
                });
                if (screenName !== "" && backendOk)
                    usedScreens[screenName] = true;
            }
        }
        // Backlight devices: internal panels (eDP / LVDS / DSI), or the only screen.
        for (var k = 0; k < backlightInfo.length; k++) {
            var bl = backlightInfo[k];
            var target = "";
            for (var m = 0; m < screens.length; m++) {
                var ovb = monitorOverrideFor(screens[m]);
                if (ovb && ovb.backlight_device !== undefined && String(ovb.backlight_device).replace(/^.*\//, "") === bl.device) {
                    target = screens[m].name;
                    break;
                }
            }
            if (target === "") {
                for (var n = 0; n < screens.length; n++)
                    if (/^(eDP|LVDS|DSI)/i.test(screens[n].name) && !usedScreens[screens[n].name]) {
                        target = screens[n].name;
                        break;
                    }
            }
            if (target === "" && screens.length === 1 && !usedScreens[screens[0].name])
                target = screens[0].name;
            var ob = target !== "" ? overrideFor(target) : null;
            var blOk = !ob || ob.backend === undefined || ob.backend === "auto" || ob.backend === "backlight";
            out.push({
                id: bl.device,
                kind: "backlight",
                device: bl.device,
                screen: target,
                label: bl.device,
                brightness: known[bl.device] !== undefined ? known[bl.device] : (bl.max > 0 ? bl.current / bl.max : 0),
                max: bl.max,
                controllable: blOk && bl.max > 0
            });
        }
        displays = out;
    }

    onDdcEnabledChanged: refresh()
    Connections {
        target: Config
        function onReloaded() {
            root.rebuild();
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.rebuild();
        }
    }

    // brightnessctl -m -l -c backlight: device,class,current,percent,max (one line per device)
    Process {
        id: backlightProbe
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -m -l -c backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].trim().split(",");
                    if (f.length >= 5 && f[1] === "backlight")
                        list.push({
                            device: f[0],
                            current: parseInt(f[2]) || 0,
                            max: parseInt(f[4]) || 0
                        });
                }
                root.backlightInfo = list;
                root.backlightDevices = list.map(d => d.device);
                root.rebuild();
            }
        }
    }

    // ddcutil detect --terse, then getvcp 10 per bus
    Process {
        id: ddcProbe
        command: ["sh", "-c", "command -v ddcutil >/dev/null || exit 0; ddcutil detect --terse 2>/dev/null | while IFS= read -r line; do " + "case \"$line\" in Display*) echo \"#display\";; *'I2C bus:'*) b=${line##*/i2c-}; echo \"bus $b\"; v=$(ddcutil --bus \"$b\" getvcp 10 --terse 2>/dev/null); echo \"vcp $v\";; " + "*'DRM connector:'*) echo \"conn ${line##*: }\";; *'Monitor:'*) echo \"mmid ${line##*Monitor:}\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = [];
                var cur = null;
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l === "#display") {
                        cur = {
                            bus: -1,
                            connector: "",
                            mmid: "",
                            current: 0,
                            max: 0
                        };
                        list.push(cur);
                    } else if (cur && l.indexOf("bus ") === 0) {
                        cur.bus = parseInt(l.slice(4));
                    } else if (cur && l.indexOf("vcp ") === 0) {
                        var f = l.slice(4).trim().split(/\s+/);   // VCP 10 C <cur> <max>
                        if (f.length >= 5) {
                            cur.current = parseInt(f[3]) || 0;
                            cur.max = parseInt(f[4]) || 0;
                        }
                    } else if (cur && l.indexOf("conn ") === 0) {
                        cur.connector = l.slice(5).trim();
                    } else if (cur && l.indexOf("mmid ") === 0) {
                        cur.mmid = l.slice(5).trim();
                    }
                }
                root.ddcInfo = list.filter(d => d.bus >= 0);
                root.rebuild();
            }
        }
    }

    // Coalescing setters: only the latest value per device is written.
    Process {
        id: backlightSetter
        property var pending: ({})
        function flush() {
            if (running)
                return;
            var keys = Object.keys(pending);
            if (keys.length === 0)
                return;
            var cmds = keys.map(k => "brightnessctl --quiet -d '" + k.replace(/'/g, "") + "' set " + pending[k] + "%");
            pending = {};
            command = ["sh", "-c", cmds.join("; ")];
            running = true;
        }
        onExited: flush()
    }
    Process {
        id: ddcSetter
        property var pending: ({})
        function flush() {
            if (running)
                return;
            var keys = Object.keys(pending);
            if (keys.length === 0)
                return;
            var cmds = keys.map(k => "ddcutil --noverify --bus " + parseInt(k) + " setvcp 10 " + pending[k]);
            pending = {};
            command = ["sh", "-c", cmds.join("; ")];
            running = true;
        }
        onExited: flush()
    }

    // Track external changes of backlight devices (Fn keys handled by xfce4-power-manager etc.)
    Instantiator {
        id: backlightWatchers
        model: root.backlightInfo
        delegate: FileView {
            required property var modelData
            path: "/sys/class/backlight/" + modelData.device + "/actual_brightness"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                var v = parseInt(text());
                if (isNaN(v) || !(modelData.max > 0))
                    return;
                var list = root.displays.slice();
                for (var i = 0; i < list.length; i++) {
                    if (list[i].id !== modelData.device)
                        continue;
                    var nb = v / modelData.max;
                    if (Math.abs(nb - list[i].brightness) > 0.005) {
                        list[i] = Object.assign({}, list[i], {
                            brightness: nb
                        });
                        root.displays = list;
                        root.adjusted(nb);
                    }
                }
            }
        }
    }

    Timer {
        // sysfs backlight files do not always emit inotify events; poll gently.
        interval: 3000
        running: root.backlightInfo.length > 0
        repeat: true
        onTriggered: {
            for (var i = 0; i < backlightWatchers.count; i++) {
                var w = backlightWatchers.objectAt(i);
                if (w)
                    w.reload();
            }
        }
    }
}
