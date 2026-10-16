pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Text clipboard history (X11 CLIPBOARD selection, change-notified through XFixes by Qt).
Singleton {
    id: root

    readonly property bool enabled: Config.get("shell.clipboard_enabled", true) !== false
    readonly property int maxEntries: Math.max(5, Number(Config.get("shell.clipboard_history_max_entries", 100)))
    property var entries: []        // [{text, time, pinned}]
    property string lastText: ""
    property bool loaded: false

    readonly property string currentText: enabled ? Quickshell.clipboardText : ""

    onCurrentTextChanged: record(currentText)

    function record(text) {
        if (!enabled || !loaded || text === undefined || text === null)
            return;
        var t = String(text);
        if (t.trim().length === 0 || t === lastText)
            return;
        lastText = t;
        var list = entries.filter(e => e.text !== t);
        var pinned = entries.find(e => e.text === t && e.pinned) !== undefined;
        list.unshift({
            text: t,
            time: Date.now(),
            pinned: pinned
        });
        var keep = [];
        var count = 0;
        for (var i = 0; i < list.length; i++) {
            if (list[i].pinned || count < maxEntries) {
                keep.push(list[i]);
                if (!list[i].pinned)
                    count++;
            }
        }
        entries = keep;
        saveTimer.restart();
    }

    function copy(text) {
        lastText = String(text);
        Quickshell.clipboardText = String(text);
        // move to top
        var list = entries.filter(e => e.text !== text);
        var old = entries.find(e => e.text === text);
        list.unshift({
            text: String(text),
            time: Date.now(),
            pinned: old ? old.pinned : false
        });
        entries = list;
        saveTimer.restart();
    }

    function remove(text) {
        entries = entries.filter(e => e.text !== text);
        saveTimer.restart();
    }

    function togglePin(text) {
        entries = entries.map(e => e.text === text ? {
                text: e.text,
                time: e.time,
                pinned: !e.pinned
            } : e);
        saveTimer.restart();
    }

    function clear() {
        entries = entries.filter(e => e.pinned);
        saveTimer.restart();
    }

    // Paste into the previously focused window after the panel closed (needs xdotool)
    function pasteSoon() {
        pasteTimer.restart();
    }

    Timer {
        id: pasteTimer
        interval: 220
        onTriggered: Quickshell.execDetached(["sh", "-c", "command -v xdotool >/dev/null && xdotool key --clearmodifiers ctrl+v"])
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: {
            if (!ShellState.dirsReady) {
                restart();
                return;
            }
            store.setText(JSON.stringify(root.entries));
        }
    }

    FileView {
        id: store
        path: Config.stateDir + "/clipboard.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.entries = JSON.parse(text()) || [];
            } catch (e) {
                root.entries = [];
            }
            root.loaded = true;
            root.record(root.currentText);
        }
        onLoadFailed: {
            root.loaded = true;
            root.record(root.currentText);
        }
    }
}
