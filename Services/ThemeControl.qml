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

    function setSource(source, builtinName) {
        if (source === "wallpaper") {
            ShellState.set("theme_source", "wallpaper");
        } else {
            ShellState.set("theme_source", "builtin");
            if (builtinName && builtinName.length > 0)
                ShellState.set("theme_builtin", builtinName);
        }
    }

    function applyXsettings() {
        var dark = Theme.isDark;
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
        return [Config.get("theme.mode", "dark"), Config.get("theme.source", "builtin"), Config.get("theme.builtin", "Noctalia")].join("|");
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
    Component.onCompleted: {
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
        function onModeChanged() {
            if (!root.started)
                return;
            root.applyXsettings();
            Hooks.run("theme_mode_changed", {
                NOCTALIA_THEME_MODE: Theme.mode
            });
        }
        function onBasePaletteChanged() {
            if (root.started)
                Hooks.run("colors_changed", {});
        }
    }
}
