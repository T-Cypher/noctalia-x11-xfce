pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Toml.js" as Toml
import "Defaults.js" as Defaults
import "ConfigMerge.js" as ConfigMerge

// Configuration stack with noctalia v5.3.0 semantics (see ConfigMerge.js):
//   built-in defaults  <  every *.toml of the config directory (+ [include]s)  <  settings.toml
//
// Config source (first match wins):
//   1. $NOCTALIA_X11_CONFIG      a directory, or a single .toml file (+ its [include]s)
//   2. $XDG_CONFIG_HOME/noctalia-x11/*.toml        sidecar: $XDG_STATE_HOME/noctalia-x11/settings.toml
//   3. noctalia's own directory, read-only:
//      ${NOCTALIA_CONFIG_HOME:-$XDG_CONFIG_HOME}/noctalia/*.toml
//                                  sidecar: ${NOCTALIA_STATE_HOME:-$XDG_STATE_HOME}/noctalia/settings.toml
// A parse error or a missing include anywhere keeps the previous configuration (like noctalia)
// and reports the problem. Every loaded file, include directory and the sidecar are watched.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"
    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string xdgState: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string xdgCache: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
    readonly property string envPath: Quickshell.env("NOCTALIA_X11_CONFIG") || ""
    readonly property string ownDir: xdgConfig + "/noctalia-x11"
    readonly property string sharedDir: (Quickshell.env("NOCTALIA_CONFIG_HOME") || xdgConfig) + "/noctalia"
    readonly property string stateDir: xdgState + "/noctalia-x11"
    readonly property string cacheDir: xdgCache + "/noctalia-x11"
    readonly property string ownSidecar: stateDir + "/settings.toml"
    readonly property string sharedSidecar: (Quickshell.env("NOCTALIA_STATE_HOME") || xdgState) + "/noctalia/settings.toml"
    // File opened by settings-open (created from config.example.toml when missing).
    readonly property string ownPath: envPath !== "" && /\.toml$/.test(envPath) ? envPath : ownDir + "/config.toml"

    // Resolved configuration object (always complete thanks to defaults).
    property var data: finalize({})
    property string activePath: ""      // active config directory (or file), "" = built-in defaults
    property string activeSidecar: ""
    property var activeFiles: []
    property bool readOnlySource: false // using noctalia's own directory
    property string lastError: ""
    property string lastErrorTitle: ""
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
        return ConfigMerge.expandEnvVars(s, function (n) {
            return Quickshell.env(n) || "";
        });
    }

    // Dotted path lookup on the resolved config, e.g. get("osd.position", "top_center")
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

    // Settings of a named bar widget, with noctalia's seeding rule: a user [widget.<name>]
    // overlays the built-in entry of the same name only when it omits `type` or keeps it.
    function widgetSettings(name) {
        var all = data.widget || {};
        var user = Defaults.isPlainObject(all[name]) ? all[name] : null;
        var seeded = Defaults.seededWidgets[name];
        var out;
        if (user) {
            if (user.type !== undefined && user.type !== null && user.type !== "")
                out = seeded && seeded.type === user.type ? Defaults.merge(seeded, user) : Defaults.clone(user);
            else if (seeded)
                out = Defaults.merge(seeded, user);
            else
                out = Defaults.clone(user);
        } else if (seeded) {
            out = Defaults.clone(seeded);
        } else {
            out = {};
        }
        if (!out.type)
            out.type = name;
        return out;
    }

    // Bars: only user [bar.<name>] tables (ordered by [bar] order, then by name); with none at
    // all, a single bar named "default" with noctalia's BarConfig defaults.
    readonly property var bars: {
        var b = data.bar || {};
        var keys = [];
        for (var k in b)
            if (k !== "order" && Defaults.isPlainObject(b[k]))
                keys.push(k);
        if (keys.length === 0) {
            var d = Defaults.barDefaults();
            d.name = "default";
            return [d];
        }
        keys.sort();
        var names = [];
        var order = Array.isArray(b.order) ? b.order : [];
        for (var i = 0; i < order.length; i++)
            if (keys.indexOf(order[i]) >= 0 && names.indexOf(order[i]) < 0)
                names.push(order[i]);
        for (var j = 0; j < keys.length; j++)
            if (names.indexOf(keys[j]) < 0)
                names.push(keys[j]);
        var out = [];
        for (var n = 0; n < names.length; n++) {
            var cfg = Defaults.merge(Defaults.barDefaults(), b[names[n]]);
            if (cfg.enabled === false)
                continue;
            cfg.name = names[n];
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

    // noctalia monitor selector: exact connector name, or a whole token of the output's
    // manufacturer / model / serial / description.
    function screenMatches(selector, screen) {
        if (!screen)
            return false;
        return ConfigMerge.outputMatchesSelector(selector, screen.name, screen.manufacturer, screen.model, screen.serialNumber);
    }

    // Applies [bar.<name>.monitor.*] overrides (first match wins) for a given screen.
    function barForScreen(barCfg, screen) {
        var mons = barCfg.monitor;
        if (!Defaults.isPlainObject(mons) || !screen)
            return barCfg;
        var keys = Object.keys(mons).sort();
        for (var i = 0; i < keys.length; i++) {
            var m = mons[keys[i]];
            if (!Defaults.isPlainObject(m))
                continue;
            var match = m.match !== undefined ? String(m.match) : keys[i];
            if (screenMatches(match, screen)) {
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
        for (var i = 0; i < list.length; i++)
            if (screenMatches(String(list[i]), screen))
                return true;
        return false;
    }

    // Built-in defaults overlaid with the merged user configuration.
    function finalize(user) {
        var d = Defaults.merge(Defaults.defaults, user);
        // [idle.behavior.*] defaults are only seeded when the user configures none.
        if (Defaults.isPlainObject(user.idle) && Defaults.isPlainObject(user.idle.behavior) && Object.keys(user.idle.behavior).length > 0)
            d.idle.behavior = Defaults.clone(user.idle.behavior);
        return d;
    }

    // ------------------------------------------------------------------ loading

    function reload() {
        reloadTimer.restart();
    }

    property var probeInfo: ({})
    property int probeRounds: 0
    property bool busy: false
    property bool pendingReload: false
    property bool everLoaded: false
    property string lastJson: ""
    property var watchPaths: []

    Timer {
        id: reloadTimer
        interval: 120
        onTriggered: root.startReload()
    }

    function startReload() {
        if (busy) {
            pendingReload = true;
            return;
        }
        busy = true;
        probeRounds = 0;
        probeInfo = {};
        var first = [];
        if (envPath !== "")
            first.push(ConfigMerge.normalizePath(expandPath(envPath)));
        first.push(ownDir, sharedDir);
        probe(first);
    }

    function probe(paths) {
        probeRounds++;
        probeProc.command = ["sh", "-c", "for p in \"$@\"; do " + "if [ -d \"$p\" ]; then c=$(readlink -f -- \"$p\" 2>/dev/null || printf '%s' \"$p\"); printf 'D\\t%s\\t%s\\n' \"$p\" \"$c\"; " + "for f in \"$p\"/*.toml; do [ -f \"$f\" ] || continue; fc=$(readlink -f -- \"$f\" 2>/dev/null || printf '%s' \"$f\"); printf 'C\\t%s\\t%s\\t%s\\n' \"$p\" \"$f\" \"$fc\"; done; " + "elif [ -f \"$p\" ]; then c=$(readlink -f -- \"$p\" 2>/dev/null || printf '%s' \"$p\"); printf 'F\\t%s\\t%s\\n' \"$p\" \"$c\"; " + "else printf 'M\\t%s\\n' \"$p\"; fi; done", "sh"].concat(paths);
        probeProc.running = true;
    }

    function parseProbe(text) {
        var info = Object.assign({}, probeInfo);
        var lines = String(text).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].split("\t");
            if (f[0] === "D")
                info[f[1]] = {
                    type: "d",
                    canon: f[2] || f[1],
                    children: []
                };
            else if (f[0] === "C" && info[f[1]])
                info[f[1]].children.push({
                    path: f[2],
                    canon: f[3] || f[2]
                });
            else if (f[0] === "F")
                info[f[1]] = {
                    type: "f",
                    canon: f[2] || f[1],
                    children: []
                };
            else if (f[0] === "M")
                info[f[1]] = {
                    type: "m",
                    canon: f[1],
                    children: []
                };
        }
        probeInfo = info;
    }

    function readFile(path) {
        reader.failed = false;
        reader.path = path;
        reader.reload();
        var t = reader.text();
        return reader.failed ? null : t;
    }

    function sortedChildren(inf) {
        return inf.children.slice().sort(function (a, b) {
            return ConfigMerge.bytewise(a.path, b.path);
        });
    }

    // Pick the active source from the probe results.
    function pickSource() {
        var i;
        if (envPath !== "") {
            var p = ConfigMerge.normalizePath(expandPath(envPath));
            var e = probeInfo[p];
            if (e && e.type === "d")
                return {
                    path: p,
                    roots: sortedChildren(e),
                    sidecar: ownSidecar,
                    shared: false,
                    watch: [p]
                };
            if (e && e.type === "f")
                return {
                    path: p,
                    roots: [{
                            path: p,
                            canon: e.canon
                        }],
                    sidecar: ownSidecar,
                    shared: false,
                    watch: [ConfigMerge.dirname(p)]
                };
            console.warn("[noctalia-x11] NOCTALIA_X11_CONFIG does not exist:", p);
        }
        var own = probeInfo[ownDir];
        if (own && own.type === "d" && own.children.length > 0)
            return {
                path: ownDir,
                roots: sortedChildren(own),
                sidecar: ownSidecar,
                shared: false,
                watch: [ownDir]
            };
        var shared = probeInfo[sharedDir];
        if (shared && shared.type === "d" && shared.children.length > 0)
            return {
                path: sharedDir,
                roots: sortedChildren(shared),
                sidecar: sharedSidecar,
                shared: true,
                watch: [sharedDir]
            };
        return {
            path: "",
            roots: [],
            sidecar: ownSidecar,
            shared: false,
            watch: []
        };
    }

    function resolve() {
        var src = pickSource();
        var io = {
            read: function (p) {
                return root.readFile(p);
            },
            info: function (p) {
                return root.probeInfo[p];
            },
            env: function (n) {
                return Quickshell.env(n) || "";
            },
            home: home
        };
        var res = ConfigMerge.mergeAll(src.roots, io, Toml.parse);
        if (res.need.length > 0 && probeRounds < 10) {
            probe(res.need);
            return;
        }
        for (var w = 0; w < res.warnings.length; w++)
            console.warn("[noctalia-x11]", res.warnings[w]);
        finish(src, res);
    }

    function relativeTo(dir, path) {
        if (dir !== "" && path.indexOf(dir + "/") === 0)
            return path.substring(dir.length + 1);
        return path.indexOf(home + "/") === 0 ? "~" + path.substring(home.length) : path;
    }

    function finish(src, res) {
        var error = res.error;
        var errorTitle = res.error !== "" ? relativeTo(src.path, res.errorFile) + (res.errorLine > 0 ? ":" + res.errorLine : "") : "";
        var user = res.merged;
        var sidecarText = readFile(src.sidecar);
        var hasSidecar = sidecarText !== null && sidecarText.trim().length > 0;
        if (hasSidecar) {
            try {
                Defaults.deepMergeUser(user, Toml.parse(sidecarText));
            } catch (e) {
                if (error === "") {
                    error = e && e.message !== undefined ? e.message : String(e);
                    errorTitle = relativeTo("", src.sidecar) + (e && e.line ? ":" + e.line : "");
                }
            }
        }

        var noConfig = res.loaded.length === 0 && !hasSidecar && error === "";
        var next = null;
        if (error !== "") {
            console.warn("[noctalia-x11] config error:", errorTitle, error, everLoaded ? "(keeping the previous configuration)" : "(using defaults)");
            if (!everLoaded)
                next = finalize({});
        } else {
            next = finalize(noConfig ? {} : user);
            everLoaded = !noConfig || everLoaded;
        }

        lastErrorTitle = errorTitle;
        lastError = error;
        if (error === "" || !everLoaded) {
            activePath = src.path;
            activeSidecar = hasSidecar ? src.sidecar : "";
            activeFiles = res.loaded;
            readOnlySource = src.shared;
        }

        // Watch every source (and the candidate directories, so that creating them is noticed).
        var watch = [ownDir, sharedDir, ownSidecar, sharedSidecar].concat(src.watch, res.loaded, res.includeDirs);
        if (envPath !== "")
            watch.push(ConfigMerge.normalizePath(expandPath(envPath)));
        var uniq = [];
        for (var i = 0; i < watch.length; i++)
            if (watch[i] && uniq.indexOf(watch[i]) < 0)
                uniq.push(watch[i]);
        if (JSON.stringify(uniq) !== JSON.stringify(watchPaths))
            watchPaths = uniq;

        if (next !== null) {
            var json = JSON.stringify(next);
            if (json !== lastJson || !ready) {
                lastJson = json;
                data = next;
                generation++;
                ready = true;
                reloaded();
            }
        }
        busy = false;
        if (pendingReload) {
            pendingReload = false;
            reloadTimer.restart();
        }
    }

    Component.onCompleted: startReload()

    // Synchronous reader (blockAllReads: text() reads the file immediately).
    FileView {
        id: reader
        property bool failed: false
        preload: false
        blockAllReads: true
        printErrors: false
        onLoadFailed: failed = true
    }

    Process {
        id: probeProc
        stdout: StdioCollector {
            id: probeOut
        }
        onExited: (code, status) => {
            root.parseProbe(probeOut.text);
            root.resolve();
        }
    }

    // One watcher per source path. A FileView watching a directory reports entries being
    // added, removed or renamed in it; a missing path reports its creation.
    Instantiator {
        model: root.watchPaths
        delegate: FileView {
            required property var modelData
            path: modelData
            preload: false
            watchChanges: true
            printErrors: false
            onFileChanged: root.reload()
        }
    }
}
