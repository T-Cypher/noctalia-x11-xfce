import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

// Running windows (X11 _NET_CLIENT_LIST) + pinned apps.
BarWidget {
    id: root

    readonly property bool allOutputs: settings.show_all_outputs === true
    readonly property bool onlyActiveWorkspace: settings.only_active_workspace !== undefined ? settings.only_active_workspace === true : true
    readonly property real iconSize: Math.round(18 * contentScale * Number(settings.icon_scale !== undefined ? settings.icon_scale : 1))
    readonly property bool showTitles: settings.show_window_title === true
    readonly property int titleMaxWidth: Number(settings.window_title_max_width || 100)
    readonly property var pinned: Array.isArray(settings.pinned) ? settings.pinned : []

    readonly property var windows: X11.windows.filter(w => !w.skipTaskbar && (!onlyActiveWorkspace || w.desktop === X11.currentDesktop || w.desktop === -1) && (allOutputs || !bar || X11.onScreen(w, bar.screenRef)))
    readonly property var pinnedIdle: pinned.filter(id => !windows.some(w => String(w.appId).toLowerCase() === String(id).toLowerCase() || String(w.instance).toLowerCase() === String(id).toLowerCase()))

    hideWidget: windows.length === 0 && pinnedIdle.length === 0
    padding: Style.spaceXs * contentScale
    defaultActions: ({
            scroll_up: function () {
                root.cycle(-1);
            },
            scroll_down: function () {
                root.cycle(1);
            }
        })

    function cycle(delta) {
        if (windows.length === 0)
            return;
        var idx = windows.findIndex(w => w.id === X11.activeId);
        var n = (idx + delta + windows.length) % windows.length;
        X11.activate(windows[n].id);
    }

    Grid {
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: Number(root.settings.item_spacing !== undefined ? root.settings.item_spacing : 4) * root.contentScale
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: root.pinnedIdle
            delegate: Item {
                id: pinItem
                required property var modelData
                readonly property var entry: Apps.byId(modelData) || Apps.entryForClass(modelData, modelData)
                width: root.iconSize + 6
                height: root.capsuleThickness
                opacity: Number(root.settings.pinned_opacity !== undefined ? root.settings.pinned_opacity : 0.5)
                NAppIcon {
                    anchors.centerIn: parent
                    size: root.iconSize
                    source: pinItem.entry ? Apps.iconFor(pinItem.entry) : Apps.iconForClass(pinItem.modelData, pinItem.modelData)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (pinItem.entry)
                        Apps.launch(pinItem.entry)
                }
            }
        }

        Repeater {
            model: root.windows
            delegate: Item {
                id: task
                required property var modelData
                readonly property bool active: modelData.id === X11.activeId && !modelData.minimized
                width: row.width + 6
                height: root.vertical ? root.iconSize + 8 : root.capsuleThickness

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusMd
                    color: Theme.fgSurface
                    opacity: taskMouse.containsMouse ? 0.12 : 0
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: Style.spaceXs
                    NAppIcon {
                        size: root.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        source: Apps.iconForClass(task.modelData.appId, task.modelData.instance)
                        opacity: task.active ? Number(root.settings.active_opacity !== undefined ? root.settings.active_opacity : 1) : (task.modelData.minimized ? 0.5 : Number(root.settings.inactive_opacity !== undefined ? root.settings.inactive_opacity : 1))
                    }
                    NText {
                        visible: root.showTitles && !root.vertical
                        width: Math.min(implicitWidth, root.titleMaxWidth)
                        text: task.modelData.title
                        size: root.fontSize * 0.95
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    visible: root.settings.show_active_indicator !== false && (task.active || task.modelData.urgent)
                    width: root.vertical ? 3 : Math.max(6, root.iconSize * 0.45)
                    height: root.vertical ? Math.max(6, root.iconSize * 0.45) : 3
                    radius: 1.5
                    color: task.modelData.urgent ? Theme.error : Theme.resolve(root.settings.active_indicator_color || "primary")
                    anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                    anchors.bottom: root.vertical ? undefined : parent.bottom
                    anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
                    anchors.left: root.vertical ? parent.left : undefined
                }

                MouseArea {
                    id: taskMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton)
                            X11.close(task.modelData.id);
                        else if (mouse.button === Qt.RightButton)
                            X11.minimize(task.modelData.id);
                        else
                            X11.toggle(task.modelData.id);
                    }
                    onContainsMouseChanged: {
                        if (!root.bar)
                            return;
                        if (containsMouse)
                            root.bar.showTooltip(task, task.modelData.title);
                        else
                            root.bar.hideTooltip(task);
                    }
                }
            }
        }
    }
}
