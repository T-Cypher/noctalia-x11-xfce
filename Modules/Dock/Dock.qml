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

    readonly property var cfg: Config.get("dock", {})
    readonly property string position: ["top", "bottom", "left", "right"].indexOf(String(cfg.position)) >= 0 ? String(cfg.position) : "bottom"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real iconSize: Number(cfg.icon_size || 48) * Style.uiScale
    readonly property real mainPad: Number(cfg.main_axis_padding !== undefined ? cfg.main_axis_padding : 16) * Style.uiScale
    readonly property real crossPad: Number(cfg.cross_axis_padding !== undefined ? cfg.cross_axis_padding : 8) * Style.uiScale
    readonly property real spacing: Number(cfg.item_spacing !== undefined ? cfg.item_spacing : 6) * Style.uiScale
    readonly property real marginEdge: Number(cfg.margin_edge !== undefined ? cfg.margin_edge : 8) * Style.uiScale
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
    visible: !hiddenByIpc && items.length > 0 && (!activeOnly || (X11.activeWindow ? X11.screenOf(X11.activeWindow) === screenRef : screenRef === Quickshell.screens[0]))

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
        radius: Style.radius(Number(dock.cfg.radius !== undefined ? dock.cfg.radius : 16))
        color: Theme.alpha(Theme.surface, Number(dock.cfg.background_opacity !== undefined ? dock.cfg.background_opacity : 0.88))
        border.color: Theme.outline
        border.width: Style.borderWidth
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
                    anchors.horizontalCenter: dock.vertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: dock.vertical ? parent.verticalCenter : undefined
                    anchors.bottom: dock.position === "bottom" ? parent.bottom : undefined
                    anchors.top: dock.position === "top" ? parent.top : undefined
                    anchors.left: dock.position === "left" ? parent.left : undefined
                    anchors.right: dock.position === "right" ? parent.right : undefined
                    source: cell.modelData.entry ? Apps.iconFor(cell.modelData.entry) : (cell.running ? Apps.iconForClass(cell.modelData.windows[0].appId, cell.modelData.windows[0].instance) : "")
                    opacity: cell.active ? Number(dock.cfg.active_opacity || 1) : Number(dock.cfg.inactive_opacity || 0.85)
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // running indicator
                Row {
                    visible: cell.running
                    spacing: 3
                    anchors.horizontalCenter: dock.vertical ? undefined : parent.horizontalCenter
                    anchors.verticalCenter: dock.vertical ? parent.verticalCenter : undefined
                    anchors.bottom: dock.position === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: -dock.crossPad * 0.7
                    anchors.top: dock.position === "top" ? parent.top : undefined
                    anchors.topMargin: -dock.crossPad * 0.7
                    Repeater {
                        model: dock.cfg.show_instance_count !== false ? Math.min(3, cell.modelData.windows.length) : 1
                        delegate: Rectangle {
                            width: cell.active ? 10 : 5
                            height: 4
                            radius: 2
                            color: cell.active ? Theme.primary : Theme.fgSurfaceVariant
                        }
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
