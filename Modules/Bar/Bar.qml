import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// A noctalia bar on one screen, as an X11 dock window with _NET_WM_STRUT(_PARTIAL).
// Geometry follows [bar.<name>]: position, thickness, margin_ends, margin_edge, radius, ...
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
    readonly property int marginEdge: Math.round(Number(cfg.margin_edge || 0) * Style.uiScale)
    readonly property int marginEnds: {
        var m = Math.round(Number(cfg.margin_ends || 0) * Style.uiScale);
        var len = vertical ? screenRef.height : screenRef.width;
        return Math.max(0, Math.min(m, Math.floor((len - 320) / 2)));
    }
    readonly property int marginOpposite: Number(cfg.margin_opposite_edge || 0)
    readonly property bool hiddenByIpc: Commands.hiddenBars[cfg.name] === true || (Commands.hiddenBars["*"] === true && Commands.hiddenBars[cfg.name] !== false)
    readonly property bool reserve: cfg.reserve_space !== false
    readonly property bool autoHide: cfg.auto_hide === true
    readonly property bool panelFromThisBar: Panels.isOpen && Panels.activeScreen !== null && Panels.activeScreen.name === screenRef.name
    property bool pointerInside: false
    readonly property bool revealed: !autoHide || pointerInside || panelFromThisBar || peekTimer.running
    readonly property real padding: Number(cfg.padding !== undefined ? cfg.padding : 14) * contentScale

    // Window origin relative to the screen (used to anchor panels to widgets)
    readonly property real winX: position === "right" ? screenRef.width - thickness - marginEdge : (vertical ? marginEdge : marginEnds)
    readonly property real winY: position === "bottom" ? screenRef.height - thickness - marginEdge : (vertical ? marginEnds : marginEdge)

    anchors.top: position !== "bottom"
    anchors.bottom: position !== "top"
    anchors.left: position !== "right"
    anchors.right: position !== "left"
    margins.top: position === "top" ? marginEdge : (vertical ? marginEnds : 0)
    margins.bottom: position === "bottom" ? marginEdge : (vertical ? marginEnds : 0)
    margins.left: position === "left" ? marginEdge : (!vertical ? marginEnds : 0)
    margins.right: position === "right" ? marginEdge : (!vertical ? marginEnds : 0)

    implicitHeight: vertical ? 200 : (revealed ? thickness : 3)
    implicitWidth: vertical ? (revealed ? thickness : 3) : 200
    exclusionMode: reserve && !hiddenByIpc ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: (autoHide && !reserve) ? 0 : thickness + marginEdge + marginOpposite
    aboveWindows: true
    focusable: false
    color: "transparent"
    visible: !hiddenByIpc

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
            if (bar.autoHide && bar.cfg.show_on_workspace_switch !== false)
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
                } else if (bar.autoHide) {
                    hideDelay.restart();
                }
            }
        }

        // Dead zone: right click opens the control center (noctalia default)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                var dz = (bar.cfg.dead_zone && bar.cfg.dead_zone.actions) || {};
                var g = mouse.button === Qt.RightButton ? "right" : mouse.button === Qt.MiddleButton ? "middle" : "left";
                var a = dz[g] !== undefined ? dz[g] : (g === "right" ? "panel-toggle control-center home" : "none");
                var p = mapToItem(null, mouse.x, mouse.y);
                Commands.run(String(a), {
                    screen: bar.screenRef,
                    bar: bar.cfg,
                    anchor: {
                        x: bar.winX + p.x,
                        y: bar.winY + p.y,
                        w: 1,
                        h: 1
                    }
                });
            }
            onWheel: wheel => {
                var dz = (bar.cfg.dead_zone && bar.cfg.dead_zone.actions) || {};
                var a = wheel.angleDelta.y > 0 ? dz.scroll_up : dz.scroll_down;
                if (a)
                    Commands.run(String(a), null);
            }
        }

        Rectangle {
            id: background
            anchors.fill: parent
            opacity: bar.revealed ? 1 : 0
            color: Theme.alpha(Theme.surface, Number(bar.cfg.background_opacity !== undefined ? bar.cfg.background_opacity : 1))
            readonly property real r: Style.radius(Number(bar.cfg.radius !== undefined ? bar.cfg.radius : 12))
            topLeftRadius: bar.cfg.radius_top_left !== undefined ? Style.radius(Number(bar.cfg.radius_top_left)) : r
            topRightRadius: bar.cfg.radius_top_right !== undefined ? Style.radius(Number(bar.cfg.radius_top_right)) : r
            bottomLeftRadius: bar.cfg.radius_bottom_left !== undefined ? Style.radius(Number(bar.cfg.radius_bottom_left)) : r
            bottomRightRadius: bar.cfg.radius_bottom_right !== undefined ? Style.radius(Number(bar.cfg.radius_bottom_right)) : r
            border.width: Number(bar.cfg.border_width || 0)
            border.color: Theme.resolve(bar.cfg.border || "outline")
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animNormal
                }
            }
        }

        Item {
            id: sections
            anchors.fill: parent
            anchors.leftMargin: bar.vertical ? 0 : bar.padding
            anchors.rightMargin: bar.vertical ? 0 : bar.padding
            anchors.topMargin: bar.vertical ? bar.padding : 0
            anchors.bottomMargin: bar.vertical ? bar.padding : 0
            opacity: bar.revealed ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animNormal
                }
            }

            BarSection {
                id: startSection
                bar: bar
                names: bar.cfg.start || []
                x: 0
                y: bar.vertical ? 0 : (parent.height - height) / 2
                anchors.horizontalCenter: bar.vertical ? parent.horizontalCenter : undefined
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
