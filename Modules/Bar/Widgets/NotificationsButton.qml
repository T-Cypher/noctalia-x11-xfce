import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property int unread: Notifications.unread
    hideWidget: settings.hide_when_no_unread === true && unread === 0 && !Notifications.dnd
    tooltipText: Notifications.dnd ? I18n.tr("osd.dnd.on", "DND On") : (unread > 0 ? unread + " " + I18n.tr("notifications.unread", "unread") : I18n.tr("control-center.tabs.notifications", "Notifications"))

    Item {
        width: root.glyphSize
        height: root.glyphSize

        NIcon {
            anchors.centerIn: parent
            icon: Notifications.dnd ? "bell-off" : (root.unread > 0 ? "bell-ringing" : "bell")
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
        }

        Rectangle {
            visible: root.unread > 0 && !Notifications.dnd
            width: Math.max(6, root.glyphSize * 0.4)
            height: width
            radius: width / 2
            color: Theme.error
            border.color: Theme.surface
            border.width: 1.5
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -1
        }
    }
}
