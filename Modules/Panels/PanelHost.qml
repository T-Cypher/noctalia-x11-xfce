pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter
import qs.Modules.Launcher
import qs.Modules.Session
import qs.Modules.WallpaperPicker
import qs.Modules.ClipboardPanel
import qs.Modules.TrayMenu

// Per-screen overlay hosting the active panel. It is an X11 dock window placed below the bar
// struts (so bar widgets stay clickable), closes panels on outside clicks / Escape and takes
// keyboard focus through EWMH _NET_ACTIVE_WINDOW.
PanelWindow {
    id: host

    required property var screenRef
    screen: screenRef

    readonly property bool wanted: Panels.isOpen && Panels.activeScreen !== null && Panels.activeScreen.name === screenRef.name
    property string loadedId: ""
    property bool shown: false
    property real progress: 0          // 0 = hidden, 1 = fully revealed

    // With a compositor: a transparent full-screen overlay (outside clicks close the panel).
    // Without one (transparency would render black): an opaque window exactly the panel's size
    // that closes when it loses focus.
    readonly property bool composited: X11.composited
    readonly property rect fallbackRect: clampedRect(placementItem.pw, placementItem.ph)

    anchors.top: true
    anchors.left: true
    anchors.bottom: composited
    anchors.right: composited
    margins.left: composited ? 0 : fallbackRect.x
    margins.top: composited ? 0 : fallbackRect.y
    implicitWidth: composited ? 0 : Math.max(1, placementItem.pw)
    implicitHeight: composited ? 0 : Math.max(1, placementItem.ph)
    exclusionMode: composited ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true
    focusable: true
    color: composited ? "transparent" : Theme.surface
    visible: shown

    // overlay origin relative to the screen (below/beside reserved bars)
    readonly property real originX: composited ? (root.Window.window ? root.Window.window.x : 0) - screenRef.x : 0
    readonly property real originY: composited ? (root.Window.window ? root.Window.window.y : 0) - screenRef.y : 0
    readonly property real areaWidth: composited ? host.width : screenRef.width
    readonly property real areaHeight: composited ? host.height : screenRef.height

    property bool wasActive: false
    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onActiveChanged() {
            var w = root.Window.window;
            if (w.active)
                host.wasActive = true;
            else if (!host.composited && host.wasActive && host.wanted)
                Panels.close();
        }
    }
    onShownChanged: if (!shown)
        wasActive = false

    readonly property var barCfg: {
        var b = Panels.sourceBar;
        if (b)
            return b;
        var bars = Config.bars;
        return bars.length > 0 ? Config.barForScreen(bars[0], screenRef) : null;
    }
    readonly property string placementKey: {
        switch (loadedId) {
        case "control-center": return "control_center";
        case "tray-menu": return "tray";
        default: return loadedId;
        }
    }
    readonly property string placement: {
        if (loadedId === "tray-menu")
            return "attached";
        var p = String(Config.get("shell.panel." + placementKey + "_placement", "floating"));
        return p === "attached" && barCfg ? "attached" : "floating";
    }
    readonly property string barPosition: barCfg ? String(barCfg.position || "top") : "top"
    readonly property string placementEdge: placement === "attached" ? barPosition : ""   // geometry
    readonly property string attachEdge: composited ? placementEdge : ""                   // flares
    readonly property bool openNearClick: loadedId === "tray-menu" || Config.get("shell.panel.open_near_click_" + placementKey, false) === true

    onWantedChanged: {
        if (wanted) {
            loadedId = Panels.activePanel;
            shown = true;
            closeAnim.stop();
            openAnim.restart();
            focusTimer.restart();
        } else if (shown) {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Connections {
        target: Panels
        function onActivePanelChanged() {
            if (host.wanted && Panels.activePanel !== host.loadedId) {
                host.loadedId = Panels.activePanel;
                openAnim.restart();
                focusTimer.restart();
            }
        }
        function onSerialChanged() {
            if (host.wanted)
                focusTimer.restart();
        }
    }

    NumberAnimation {
        id: openAnim
        target: host
        property: "progress"
        to: 1
        duration: Style.animNormal * 1.4
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation {
            target: host
            property: "progress"
            to: 0
            duration: Style.animNormal
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                host.shown = false;
                host.loadedId = "";
            }
        }
    }

    // keyboard focus
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: {
            var w = root.Window.window;
            if (!w)
                return;
            w.title = "noctalia-x11-panel-" + host.screenRef.name;
            if (String(Config.get("x11.focus_method", "bridge")) === "bridge")
                X11.focusTitle(w.title);
            w.requestActivate();
            if (loader.item && loader.item.focusFirst)
                loader.item.focusFirst();
            else
                keyCatcher.forceActiveFocus();
        }
    }

    function clampedRect(w, h) {
        var ow = host.areaWidth, oh = host.areaHeight;
        var gap = Style.spaceSm;
        var a = Panels.anchor;   // screen-local
        var cx = a ? a.x + a.w / 2 - originX : ow / 2;
        var cy = a ? a.y + a.h / 2 - originY : oh / 2;
        var x, y;
        if (placementEdge !== "") {
            var bc = barCfg;
            var thick = Number(bc.thickness || 34) * Style.uiScale;
            var edgeM = Number(bc.margin_edge || 0) * Style.uiScale;
            var ends = Number(bc.margin_ends || 0) * Style.uiScale;
            var inner = edgeM + thick;  // bar inner edge, screen-local distance from its screen edge
            var useAnchor = a && (openNearClick || loadedId !== "launcher");
            if (placementEdge === "top" || placementEdge === "bottom") {
                y = placementEdge === "top" ? inner - originY : (screenRef.height - inner) - originY - h;
                x = (useAnchor ? cx : ow / 2) - w / 2;
                // keep inside the bar span when it is wide enough, else inside the screen
                var minX = ends - originX + Style.radiusXl, maxX = screenRef.width - ends - originX - w - Style.radiusXl;
                if (maxX >= minX)
                    x = Math.max(minX, Math.min(maxX, x));
            } else {
                x = placementEdge === "left" ? inner - originX : (screenRef.width - inner) - originX - w;
                y = (useAnchor ? cy : oh / 2) - h / 2;
                var minY = ends - originY + Style.radiusXl, maxY = screenRef.height - ends - originY - h - Style.radiusXl;
                if (maxY >= minY)
                    y = Math.max(minY, Math.min(maxY, y));
            }
        } else {
            var pos = String(Config.get("shell.panel." + placementKey + "_position", "center"));
            if (openNearClick && a) {
                x = cx - w / 2;
                y = barPosition === "bottom" ? oh - h - gap : gap;
            } else {
                x = pos.indexOf("left") >= 0 ? gap : pos.indexOf("right") >= 0 ? ow - w - gap : (ow - w) / 2;
                y = pos.indexOf("top") >= 0 ? gap * 2 : pos.indexOf("bottom") >= 0 ? oh - h - gap * 2 : (oh - h) / 2;
            }
        }
        x = Math.max(0, Math.min(ow - w, x));
        y = Math.max(0, Math.min(oh - h, y));
        return Qt.rect(Math.round(x), Math.round(y), w, h);
    }

    Item {
        id: root
        anchors.fill: parent

        // Optional backdrop dim ([backdrop] enabled)
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.shadow, Number(Config.get("backdrop.tint_intensity", 0.3)))
            visible: Config.get("backdrop.enabled", false) === true
            opacity: host.progress
        }

        // Outside click closes the panel
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Panels.close()
        }

        FocusScope {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Panels.close()
        }

        Item {
            id: placementItem
            readonly property real pw: loader.item ? loader.item.implicitWidth : 0
            readonly property real ph: loader.item ? loader.item.implicitHeight : 0
            readonly property rect r: host.composited ? host.clampedRect(pw, ph) : Qt.rect(0, 0, pw, ph)
            x: r.x
            y: r.y
            width: pw
            height: ph

            // reveal: attached panels slide out of the bar, floating ones fade/scale in
            readonly property bool slide: host.attachEdge !== ""
            opacity: slide ? 1 : host.progress
            scale: slide ? 1 : 0.96 + 0.04 * host.progress

            Item {
                id: clipper
                anchors.fill: parent
                anchors.margins: -Style.radiusXl - 2
                clip: placementItem.slide
                // clip region grows from the attach edge
                readonly property real reveal: placementItem.slide ? host.progress : 1

                Item {
                    id: slider
                    x: Style.radiusXl + 2 + (host.attachEdge === "left" ? -(1 - clipper.reveal) * placementItem.width : host.attachEdge === "right" ? (1 - clipper.reveal) * placementItem.width : 0)
                    y: Style.radiusXl + 2 + (host.attachEdge === "top" ? -(1 - clipper.reveal) * placementItem.height : host.attachEdge === "bottom" ? (1 - clipper.reveal) * placementItem.height : 0)
                    width: placementItem.width
                    height: placementItem.height

                    PanelFrame {
                        id: frame
                        anchors.fill: parent
                        attachEdge: host.attachEdge
                        fill: Theme.alpha(Theme.surface, String(Config.get("shell.panel.transparency_mode", "solid")) === "solid" ? 1 : 0.88)
                        borderColor: Theme.resolve(Config.get("shell.panel.border_color", "outline"))
                        borderWidth: Config.get("shell.panel.borders", true) === false ? 0 : Number(Config.get("shell.panel.border_width", 1))
                        layer.enabled: !placementItem.slide && Config.get("shell.panel.shadow", true) !== false && host.shown
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.shadow
                            shadowOpacity: Number(Config.get("shell.shadow.alpha", 0.55))
                            shadowBlur: 0.8
                            shadowVerticalOffset: String(Config.get("shell.shadow.direction", "down")) === "up" ? -4 : 4
                        }
                    }

                    // swallow clicks inside the panel
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        onPressed: mouse => mouse.accepted = true
                    }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        active: host.loadedId !== ""
                        focus: true
                        sourceComponent: {
                            switch (host.loadedId) {
                            case "control-center": return ccComp;
                            case "launcher": return launcherComp;
                            case "session": return sessionComp;
                            case "wallpaper": return wallpaperComp;
                            case "clipboard": return clipboardComp;
                            case "tray-menu": return trayComp;
                            }
                            return null;
                        }
                        Keys.onEscapePressed: Panels.close()
                    }
                }
            }
        }
    }

    Component {
        id: ccComp
        ControlCenterPanel {
            screenRef: host.screenRef
        }
    }
    Component {
        id: launcherComp
        LauncherPanel {
            screenRef: host.screenRef
        }
    }
    Component {
        id: sessionComp
        SessionPanel {
            screenRef: host.screenRef
        }
    }
    Component {
        id: wallpaperComp
        WallpaperPanel {
            screenRef: host.screenRef
        }
    }
    Component {
        id: clipboardComp
        ClipboardPanel {
            screenRef: host.screenRef
        }
    }
    Component {
        id: trayComp
        TrayMenuPanel {
            screenRef: host.screenRef
        }
    }
}
