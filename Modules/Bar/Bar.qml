import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/GestureDefaults.js" as GestureDefaults

// A noctalia bar on one screen, as an X11 dock window with _NET_WM_STRUT(_PARTIAL).
// Geometry follows [bar.<name>]: position, thickness, margin_ends, margin_edge, radius_*,
// concave_edge_corners (noctalia's bar_corner_shape.h), auto_hide / smart_auto_hide, ...
PanelWindow {
    id: bar

    required property var modelData      // bar name (stable across config reloads)
    required property var screenRef      // ShellScreen

    screen: screenRef
    readonly property var cfg: Config.barForScreen(Config.barByName(modelData), screenRef)
    readonly property string position: ["top", "bottom", "left", "right"].indexOf(String(cfg.position)) >= 0 ? String(cfg.position) : "top"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real contentScale: Number(cfg.scale !== undefined ? cfg.scale : 1) * Style.uiScale
    readonly property int thickness: Math.round(Number(cfg.thickness !== undefined ? cfg.thickness : 34) * Style.uiScale)
    readonly property int marginEdge: Math.round(Math.max(0, Number(cfg.margin_edge || 0)) * Style.uiScale)
    readonly property int screenLength: vertical ? screenRef.height : screenRef.width
    readonly property int marginEnds: {
        var m = Math.round(Math.max(0, Number(cfg.margin_ends || 0)) * Style.uiScale);
        return Math.max(0, Math.min(m, Math.floor((screenLength - 320) / 2)));
    }
    readonly property int marginOpposite: Math.round(Math.max(0, Number(cfg.margin_opposite_edge || 0)) * Style.uiScale)

    // Runtime IPC state for this bar instance (bar-hide/show/toggle, bar-reserve-toggle,
    // bar-auto-hide-set, bar-layer-set accept [bar-name] [monitor-selector]).
    readonly property var ipcState: Commands.barState[cfg.name + "@" + screenRef.name] || ({})
    readonly property bool hiddenByIpc: ipcState.hidden === true
    readonly property bool reserve: ipcState.reserve !== undefined ? ipcState.reserve : cfg.reserve_space !== false
    readonly property string autoHideMode: ipcState.autoHide !== undefined ? ipcState.autoHide : (cfg.smart_auto_hide === true ? "smart" : (cfg.auto_hide === true ? "on" : "off"))
    readonly property bool autoHideEnabled: autoHideMode !== "off"
    // smart_auto_hide: hidden while the active workspace has windows on this screen.
    readonly property bool workspaceBusy: autoHideMode === "smart" && X11.windows.some(w => (w.desktop === X11.currentDesktop || w.desktop === -1) && !w.minimized && !w.skipTaskbar && X11.onScreen(w, screenRef))
    readonly property bool hidesNow: autoHideMode === "on" || (autoHideMode === "smart" && workspaceBusy)
    readonly property bool panelFromThisBar: Panels.isOpen && Panels.activeScreen !== null && Panels.activeScreen.name === screenRef.name
    property bool pointerInside: false
    readonly property bool revealed: !hidesNow || pointerInside || panelFromThisBar || peekTimer.running
    readonly property real padding: Number(cfg.padding !== undefined ? cfg.padding : 14) * contentScale

    // ---------------------------------------------------------------- shape (bar_corner_shape.h)
    function cornerRadius(key) {
        var v = cfg[key] !== undefined ? cfg[key] : (cfg.radius !== undefined ? cfg.radius : 12);
        return Math.max(0, Style.radius(Number(v)));
    }
    readonly property real rTL: cornerRadius("radius_top_left")
    readonly property real rTR: cornerRadius("radius_top_right")
    readonly property real rBL: cornerRadius("radius_bottom_left")
    readonly property real rBR: cornerRadius("radius_bottom_right")
    // Canonical corners: "edge" corners touch the docked screen edge, "inner" ones face inward.
    readonly property var cornerKeys: ({
            top: ["rTL", "rTR", "rBL", "rBR"],
            bottom: ["rBL", "rBR", "rTL", "rTR"],
            left: ["rTL", "rBL", "rTR", "rBR"],
            right: ["rTR", "rBR", "rTL", "rBL"]
        })[position]
    readonly property real rEdgeStart: bar[cornerKeys[0]]
    readonly property real rEdgeEnd: bar[cornerKeys[1]]
    readonly property real rInnerStart: bar[cornerKeys[2]]
    readonly property real rInnerEnd: bar[cornerKeys[3]]
    readonly property bool concaveAllowed: Style.composited && cfg.concave_edge_corners !== false && marginEdge === 0
    readonly property bool screenEdgeMode: concaveAllowed && marginEnds > 0
    readonly property bool innerEdgeMode: concaveAllowed && marginEnds === 0
    readonly property real half: thickness / 2
    // screen-edge concavity: flare into the end margins (radius <= T/2 and <= margin_ends)
    readonly property real carveStart: screenEdgeMode ? Math.min(half, rEdgeStart, marginEnds) : 0
    readonly property real carveEnd: screenEdgeMode ? Math.min(half, rEdgeEnd, marginEnds) : 0
    // inner-edge concavity: fillets hang off the inner edge, the surface grows by the bulge
    readonly property real filletStart: innerEdgeMode ? Math.min(half, rInnerStart) : 0
    readonly property real filletEnd: innerEdgeMode ? Math.min(half, rInnerEnd) : 0
    readonly property real bulge: Math.max(filletStart, filletEnd)
    readonly property bool useShape: (screenEdgeMode || innerEdgeMode) && revealed

    // Window origin relative to the screen (used to anchor panels to widgets)
    readonly property real winX: position === "right" ? screenRef.width - width - marginEdge : (vertical ? marginEdge : margins.left)
    readonly property real winY: position === "bottom" ? screenRef.height - height - marginEdge : (vertical ? margins.top : marginEdge)

    anchors.top: position !== "bottom"
    anchors.bottom: position !== "top"
    anchors.left: position !== "right"
    anchors.right: position !== "left"
    margins.top: position === "top" ? marginEdge : (vertical ? marginEnds - carveStart : 0)
    margins.bottom: position === "bottom" ? marginEdge : (vertical ? marginEnds - carveEnd : 0)
    margins.left: position === "left" ? marginEdge : (!vertical ? marginEnds - carveStart : 0)
    margins.right: position === "right" ? marginEdge : (!vertical ? marginEnds - carveEnd : 0)

    readonly property int crossSize: revealed ? thickness + (useShape ? Math.ceil(bulge) : 0) : 3
    implicitHeight: vertical ? 200 : crossSize
    implicitWidth: vertical ? crossSize : 200
    exclusionMode: reserve && !hiddenByIpc ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: (autoHideEnabled && !reserve) ? 0 : thickness + marginEdge + marginOpposite
    aboveWindows: true
    focusable: false
    color: "transparent"
    visible: !hiddenByIpc && cfg.enabled !== false

    // With inner-edge fillets, only the bar body and the two fillet squares take input; the
    // rest of the bulge stays click-through.
    mask: useShape && innerEdgeMode ? bulgeMask : null
    Region {
        id: bulgeMask
        item: bodyArea
        Region {
            item: filletStartBox
        }
        Region {
            item: filletEndBox
        }
    }

    // Screen-local panel origin for a widget item
    function origin(item) {
        var p = item.mapToItem(null, 0, 0);
        return {
            screen: screenRef,
            bar: cfg,
            barWindow: bar,
            anchor: {
                x: winX + p.x,
                y: winY + p.y,
                w: item.width,
                h: item.height
            }
        };
    }

    // Bar dead zone (and unbound widget gestures): [bar.<name>.dead_zone.actions], default
    // right click -> control center.
    function deadZoneGesture(gesture, item, mouse) {
        var dz = (cfg.dead_zone && cfg.dead_zone.actions) || {};
        var a = dz[gesture] !== undefined ? dz[gesture] : GestureDefaults.deadZone[gesture];
        if (a === undefined || a === null || String(a) === "" || String(a) === "none")
            return;
        var p = item && mouse ? item.mapToItem(null, mouse.x, mouse.y) : Qt.point(width / 2, height / 2);
        Commands.run(String(a), {
            screen: screenRef,
            bar: cfg,
            barWindow: bar,
            anchor: {
                x: winX + p.x,
                y: winY + p.y,
                w: 1,
                h: 1
            }
        });
    }

    // ---------------------------------------------------------------- tooltips
    property Item tooltipTarget: null
    property string tooltipTextValue: ""
    function showTooltip(item, text) {
        tooltipTarget = item;
        tooltipTextValue = text;
        tooltipDelay.restart();
    }
    function hideTooltip(item) {
        if (tooltipTarget === item) {
            tooltipDelay.stop();
            tooltip.shown = false;
        }
    }
    Timer {
        id: tooltipDelay
        interval: 450
        onTriggered: tooltip.shown = bar.tooltipTarget !== null && !Panels.isOpen
    }
    Connections {
        target: Panels
        function onIsOpenChanged() {
            tooltipDelay.stop();
            tooltip.shown = false;
        }
    }
    function dismissTooltip() {
        tooltipDelay.stop();
        tooltip.shown = false;
    }
    NTooltip {
        id: tooltip
        target: bar.tooltipTarget
        text: bar.tooltipTextValue
        edge: bar.position === "top" ? "bottom" : bar.position === "bottom" ? "top" : bar.position === "left" ? "right" : "left"
    }

    // ---------------------------------------------------------------- auto-hide
    Timer {
        id: hideDelay
        interval: Math.max(1, Number(bar.cfg.auto_hide_delay_ms || 0))
        onTriggered: bar.pointerInside = false
    }
    Timer {
        id: peekTimer
        interval: 1200
    }
    Connections {
        target: X11
        function onDesktopSwitched() {
            if (bar.autoHideEnabled && bar.cfg.show_on_workspace_switch !== false)
                peekTimer.restart();
        }
    }

    // ---------------------------------------------------------------- body
    Item {
        id: body
        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    hideDelay.stop();
                    bar.pointerInside = true;
                } else if (bar.autoHideEnabled) {
                    hideDelay.restart();
                }
            }
        }

        // The bar body in window coordinates (excludes the concave flares / fillet bulge).
        Item {
            id: bodyArea
            x: bar.vertical ? (bar.position === "right" ? parent.width - bar.thickness : 0) : bar.carveStart
            y: bar.vertical ? bar.carveStart : (bar.position === "bottom" ? parent.height - bar.thickness : 0)
            width: bar.vertical ? Math.min(parent.width, bar.thickness) : parent.width - bar.carveStart - bar.carveEnd
            height: bar.vertical ? parent.height - bar.carveStart - bar.carveEnd : Math.min(parent.height, bar.thickness)
        }
        Item {
            id: filletStartBox
            readonly property real r: bar.filletStart
            x: bar.position === "left" ? bar.thickness : (bar.position === "right" ? parent.width - bar.thickness - r : 0)
            y: bar.position === "top" ? bar.thickness : (bar.position === "bottom" ? parent.height - bar.thickness - r : 0)
            width: bar.useShape && bar.innerEdgeMode ? r : 0
            height: width
        }
        Item {
            id: filletEndBox
            readonly property real r: bar.filletEnd
            x: bar.position === "left" ? bar.thickness : (bar.position === "right" ? parent.width - bar.thickness - r : parent.width - r)
            y: bar.position === "top" ? bar.thickness : (bar.position === "bottom" ? parent.height - bar.thickness - r : (bar.vertical ? parent.height - r : 0))
            width: bar.useShape && bar.innerEdgeMode ? r : 0
            height: width
        }

        // Dead zone: gestures on empty bar space
        MouseArea {
            anchors.fill: bodyArea
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
            property real wheelAccumY: 0
            property real wheelAccumX: 0
            onClicked: mouse => {
                var g = mouse.button === Qt.RightButton ? "right" : mouse.button === Qt.MiddleButton ? "middle" : mouse.button === Qt.BackButton ? "back" : mouse.button === Qt.ForwardButton ? "forward" : "left";
                bar.deadZoneGesture(g, this, mouse);
            }
            onWheel: wheel => {
                wheelAccumY += wheel.angleDelta.y;
                wheelAccumX += wheel.angleDelta.x;
                while (Math.abs(wheelAccumY) >= 120) {
                    bar.deadZoneGesture(wheelAccumY > 0 ? "scroll_up" : "scroll_down", this, wheel);
                    wheelAccumY -= wheelAccumY > 0 ? 120 : -120;
                }
                while (Math.abs(wheelAccumX) >= 120) {
                    bar.deadZoneGesture(wheelAccumX > 0 ? "scroll_left" : "scroll_right", this, wheel);
                    wheelAccumX -= wheelAccumX > 0 ? 120 : -120;
                }
            }
        }

        readonly property color fillColor: Theme.alpha(Theme.surface, Number(bar.cfg.background_opacity !== undefined ? bar.cfg.background_opacity : 1))
        readonly property real borderWidth: Math.max(0, Number(bar.cfg.border_width || 0))
        readonly property color borderColor: Theme.resolve(bar.cfg.border || "outline", Theme.outline)

        // Convex shape: a rounded rectangle with four independent radii.
        Rectangle {
            id: background
            anchors.fill: parent
            visible: !bar.useShape
            opacity: bar.revealed ? 1 : 0
            color: body.fillColor
            readonly property real cap: Math.min(width, height) / 2
            topLeftRadius: Math.min(bar.rTL, cap)
            topRightRadius: Math.min(bar.rTR, cap)
            bottomLeftRadius: Math.min(bar.rBL, cap)
            bottomRightRadius: Math.min(bar.rBR, cap)
            border.width: body.borderWidth
            border.color: body.borderColor
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animNormal
                }
            }
        }

        // Concave shapes (noctalia's concave_edge_corners)
        // Default geometry renderer (CurveRenderer is not available on every GL stack) with
        // multisampling for smooth arcs.
        Shape {
            anchors.fill: parent
            visible: bar.useShape
            layer.enabled: visible
            layer.samples: 4
            ShapePath {
                fillColor: body.fillColor
                strokeColor: body.borderWidth > 0 ? body.borderColor : "transparent"
                strokeWidth: body.borderWidth > 0 ? body.borderWidth : -1
                PathSvg {
                    path: bar.shapePath(body.width, body.height)
                }
            }
        }

        Item {
            id: sections
            x: bodyArea.x
            y: bodyArea.y
            width: bodyArea.width
            height: bodyArea.height
            opacity: bar.revealed ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animNormal
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: bar.vertical ? 0 : bar.padding
                anchors.rightMargin: bar.vertical ? 0 : bar.padding
                anchors.topMargin: bar.vertical ? bar.padding : 0
                anchors.bottomMargin: bar.vertical ? bar.padding : 0

                BarSection {
                    id: startSection
                    bar: bar
                    names: bar.cfg.start || []
                    x: bar.vertical ? (parent.width - width) / 2 : 0
                    y: bar.vertical ? 0 : (parent.height - height) / 2
                }

                BarSection {
                    id: centerSection
                    bar: bar
                    names: bar.cfg.center || []
                    anchors.centerIn: parent
                }

                BarSection {
                    id: endSection
                    bar: bar
                    names: bar.cfg.end || []
                    x: bar.vertical ? (parent.width - width) / 2 : parent.width - width
                    y: bar.vertical ? parent.height - height : (parent.height - height) / 2
                }
            }
        }
    }

    // SVG outline in window coordinates. The path is built for a "top" bar (u along the bar,
    // v away from the screen edge) and mapped to the real edge; mirrored mappings flip the
    // arc sweep direction.
    function shapePath(w, h) {
        if (w <= 0 || h <= 0)
            return "";
        var L = vertical ? h : w;
        var T = thickness;
        var flip = position === "bottom" || position === "left";
        function pt(u, v) {
            var x, y;
            if (position === "top") {
                x = u;
                y = v;
            } else if (position === "bottom") {
                x = u;
                y = h - v;
            } else if (position === "left") {
                x = v;
                y = u;
            } else {
                x = w - v;
                y = u;
            }
            return x.toFixed(2) + " " + y.toFixed(2);
        }
        function arc(r, sweep, u, v) {
            if (r <= 0)
                return " L " + pt(u, v);
            return " A " + r.toFixed(2) + " " + r.toFixed(2) + " 0 0 " + ((sweep === 1) !== flip ? 1 : 0) + " " + pt(u, v);
        }
        var s;
        if (screenEdgeMode) {
            var cs = carveStart, ce = carveEnd;
            var bodyL = L - cs - ce;
            var ris = Math.min(rInnerStart, half, bodyL / 2), rie = Math.min(rInnerEnd, half, bodyL / 2);
            s = "M " + pt(0, 0) + " L " + pt(L, 0);
            s += arc(ce, 0, L - ce, ce);
            s += " L " + pt(L - ce, T - rie);
            s += arc(rie, 1, L - ce - rie, T);
            s += " L " + pt(cs + ris, T);
            s += arc(ris, 1, cs, T - ris);
            s += " L " + pt(cs, cs);
            s += arc(cs, 0, 0, 0);
            return s + " Z";
        }
        // inner-edge fillets
        var res = Math.min(rEdgeStart, half, L / 2), ree = Math.min(rEdgeEnd, half, L / 2);
        var fs = filletStart, fe = filletEnd;
        s = "M " + pt(0, res);
        s += arc(res, 1, res, 0);
        s += " L " + pt(L - ree, 0);
        s += arc(ree, 1, L, ree);
        s += " L " + pt(L, T + fe);
        s += arc(fe, 0, L - fe, T);
        s += " L " + pt(fs, T);
        s += arc(fs, 0, 0, T + fs);
        return s + " Z";
    }
}
