pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// EWMH/XKB backend fed by scripts/x11-bridge.py. Replaces noctalia's compositor backends
// (workspaces, toplevels, keyboard layout, idle notification) on X11 window managers.
Singleton {
    id: root

    property bool available: false
    property int desktopCount: 1
    property int currentDesktop: 0
    property var desktopNames: []
    property string activeId: ""
    property var windows: []
    property bool showingDesktop: false
    property bool idleSupported: false
    property int idleSeconds: 0
    property var keyboard: ({
            layouts: ["us"],
            names: ["English (US)"],
            group: 0,
            caps: false,
            num: false,
            scroll: false
        })
    property int restarts: 0
    // Is a compositing manager running (xfwm4 compositor, picom)? Without one, transparency
    // renders black, so panels switch to an opaque, square fallback.
    property bool composited: true
    onCompositedChanged: Style.composited = composited

    readonly property var activeWindow: {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].id === activeId)
                return windows[i];
        return null;
    }
    readonly property string layoutCode: {
        var l = keyboard.layouts || [];
        return (l[keyboard.group] || l[0] || "us");
    }
    readonly property string layoutName: {
        var n = keyboard.names || [];
        return (n[keyboard.group] || n[0] || layoutCode.toUpperCase());
    }

    signal pointerReply(int x, int y, string tag)
    signal keyboardUpdated(bool layoutChanged, bool locksChanged, var previous)
    signal desktopSwitched(int index)

    function send(cmd) {
        if (proc.running)
            proc.write(cmd + "\n");
    }

    function switchDesktop(index) {
        send("desktop " + index);
    }
    function relDesktop(delta) {
        send("desktop-rel " + (delta > 0 ? "+" + delta : String(delta)));
    }
    // workspace-switch: adjacent workspace, stopping at both ends (noctalia semantics).
    function switchDesktopClamped(delta) {
        var t = currentDesktop + (delta > 0 ? 1 : -1);
        if (t >= 0 && t < desktopCount)
            switchDesktop(t);
    }
    // taskbar-cycle without an invoking taskbar: windows of the current workspace in stacking order.
    function cycleWindows(delta) {
        var list = windowsOnDesktop(currentDesktop).filter(w => !w.skipTaskbar);
        if (list.length === 0)
            return;
        var idx = list.findIndex(w => w.id === activeId);
        var n = idx < 0 ? 0 : (idx + (delta > 0 ? 1 : -1) + list.length) % list.length;
        activate(list[n].id);
    }
    function activate(id) {
        send("activate " + id);
    }
    function close(id) {
        send("close " + id);
    }
    function minimize(id) {
        send("minimize " + id);
    }
    function toggle(id) {
        send("toggle " + id);
    }
    function maximize(id) {
        send("maximize " + id);
    }
    function fullscreen(id) {
        send("fullscreen " + id);
    }
    function moveToDesktop(id, index) {
        send("move " + id + " " + index);
    }
    function focusTitle(title) {
        send("focus-title " + title);
    }
    function showDesktop() {
        send("show-desktop");
    }
    function layoutNext() {
        send("layout-next");
    }
    function layoutPrev() {
        send("layout-prev");
    }
    function setIdleWatch(on) {
        send("idle " + (on ? "on" : "off"));
    }
    function queryPointer(tag) {
        send("pointer " + (tag || ""));
    }

    // Layout label: [shell.keyboard_layout] custom_labels (or a widget's own custom_labels) keyed
    // by layout name or code, else the full name (display = "full") or the upper-case code.
    function layoutLabel(display, widgetLabels) {
        var custom = Object.assign({}, Config.get("shell.keyboard_layout.custom_labels", {}), widgetLabels || {});
        if (custom[layoutName] !== undefined && String(custom[layoutName]) !== "")
            return String(custom[layoutName]);
        if (custom[layoutCode] !== undefined && String(custom[layoutCode]) !== "")
            return String(custom[layoutCode]);
        return display === "full" ? layoutName : layoutCode.toUpperCase();
    }

    function desktopName(index) {
        var n = desktopNames[index];
        return n && n.length > 0 ? n : String(index + 1);
    }

    // Screen (ShellScreen) whose geometry contains the window center
    function screenOf(win) {
        if (!win)
            return null;
        var cx = win.x + win.w / 2, cy = win.y + win.h / 2;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height)
                return s;
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function screenAt(x, y) {
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                return s;
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function onScreen(win, screen) {
        if (!screen || Quickshell.screens.length <= 1)
            return true;
        var s = screenOf(win);
        return s !== null && s.name === screen.name;
    }

    function windowsOnDesktop(index) {
        return windows.filter(function (w) {
            return w.desktop === index || w.desktop === -1;
        });
    }

    function desktopOccupied(index) {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].desktop === index)
                return true;
        return false;
    }

    function desktopUrgent(index) {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].desktop === index && windows[i].urgent)
                return true;
        return false;
    }

    function handle(line) {
        var msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (msg.type) {
        case "state":
            var prevDesktop = currentDesktop;
            desktopCount = msg.desktops;
            desktopNames = msg.names || [];
            currentDesktop = msg.current;
            activeId = msg.active || "";
            showingDesktop = msg.showingDesktop === true;
            windows = msg.windows || [];
            available = true;
            if (prevDesktop !== currentDesktop)
                desktopSwitched(currentDesktop);
            break;
        case "keyboard":
            var old = keyboard;
            keyboard = msg;
            var layoutChanged = old.group !== msg.group || JSON.stringify(old.layouts) !== JSON.stringify(msg.layouts);
            var locksChanged = old.caps !== msg.caps || old.num !== msg.num || old.scroll !== msg.scroll;
            if (available)
                keyboardUpdated(layoutChanged, locksChanged, old);
            break;
        case "idle":
            idleSeconds = msg.seconds;
            break;
        case "pointer":
            pointerReply(msg.x, msg.y, msg.tag || "");
            break;
        case "compositor":
            composited = msg.active === true;
            break;
        case "ready":
            idleSupported = msg.idleSupported === true;
            restarts = 0;   // the restart budget only guards against crash loops
            break;
        case "error":
            console.warn("[x11-bridge]", msg.message);
            break;
        }
    }

    Process {
        id: proc
        command: ["python3", (Quickshell.shellDir + "/scripts/x11-bridge.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("[x11-bridge]", data)
        }
        onExited: (code, status) => {
            root.available = false;
            if (root.restarts < 20) {
                root.restarts++;
                restartTimer.start();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: proc.running = true
    }
}
