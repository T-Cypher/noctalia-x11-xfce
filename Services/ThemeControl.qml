pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Theme mode / color scheme changes + XFCE integration (optional GTK & icon theme switching
// through xsettings when [x11] gtk_theme_dark / gtk_theme_light are configured).
Singleton {
    id: root

    function setMode(mode) {
        var m = ["dark", "light", "auto"].indexOf(mode) >= 0 ? mode : "dark";
        ShellState.set("theme_mode", m);
    }

    // color-scheme-set <source> <name>. Returns "" on success or an error message.
    readonly property var wallpaperSchemes: ["m3-tonal-spot", "m3-content", "m3-fruit-salad", "m3-rainbow", "m3-monochrome", "vibrant", "faithful", "soft", "dysfunctional", "muted"]
    function setSource(source, name) {
        var n = String(name || "").trim();
        if (source === "wallpaper") {
            if (n !== "" && wallpaperSchemes.indexOf(n) < 0)
                return "error: unknown wallpaper scheme '" + n + "' (available: " + wallpaperSchemes.join(", ") + ")";
            ShellState.set("theme_source", "wallpaper");
            if (n !== "")
                ShellState.set("theme_wallpaper_scheme", n);
            return "";
        }
        if (source === "builtin") {
            if (n === "")
                return "error: color-scheme-set builtin requires <name>";
            var match = Theme.paletteNames.find(function (p) {
                return p.toLowerCase() === n.toLowerCase();
            });
            if (!match)
                return "error: unknown builtin palette '" + n + "' (available: " + Theme.paletteNames.join(", ") + ")";
            ShellState.set("theme_source", "builtin");
            ShellState.set("theme_builtin", match);
            return "";
        }
        if (source === "community" || source === "custom")
            return "error: " + source + " palettes are not supported by noctalia-x11";
        return "error: usage: color-scheme-set builtin <name> | wallpaper [scheme]";
    }

    function applyXsettings() {
        var dark = Theme.appIsDark;
        var gtk = String(Config.get(dark ? "x11.gtk_theme_dark" : "x11.gtk_theme_light", ""));
        var icons = String(Config.get(dark ? "x11.icon_theme_dark" : "x11.icon_theme_light", ""));
        if (gtk !== "")
            Quickshell.execDetached(["xfconf-query", "-c", "xsettings", "-p", "/Net/ThemeName", "-n", "-t", "string", "-s", gtk]);
        if (icons !== "")
            Quickshell.execDetached(["xfconf-query", "-c", "xsettings", "-p", "/Net/IconThemeName", "-n", "-t", "string", "-s", icons]);
    }

    // Runtime overrides (theme-mode-toggle, color-scheme-set) persist in state, but editing the
    // [theme] table in config.toml resets them so config changes always take effect.
    function configSnapshot() {
        return [Config.get("theme.mode", "dark"), Config.get("theme.source", "builtin"), Config.get("theme.builtin", "Noctalia"), Config.get("theme.wallpaper_scheme", "m3-content")].join("|");
    }
    function checkConfigChange() {
        if (!ShellState.loaded || !Config.ready)
            return;
        var snap = configSnapshot();
        var prev = ShellState.get("theme_config_snapshot", "");
        if (prev === snap)
            return;
        ShellState.set("theme_mode", null);
        ShellState.set("theme_source", null);
        ShellState.set("theme_builtin", null);
        ShellState.set("theme_wallpaper_scheme", null);
        ShellState.set("theme_config_snapshot", snap);
    }
    Connections {
        target: Config
        function onReloaded() {
            root.checkConfigChange();
        }
    }
    Connections {
        target: ShellState
        function onLoadedChanged() {
            root.checkConfigChange();
        }
    }

    property bool started: false
    property string lastAppMode: ""
    Component.onCompleted: {
        lastAppMode = Theme.appMode;
        startTimer.start();
        checkConfigChange();
    }

    Timer {
        id: startTimer
        interval: 1500
        onTriggered: root.started = true
    }

    Connections {
        target: Theme
        // theme_mode_changed follows the app-facing [theme] mode (it ignores shell_mode).
        function onAppModeChanged() {
            var previous = root.lastAppMode;
            root.lastAppMode = Theme.appMode;
            if (!root.started || previous === Theme.appMode)
                return;
            root.applyXsettings();
            Hooks.run("theme_mode_changed", {
                NOCTALIA_THEME_MODE: Theme.appMode,
                NOCTALIA_THEME_MODE_PREVIOUS: previous,
                NOCTALIA_THEME_MODE_CONFIGURED: Theme.requestedMode
            });
        }
        function onBasePaletteChanged() {
            if (root.started)
                Hooks.run("colors_changed", {});
        }
    }
}
