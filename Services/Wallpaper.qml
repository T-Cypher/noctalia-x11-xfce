pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Wallpapers on X11. On XFCE the desktop is owned by xfdesktop, so wallpapers are applied
// through xfconf (desktop icons keep working); feh / xwallpaper / hsetroot are fallbacks.
// Also feeds wallpaper-derived palettes to Theme when [theme] source = "wallpaper".
Singleton {
    id: root

    readonly property string bundled: (Quickshell.shellDir + "/assets/noctalia-wallpaper.png")
    readonly property string backendSetting: String(Config.get("x11.wallpaper_backend", "auto"))
    property string detectedBackend: ""
    readonly property string backend: backendSetting === "auto" ? detectedBackend : backendSetting
    property string picturesDir: Config.home + "/Pictures"
    readonly property string directory: {
        var d = "";
        if (!Theme.isDark)
            d = String(Config.get("wallpaper.directory_light", ""));
        else
            d = String(Config.get("wallpaper.directory_dark", ""));
        if (d === "")
            d = String(Config.get("wallpaper.directory", ""));
        return d !== "" ? Config.expandPath(d) : picturesDir;
    }
    readonly property bool recursive: Config.get("wallpaper.automation.recursive", true) !== false
    property var files: []
    property bool scanning: false
    readonly property var wallpapers: ShellState.get("wallpapers", ({}))
    property var xfdesktopCurrent: ({})
    readonly property string fillMode: String(Config.get("wallpaper.fill_mode", "crop"))

    signal changed(string screen, string path)

    function current(screenName) {
        var w = wallpapers;
        if (screenName && w[screenName])
            return w[screenName];
        if (w["*"])
            return w["*"];
        if (screenName && xfdesktopCurrent[screenName])
            return xfdesktopCurrent[screenName];
        var keys = Object.keys(xfdesktopCurrent);
        if (keys.length > 0)
            return xfdesktopCurrent[keys[0]];
        var def = String(Config.get("wallpaper.default.path", ""));
        return def !== "" ? Config.expandPath(def) : bundled;
    }

    readonly property string primaryWallpaper: current(Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")

    function scan() {
        if (scanning)
            return;
        scanning = true;
        scanProc.command = ["sh", "-c", "find -L \"$1\" " + (recursive ? "-maxdepth 4" : "-maxdepth 1") + " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) 2>/dev/null | sort | head -n 2000", "sh", directory];
        scanProc.running = true;
    }

    function set(screenName, path) {
        if (!path)
            return;
        var p = Config.expandPath(path);
        if (!screenName || screenName === "*" || screenName === "all") {
            ShellState.set("wallpapers", {
                "*": p
            });
            applyAll(p);
            changed("*", p);
        } else {
            ShellState.setIn("wallpapers", screenName, p);
            applyScreen(screenName, p);
            changed(screenName, p);
        }
        // noctalia runs wallpaper_changed once per changed connector
        var targets = (!screenName || screenName === "*" || screenName === "all") ? Quickshell.screens.map(sc => sc.name) : [screenName];
        for (var t = 0; t < targets.length; t++)
            Hooks.run("wallpaper_changed", {
                NOCTALIA_WALLPAPER_PATH: p,
                NOCTALIA_WALLPAPER_CONNECTOR: targets[t]
            });
    }

    function pickRelative(screenName, delta) {
        if (files.length === 0) {
            scan();
            return;
        }
        var cur = current(screenName);
        var idx = files.indexOf(cur);
        var n = idx < 0 ? 0 : (idx + delta + files.length) % files.length;
        set(screenName || "*", files[n]);
    }
    function next(screenName) {
        pickRelative(screenName, 1);
    }
    function previous(screenName) {
        pickRelative(screenName, -1);
    }
    function random(screenName) {
        if (files.length === 0) {
            pendingRandom = screenName || "*";
            scan();
            return;
        }
        var cur = current(screenName);
        var pick = files[Math.floor(Math.random() * files.length)];
        if (files.length > 1 && pick === cur)
            pick = files[(files.indexOf(pick) + 1) % files.length];
        set(screenName || "*", pick);
    }
    property string pendingRandom: ""

    function styleCode() {
        return {
            "crop": 5,
            "fill": 5,
            "fit": 4,
            "contain": 4,
            "stretch": 3,
            "center": 1,
            "tile": 2
        }[fillMode] || 5;
    }

    function applyAll(path) {
        var screens = Quickshell.screens;
        if (backend === "xfdesktop") {
            for (var i = 0; i < screens.length; i++)
                applyScreen(screens[i].name, path);
            return;
        }
        applyScreen("*", path);
    }

    function applyScreen(screenName, path) {
        var q = "'" + String(path).replace(/'/g, "'\\''") + "'";
        var cmd = "";
        switch (backend) {
        case "xfdesktop":
            // Update every existing last-image key for this monitor (all workspaces), creating
            // the workspace keys when xfdesktop has never stored them.
            var mon = screenName === "*" ? "" : screenName;
            cmd = "props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' | grep -F \"monitor" + mon + "\"); " + "if [ -z \"$props\" ]; then n=$(xprop -root _NET_NUMBER_OF_DESKTOPS 2>/dev/null | awk '{print $3}'); n=${n:-4}; " + "for i in $(seq 0 $((n-1))); do props=\"$props /backdrop/screen0/monitor" + (mon || "0") + "/workspace$i/last-image\"; done; fi; " + "for p in $props; do xfconf-query -c xfce4-desktop -p \"$p\" -n -t string -s " + q + "; " + "xfconf-query -c xfce4-desktop -p \"${p%/last-image}/image-style\" -n -t int -s " + styleCode() + "; done";
            break;
        case "feh":
            var fehMode = {
                "fit": "--bg-max",
                "contain": "--bg-max",
                "stretch": "--bg-scale",
                "center": "--bg-center",
                "tile": "--bg-tile"
            }[fillMode] || "--bg-fill";
            cmd = "feh --no-fehbg " + fehMode + " " + q;
            break;
        case "xwallpaper":
            var xwMode = {
                "fit": "--maximize",
                "contain": "--maximize",
                "stretch": "--stretch",
                "center": "--center",
                "tile": "--tile"
            }[fillMode] || "--zoom";
            cmd = screenName === "*" ? "xwallpaper " + xwMode + " " + q : "xwallpaper --output '" + screenName + "' " + xwMode + " " + q;
            break;
        case "hsetroot":
            var hsMode = {
                "fit": "-full",
                "stretch": "-fill",
                "center": "-center",
                "tile": "-tile"
            }[fillMode] || "-cover";
            cmd = "hsetroot " + hsMode + " " + q;
            break;
        default:
            return;
        }
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // ---------------------------------------------------------------- detection
    Process {
        running: true
        command: ["sh", "-c", "if pgrep -x xfdesktop >/dev/null 2>&1; then echo xfdesktop; " + "elif command -v feh >/dev/null; then echo feh; elif command -v xwallpaper >/dev/null; then echo xwallpaper; " + "elif command -v hsetroot >/dev/null; then echo hsetroot; elif command -v xfconf-query >/dev/null; then echo xfdesktop; fi; " + "echo \"#pics $(xdg-user-dir PICTURES 2>/dev/null)\"; " + "xfconf-query -c xfce4-desktop -l -v 2>/dev/null | grep -E 'monitor.*/workspace0/last-image' "]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var cur = {};
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (l.length === 0)
                        continue;
                    if (i === 0 && l.indexOf("/") < 0 && l.indexOf("#") !== 0) {
                        root.detectedBackend = l;
                        continue;
                    }
                    if (l.indexOf("#pics ") === 0) {
                        var p = l.slice(6).trim();
                        if (p.length > 0 && p !== Config.home)
                            root.picturesDir = p;
                        continue;
                    }
                    var m = /\/backdrop\/screen\d+\/monitor([^\/]+)\/workspace0\/last-image\s+(.*)$/.exec(l);
                    if (m && m[2])
                        cur[m[1]] = m[2].trim();
                }
                root.xfdesktopCurrent = cur;
            }
        }
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                var list = text.split("\n").filter(l => l.length > 0);
                if (list.indexOf(root.bundled) < 0)
                    list.push(root.bundled);
                root.files = list;
                root.scanning = false;
                if (root.pendingRandom !== "") {
                    var s = root.pendingRandom;
                    root.pendingRandom = "";
                    if (root.files.length > 0)
                        root.random(s);
                }
            }
        }
        onExited: root.scanning = false
    }

    onDirectoryChanged: scan()
    Component.onCompleted: scan()

    // [wallpaper.automation]
    Timer {
        interval: Math.max(60, Number(Config.get("wallpaper.automation.interval_seconds", 1800))) * 1000
        running: Config.get("wallpaper.automation.enabled", false) === true
        repeat: true
        onTriggered: {
            if (String(Config.get("wallpaper.automation.order", "random")) === "alphabetical")
                root.next("*");
            else
                root.random("*");
        }
    }

    // Wallpaper-derived palette
    ColorQuantizer {
        id: quantizer
        source: Theme.source === "wallpaper" && root.primaryWallpaper !== "" ? "file://" + root.primaryWallpaper : ""
        depth: 3
        rescaleSize: 96
        onColorsChanged: Theme.wallpaperColors = colors && colors.length > 0 ? colors : []
    }
}
