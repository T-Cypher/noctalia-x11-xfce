import QtQuick
import qs.Commons

// Toggle switch (medium preset from noctalia style.h)
Item {
    id: root

    property bool checked: false
    property bool enabled_: true
    signal toggled(bool checked)

    readonly property real thumb: Style.toggleThumbSize
    readonly property real inset: Style.toggleInset
    readonly property real travel: Style.toggleTravel

    implicitWidth: thumb + inset * 2 + travel
    implicitHeight: thumb + inset * 2
    opacity: enabled_ ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceVariant
        border.color: root.checked ? Theme.primary : Theme.outline
        border.width: Style.borderWidth
        Behavior on color {
            ColorAnimation {
                duration: Style.animFast
            }
        }

        Rectangle {
            width: root.thumb
            height: root.thumb
            radius: width / 2
            y: root.inset
            x: root.checked ? root.inset + root.travel : root.inset
            color: root.checked ? Theme.fgPrimary : (mouse.containsMouse ? Theme.hover : Theme.fgSurfaceVariant)
            Behavior on x {
                NumberAnimation {
                    duration: Style.animNormal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Style.animFast
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled_
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
