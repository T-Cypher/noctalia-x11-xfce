pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import qs.Modules.Notifications

Item {
    id: root

    Component.onCompleted: Notifications.markRead()

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd

        NCard {
            id: head
            width: parent.width
            height: Style.controlHeightLg + Style.spaceSm
            ListRow {
                anchors.fill: parent
                anchors.margins: Style.spaceXs
                glyph: Notifications.dnd ? "bell-off" : "bell"
                title: I18n.tr("settings.schema.shell.osd-kinds-dnd.label", "Do Not Disturb")
                subtitle: Notifications.history.count + " " + I18n.tr("control-center.notifications.in-history", "in history")
                clickable: false
                NButton {
                    text: I18n.tr("control-center.notifications.clear-all", "Clear all")
                    icon: "trash"
                    height: Style.controlHeightSm
                    fontSize: Style.fontSizeCaption
                    enabled_: Notifications.history.count > 0
                    onClicked: Notifications.clearHistory()
                }
                NToggle {
                    checked: Notifications.dnd
                    onToggled: c => Notifications.setDnd(c)
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - head.height - parent.spacing

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: Style.spaceSm
                model: Notifications.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    width: list.width - Style.spaceMd
                    compact: true
                    historyMode: true
                }
            }
            NScrollBar {
                flickable: list
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }
            Column {
                anchors.centerIn: parent
                visible: list.count === 0
                spacing: Style.spaceSm
                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "bell"
                    size: 40 * Style.uiScale
                    color: Theme.fgSurfaceVariant
                }
                NText {
                    text: I18n.tr("control-center.notifications.empty-title", "No notifications")
                    muted: true
                }
            }
        }
    }
}
