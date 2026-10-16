import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

// StatusNotifierItem tray (XEmbed-only apps need snixembed / xembedsniproxy on X11).
BarWidget {
    id: root

    readonly property var hiddenIds: Array.isArray(settings.hidden) ? settings.hidden : []
    readonly property bool hidePassive: settings.hide_passive !== false
    readonly property var items: SystemTray.items.values.filter(i => i && hiddenIds.indexOf(i.id) < 0 && !(hidePassive && i.status === Status.Passive))
    readonly property real iconSize: Math.round(16 * contentScale)

    hideWidget: items.length === 0
    padding: Style.spaceXs * contentScale

    Grid {
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: Style.spaceSm * root.contentScale
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: root.items
            delegate: Item {
                id: trayItem
                required property var modelData
                width: root.iconSize + 4
                height: root.iconSize + 4

                IconImage {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    source: trayItem.modelData.icon
                    asynchronous: true
                    mipmap: true
                }

                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        var it = trayItem.modelData;
                        if (mouse.button === Qt.LeftButton && !it.onlyMenu) {
                            it.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            it.secondaryActivate();
                        } else if (it.hasMenu) {
                            var o = root.bar.origin(trayItem);
                            Panels.toggle("tray-menu", o.screen, it.id, o.anchor, o.bar, it);
                        } else {
                            it.activate();
                        }
                    }
                    onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false)
                    onContainsMouseChanged: {
                        var it = trayItem.modelData;
                        var tip = it.tooltipTitle || it.title || it.id;
                        if (containsMouse)
                            root.bar.showTooltip(trayItem, tip);
                        else
                            root.bar.hideTooltip(trayItem);
                    }
                }
            }
        }
    }
}
