pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Toml.js" as Toml
import "Defaults.js" as Defaults

// Loads the TOML configuration (noctalia v5 schema subset + [x11] table), merges it over the
// built-in defaults and hot-reloads it whenever the file changes.
//
// Lookup order:
//   1. $NOCTALIA_X11_CONFIG
//   2. ~/.config/noctalia-x11/config.toml
//   3. ~/.config/noctalia/config.toml   (shared with native noctalia, read-only)
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"
    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string xdgState: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string xdgCache: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
    readonly property string envPath: Quickshell.env("NOCTALIA_X11_CONFIG") || ""
    readonly property string ownDir: xdgConfig + "/noctalia-x11"
    readonly property string ownPath: envPath !== "" ? envPath : ownDir + "/config.toml"
    readonly property string sharedPath: xdgConfig + "/noctalia/config.toml"
    readonly property string stateDir: xdgState + "/noctalia-x11"
    readonly property string cacheDir: xdgCache + "/noctalia-x11"

    // Resolved configuration object (always complete thanks to defaults).
    property var data: Defaults.clone(Defaults.defaults)
    property string activePath: ""
    property string lastError: ""
    property int generation: 0
    property bool ready: false

    signal reloaded

    function expandPath(p) {
        if (p === undefined || p === null)
            return "";
        var s = String(p);
        if (s === "~")
            return home;
        if (s.indexOf("~/") === 0)
            return home + s.slice(1);
        return s.replace(/\$HOME|\$\{HOME\}/g, home);
    }

    // Dotted path lookup on the resolved config, e.g. get("bar.main.thickness", 34)
    function get(path, fallback) {
        var parts = String(path).split(".");
        var o = data;
        for (var i = 0; i < parts.length; i++) {
            if (o === null || o === undefined || typeof o !== "object")
                return fallback;
            o = o[parts[i]];
        }
        return o === undefined || o === null ? fallback : o;
    }

    // Settings of a named bar widget: [widget.<name>] merged with its type ("type" defaults to the name).
    function widgetSettings(name) {
        var all = data.widget || {};
        var s = all[name];
        var out = Defaults.isPlainObject(s) ? Defaults.clone(s) : {};
        if (!out.type)
            out.type = name;
        return out;
    }

    // Enabled bars, ordered by [bar].order then file order.
    readonly property var bars: {
        var b = data.bar || {};
        var names = [];
        var order = Array.isArray(b.order) ? b.order : [];
        for (var i = 0; i < order.length; i++)
            if (Defaults.isPlainObject(b[order[i]]) && names.indexOf(order[i]) < 0)
                names.push(order[i]);
        for (var k in b)
            if (k !== "order" && Defaults.isPlainObject(b[k]) && names.indexOf(k) < 0)
                names.push(k);
        var out = [];
        for (var j = 0; j < names.length; j++) {
            var cfg = Defaults.merge(Defaults.barDefaults(), b[names[j]]);
            if (cfg.enabled === false)
                continue;
            cfg.name = names[j];
            out.push(cfg);
        }
        return out;
    }

    function barByName(name) {
        for (var i = 0; i < bars.length; i++)
            if (bars[i].name === name)
                return bars[i];
        var d = Defaults.barDefaults();
        d.name = name;
        return d;
    }

    readonly property var barNames: bars.map(b => b.name)

    // Applies [bar.<name>.monitor.*] overrides (first match wins) for a given screen.
    function barForScreen(barCfg, screen) {
        var mons = barCfg.monitor;
        if (!Defaults.isPlainObject(mons) || !screen)
            return barCfg;
        for (var key in mons) {
            var m = mons[key];
            if (!Defaults.isPlainObject(m))
                continue;
            var match = m.match !== undefined ? String(m.match) : key;
            var desc = (screen.model || "") + " " + (screen.manufacturer || "");
            if (screen.name === match || (match.length > 0 && desc.indexOf(match) >= 0)) {
                var merged = Defaults.merge(barCfg, m);
                merged.name = barCfg.name;
                return merged;
            }
        }
        return barCfg;
    }

    function screenAllowed(list, screen) {
        if (!Array.isArray(list) || list.length === 0 || !screen)
            return true;
        return list.indexOf(screen.name) >= 0;
    }

    function applyText(text, path) {
        try {
            var parsed = Toml.parse(text);
            data = Defaults.merge(Defaults.defaults, parsed);
            activePath = path;
            lastError = "";
        } catch (e) {
            lastError = (path + ": " + (e && e.toString ? e.toString() : e));
            console.warn("[noctalia-x11] config error:", lastError);
            // keep the previous configuration on parse errors
        }
        generation++;
        ready = true;
        reloaded();
    }

    function useDefaults() {
        data = Defaults.clone(Defaults.defaults);
        activePath = "";
        generation++;
        ready = true;
        reloaded();
    }

    function reload() {
        ownFile.reload();
    }

    // Resolve which file to use: own config first, then the shared noctalia config.
    property bool ownLoaded: false
    property bool ownFailed: false
    property bool sharedLoaded: false
    property bool sharedFailed: false

    function pick() {
        if (ownLoaded) {
            applyText(ownFile.text(), root.ownPath);
        } else if (ownFailed && sharedLoaded) {
            applyText(sharedFile.text(), root.sharedPath);
        } else if (ownFailed && sharedFailed) {
            useDefaults();
        }
    }

    FileView {
        id: ownFile
        path: root.ownPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.ownLoaded = true;
            root.ownFailed = false;
            root.pick();
        }
        onLoadFailed: {
            root.ownLoaded = false;
            root.ownFailed = true;
            root.pick();
        }
        onFileChanged: reload()
    }

    FileView {
        id: sharedFile
        path: root.sharedPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.sharedLoaded = true;
            root.sharedFailed = false;
            if (!root.ownLoaded)
                root.pick();
        }
        onLoadFailed: {
            root.sharedLoaded = false;
            root.sharedFailed = true;
            if (!root.ownLoaded)
                root.pick();
        }
        onFileChanged: reload()
    }
}
