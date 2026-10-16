pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Desktop entries, launch tracking and X11 window-class -> icon resolution.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(a => a && !a.noDisplay).sort((a, b) => String(a.name).localeCompare(String(b.name)))
    readonly property var usage: ShellState.get("app_usage", ({}))
    readonly property var recent: ShellState.get("app_recent", [])

    function launch(entry) {
        if (!entry)
            return;
        if (Config.get("shell.launcher.track_usage", true) !== false) {
            var u = Object.assign({}, usage);
            u[entry.id] = (u[entry.id] || 0) + 1;
            ShellState.set("app_usage", u);
            var r = recent.filter(id => id !== entry.id);
            r.unshift(entry.id);
            ShellState.set("app_recent", r.slice(0, 24));
        }
        if (entry.runInTerminal) {
            var term = String(Config.get("x11.terminal", ""));
            var cmd = entry.command.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ");
            var launcher = term !== "" ? term + " -e " : "if command -v exo-open >/dev/null; then exo-open --launch TerminalEmulator " + cmd + "; exit; fi; x-terminal-emulator -e ";
            Quickshell.execDetached(["sh", "-c", term !== "" ? launcher + cmd : launcher + cmd]);
        } else {
            entry.execute();
        }
    }

    function byId(id) {
        return DesktopEntries.byId(id);
    }

    function usageCount(entry) {
        return entry ? (usage[entry.id] || 0) : 0;
    }

    // Icon path for an X11 window class / instance (or a desktop entry id)
    property var iconCache: ({})
    function iconForClass(appId, instance) {
        var key = (appId || "") + "|" + (instance || "");
        if (iconCache[key] !== undefined)
            return iconCache[key];
        var path = "";
        var candidates = [appId, instance, String(appId || "").toLowerCase(), String(instance || "").toLowerCase()];
        for (var i = 0; i < candidates.length && path === ""; i++) {
            var c = candidates[i];
            if (!c)
                continue;
            var entry = DesktopEntries.heuristicLookup(c);
            if (entry && entry.icon)
                path = Quickshell.iconPath(entry.icon, true);
            if (path === "")
                path = Quickshell.iconPath(c, true);
        }
        iconCache[key] = path;
        return path;
    }

    function entryForClass(appId, instance) {
        return DesktopEntries.heuristicLookup(appId || instance || "") || DesktopEntries.heuristicLookup(instance || "");
    }

    function iconFor(entry) {
        if (!entry || !entry.icon)
            return "";
        return Quickshell.iconPath(entry.icon, true);
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.iconCache = {};
        }
    }
}
