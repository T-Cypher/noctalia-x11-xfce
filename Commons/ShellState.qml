pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Small persistent runtime state (theme mode toggles, DND, caffeine, wallpapers, launcher
// usage, ...) stored as JSON in $XDG_STATE_HOME/noctalia-x11/state.json.
Singleton {
    id: root

    property var data: ({})
    property bool loaded: false
    property bool dirsReady: false
    readonly property string path: Config.stateDir + "/state.json"

    signal changed(string key)

    function get(key, fallback) {
        var v = data[key];
        return v === undefined || v === null ? fallback : v;
    }

    function set(key, value) {
        var copy = Object.assign({}, data);
        if (value === undefined || value === null)
            delete copy[key];
        else
            copy[key] = value;
        data = copy;
        changed(key);
        saveTimer.restart();
    }

    // Shallow update of a nested object key, e.g. setIn("wallpapers", "HDMI-1", "/a.png")
    function setIn(key, sub, value) {
        var obj = Object.assign({}, data[key] || {});
        if (value === undefined || value === null)
            delete obj[sub];
        else
            obj[sub] = value;
        set(key, obj);
    }

    function save() {
        // Never write before the existing state was read, or it would be clobbered.
        if (!dirsReady || !loaded) {
            saveTimer.restart();
            return;
        }
        file.setText(JSON.stringify(data, null, 1));
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: root.save()
    }

    Process {
        id: mkdirs
        running: true
        command: ["mkdir", "-p", Config.stateDir, Config.cacheDir]
        onExited: root.dirsReady = true
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                var t = text();
                root.data = t && t.length > 0 ? JSON.parse(t) : {};
            } catch (e) {
                console.warn("[noctalia-x11] state.json is corrupt, starting fresh:", e);
                root.data = {};
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
