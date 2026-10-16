import QtQuick
import qs.Commons

// Text input with noctalia input styling (surface fill, outline border, secondary focus ring).
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property real fontSize: Style.fontSizeBody

    signal accepted
    signal escapePressed
    signal keyNavigation(int key)

    implicitHeight: Style.controlHeight
    implicitWidth: 240
    radius: Style.radiusLg
    color: Theme.surface
    border.color: input.activeFocus ? Theme.secondary : Theme.outline
    border.width: input.activeFocus ? Style.focusRingWidth : Style.borderWidth

    function focusInput() {
        input.forceActiveFocus();
    }

    NIcon {
        id: leading
        visible: root.icon !== ""
        icon: root.icon
        size: root.fontSize + 2
        color: Theme.fgSurfaceVariant
        anchors.left: parent.left
        anchors.leftMargin: Style.spaceMd
        anchors.verticalCenter: parent.verticalCenter
    }

    TextInput {
        id: input
        anchors.left: leading.visible ? leading.right : parent.left
        anchors.leftMargin: leading.visible ? Style.spaceSm : Style.spaceMd
        anchors.right: parent.right
        anchors.rightMargin: Style.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        font.family: Style.fontFamily
        font.pixelSize: root.fontSize
        color: Theme.fgSurface
        selectionColor: Theme.alpha(Theme.primary, 0.4)
        selectedTextColor: Theme.fgSurface
        clip: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        onAccepted: root.accepted()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.escapePressed();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp || (event.key === Qt.Key_Left && cursorPosition === 0 && text.length === 0) || (event.key === Qt.Key_Right && text.length === 0)) {
                root.keyNavigation(event.key);
                event.accepted = true;
            }
        }

        NText {
            anchors.fill: parent
            text: root.placeholder
            muted: true
            size: root.fontSize
            visible: input.text.length === 0
        }
    }
}
