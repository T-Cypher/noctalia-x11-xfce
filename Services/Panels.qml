pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Panel manager: a single active panel (like noctalia's PanelManager) shown on one screen.
// Panels: launcher, control-center, session, wallpaper, clipboard, tray-menu.
Singleton {
    id: root

    property string activePanel: ""
    property var activeScreen: null
    property string context: ""
    property var anchor: null        // {x, y, w, h} in screen-local coordinates (source widget)
    property var sourceBar: null     // resolved bar config that opened the panel
    property var payload: null
    property int serial: 0
    readonly property bool isOpen: activePanel !== ""

    readonly property var knownPanels: ["launcher", "control-center", "session", "wallpaper", "clipboard", "tray-menu"]

    signal opened(string id)
    signal closed(string id)

    function screenByName(name) {
        var s = Quickshell.screens;
        for (var i = 0; i < s.length; i++)
            if (s[i].name === name)
                return s[i];
        return null;
    }

    function open(id, screen, ctx, anchorRect, bar, payloadObj) {
        if (knownPanels.indexOf(id) < 0) {
            console.warn("[noctalia-x11] unknown panel:", id);
            return;
        }
        var scr = screen || activeScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        activeScreen = scr;
        context = ctx || "";
        anchor = anchorRect || null;
        sourceBar = bar || null;
        payload = payloadObj || null;
        activePanel = id;
        serial++;
        opened(id);
    }

    function close(id) {
        if (id && id !== "" && id !== activePanel)
            return;
        var was = activePanel;
        activePanel = "";
        payload = null;
        if (was !== "")
            closed(was);
    }

    function toggle(id, screen, ctx, anchorRect, bar, payloadObj) {
        var sameScreen = !screen || !activeScreen || screen.name === activeScreen.name;
        if (activePanel === id && sameScreen && (!ctx || ctx === context || id !== "control-center"))
            close();
        else
            open(id, screen, ctx, anchorRect, bar, payloadObj);
    }

    // IPC entry points: resolve the screen under the pointer first (multi-monitor)
    property var pendingIpc: null
    function ipc(action, id, ctx) {
        if (Quickshell.screens.length <= 1 || !X11.available) {
            dispatchIpc(action, id, ctx, Quickshell.screens[0] || null);
            return;
        }
        pendingIpc = {
            action: action,
            id: id,
            ctx: ctx,
            tag: "panel" + (serial + 1) + "-" + Date.now()
        };
        X11.queryPointer(pendingIpc.tag);
        ipcTimeout.restart();
    }

    function dispatchIpc(action, id, ctx, screen) {
        if (action === "toggle")
            toggle(id, screen, ctx, null, null, null);
        else
            open(id, screen, ctx, null, null, null);
    }

    Connections {
        target: X11
        function onPointerReply(x, y, tag) {
            if (root.pendingIpc && root.pendingIpc.tag === tag) {
                var p = root.pendingIpc;
                root.pendingIpc = null;
                ipcTimeout.stop();
                root.dispatchIpc(p.action, p.id, p.ctx, X11.screenAt(x, y));
            }
        }
    }

    Timer {
        id: ipcTimeout
        interval: 400
        onTriggered: {
            if (root.pendingIpc) {
                var p = root.pendingIpc;
                root.pendingIpc = null;
                var aw = X11.activeWindow;
                root.dispatchIpc(p.action, p.id, p.ctx, aw ? X11.screenOf(aw) : Quickshell.screens[0]);
            }
        }
    }
}
