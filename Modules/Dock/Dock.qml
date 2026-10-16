pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// noctalia dock ([dock]): pinned + running applications from the X11 bridge, magnification,
// active/inactive scaling and opacity, instance indicators and optional auto-hide.
PanelWindow {
    id: dock

    required property var screenRef
    screen: screenRef

    // [dock] with [dock.monitor.<x>] overrides (first match wins)
    readonly property var cfg: Config.barForScreen(Config.get("dock", {}), screenRef)
    readonly property string position: ["top", "bottom", "left", "right"].indexOf(String(cfg.position)) >= 0 ? String(cfg.position) : "bottom"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real iconSize: Number(cfg.icon_size || 48) * Style.uiScale
    readonly property real mainPad: Number(cfg.main_axis_padding !== undefined ? cfg.main_axis_padding : 16) * Style.uiScale
    readonly property real crossPad: Number(cfg.cross_axis_padding !== undefined ? cfg.cross_axis_padding : 8) * Style.uiScale
    readonly property real spacing: Number(cfg.item_spacing !== undefined ? cfg.item_spacing : 6) * Style.uiScale
    readonly property real marginEdge: Number(cfg.margin_edge !== undefined ? cfg.margin_edge : 0) * Style.uiScale
    // Flush with the screen edge (margin_edge = 0): noctalia flares the edge corners concavely;
    // here the edge-side corners are drawn square so the dock meets the edge cleanly.
    readonly property bool flush: marginEdge === 0 && cfg.concave_edge_corners !== false
    readonly property real magnify: cfg.magnification !== false ? Number(cfg.magnification_scale || 1.45) : 1
    readonly property bool autoHide: cfg.auto_hide === true
    readonly property bool hiddenByIpc: ShellState.get("dock_hidden", false) === true
    readonly property bool activeOnly: cfg.active_monitor_only === true
    property bool hovered: false
    readonly property bool revealed: !autoHide || hovered
    readonly property real thickness: iconSize + crossPad * 2

    readonly property var pinned: Array.isArray(cfg.pinned) ? cfg.pinned : []
    readonly property var windows: X11.windows.filter(w => !w.skipTaskbar && (Quickshell.screens.length <= 1 || X11.onScreen(w, screenRef)))

    // group windows by app, keep pinned order first
    readonly property var items: {
        var out = [];
        var byKey = {};
        function keyOf(w) {
            return String(w.appId || w.instance).toLowerCase();
        }
        pinned.forEach(id => {
            var k = String(id).toLowerCase().replace(/\.desktop$/, "");
            var entry = Apps.byId(id) || Apps.byId(k) || DesktopEntries.heuristicLookup(k);
            var item = {
                key: k,
                entry: entry,
                windows: [],
                pinned: true
            };
            byKey[k] = item;
            out.push(item);
        });
        if (cfg.show_running !== false) {
            windows.forEach(w => {
                var k = keyOf(w);
                var inst = String(w.instance).toLowerCase();
                var item = byKey[k] || byKey[inst];
                if (!item) {
                    // match pinned entries through their desktop entry startup class / id
                    for (var i = 0; i < out.length && !item; i++) {
                        var e = out[i].entry;
                        if (e && (String(e.startupClass).toLowerCase() === k || String(e.id).toLowerCase() === k || String(e.id).toLowerCase() === inst))
                            item = out[i];
                    }
                }
                if (!item) {
                    item = {
                        key: k,
                        entry: Apps.entryForClass(w.appId, w.instance),
                        windows: [],
                        pinned: false
                    };
                    byKey[k] = item;
                    out.push(item);
                }
                item.windows.push(w);
            });
        }
        return out;
    }

    anchors.bottom: position === "bottom"
    anchors.top: position === "top"
    anchors.left: position === "left"
    anchors.right: position === "right"
    margins.bottom: position === "bottom" ? marginEdge : 0
    margins.top: position === "top" ? marginEdge : 0
    margins.left: position === "left" ? marginEdge : 0
    margins.right: position === "right" ? marginEdge : 0

    implicitWidth: vertical ? (revealed ? thickness * Math.max(1, magnify * 0.92) : 4) : Math.max(thickness, row.implicitWidth + mainPad * 2)
    implicitHeight: vertical ? Math.max(thickness, row.implicitHeight + mainPad * 2) : (revealed ? thickness * Math.max(1, magnify * 0.92) : 4)
    exclusionMode: cfg.reserve_space !== false && !autoHide ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: thickness + marginEdge
    aboveWindows: true
    focusable: false
    color: "transparent"
    visible: !hiddenByIpc && cfg.enabled !== false && Config.screenAllowed(cfg.monitors, screenRef) && items.length > 0 && (!activeOnly || (X11.activeWindow ? X11.screenOf(X11.activeWindow) === screenRef : screenRef === Quickshell.screens[0]))

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                hideTimer.stop();
                dock.hovered = true;
            } else {
                hideTimer.restart();
            }
        }
    }
    Timer {
        id: hideTimer
        interval: 400
        onTriggered: dock.hovered = false
    }

    Rectangle {
        id: bg
        // background hugs the bar edge; the magnified icons may overflow it
        width: dock.vertical ? dock.thickness : parent.width
        height: dock.vertical ? parent.height : dock.thickness
        x: dock.position === "right" ? parent.width - width : 0
        y: dock.position === "bottom" ? parent.height - height : 0
        readonly property real r: Math.min(Style.radius(Number(dock.cfg.radius !== undefined ? dock.cfg.radius : 16)), Math.min(width, height) / 2)
        topLeftRadius: dock.flush && (dock.position === "top" || dock.position === "left") ? 0 : r
        topRightRadius: dock.flush && (dock.position === "top" || dock.position === "right") ? 0 : r
        bottomLeftRadius: dock.flush && (dock.position === "bottom" || dock.position === "left") ? 0 : r
        bottomRightRadius: dock.flush && (dock.position === "bottom" || dock.position === "right") ? 0 : r
        color: Theme.alpha(Theme.surface, Number(dock.cfg.background_opacity !== undefined ? dock.cfg.background_opacity : 0.88))
        border.color: Theme.resolve(dock.cfg.border || "outline", Theme.outline)
        border.width: Math.max(0, Number(dock.cfg.border_width !== undefined ? dock.cfg.border_width : 0))
        opacity: dock.revealed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.animNormal
            }
        }
    }

    Grid {
        id: row
        rows: dock.vertical ? -1 : 1
        columns: dock.vertical ? 1 : -1
        spacing: dock.spacing
        anchors.centerIn: bg
        verticalItemAlignment: dock.position === "top" ? Grid.AlignTop : Grid.AlignBottom
        horizontalItemAlignment: dock.position === "left" ? Grid.AlignLeft : Grid.AlignRight
        opacity: dock.revealed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.animNormal
            }
        }

        Repeater {
            model: dock.items
            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool running: modelData.windows.length > 0
                readonly property bool active: modelData.windows.some(w => w.id === X11.activeId && !w.minimized)
                readonly property real s: (mouse.containsMouse ? dock.magnify : 1) * (active ? Number(dock.cfg.active_scale || 1) : (running ? 1 : Number(dock.cfg.inactive_scale || 0.85)))
                width: dock.iconSize
                height: dock.iconSize

                NAppIcon {
                    id: icon
                    width: dock.iconSize * cell.s
                    height: width
                    size: width
                    // grow away from the docked screen edge
                    x: dock.position === "left" ? 0 : (dock.position === "right" ? parent.width - width : (parent.width - width) / 2)
                    y: dock.position === "top" ? 0 : (dock.position === "bottom" ? parent.height - height : (parent.height - height) / 2)
                    source: cell.modelData.entry ? Apps.iconFor(cell.modelData.entry) : (cell.running ? Apps.iconForClass(cell.modelData.windows[0].appId, cell.modelData.windows[0].instance) : "")
                    opacity: cell.active ? Number(dock.cfg.active_opacity || 1) : Number(dock.cfg.inactive_opacity || 0.85)
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // show_dots: up to three window dots on the screen-edge side (primary when active)
                readonly property real dot: Math.max(4, Math.round(dock.iconSize * 0.09))
                Grid {
                    visible: dock.cfg.show_dots === true && cell.running
                    rows: dock.vertical ? -1 : 1
                    columns: dock.vertical ? 1 : -1
                    spacing: 3
                    x: dock.position === "left" ? -dock.crossPad * 0.7 : (dock.position === "right" ? parent.width - width + dock.crossPad * 0.7 : (parent.width - width) / 2)
                    y: dock.position === "top" ? -dock.crossPad * 0.7 : (dock.position === "bottom" ? parent.height - height + dock.crossPad * 0.7 : (parent.height - height) / 2)
                    Repeater {
                        model: Math.min(3, cell.modelData.windows.length)
                        delegate: Rectangle {
                            width: cell.dot
                            height: cell.dot
                            radius: cell.dot / 2
                            color: cell.active ? Theme.primary : Theme.secondary
                        }
                    }
                }

                // show_instance_count: window count badge (>= 2) on the screen-interior corner
                Rectangle {
                    readonly property real bd: Math.max(16, dock.iconSize * 0.3)
                    readonly property int count: cell.modelData.windows.length
                    visible: dock.cfg.show_instance_count !== false && count >= 2
                    width: bd
                    height: bd
                    radius: bd / 2
                    color: Theme.primary
                    x: dock.position === "right" ? icon.x - bd * (1 - 0.55) : icon.x + icon.width - bd * 0.55
                    y: dock.position === "top" ? icon.y + icon.height - bd * (1 - 0.45) : icon.y - bd * 0.45
                    NText {
                        anchors.centerIn: parent
                        text: parent.count > 9 ? "9+" : String(parent.count)
                        size: parent.bd * 0.72 * 0.75
                        weight: Font.Bold
                        color: Theme.fgPrimary
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        var item = cell.modelData;
                        if (event.button === Qt.MiddleButton || (!cell.running && event.button === Qt.LeftButton)) {
                            if (item.entry)
                                Apps.launch(item.entry);
                            return;
                        }
                        if (event.button === Qt.RightButton) {
                            item.windows.forEach(w => X11.minimize(w.id));
                            return;
                        }
                        // cycle through the app's windows
                        var wins = item.windows;
                        var idx = wins.findIndex(w => w.id === X11.activeId);
                        if (wins.length === 1)
                            X11.toggle(wins[0].id);
                        else
                            X11.activate(wins[(idx + 1) % wins.length].id);
                    }
                }
            }
        }
    }
}
