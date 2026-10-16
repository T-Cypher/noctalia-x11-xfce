import QtQuick
import Quickshell
import qs.Commons

// Hover tooltip shown in a separate (override-redirect) popup window on X11.
// Set `target` (Item) and `text`; `edge` picks the side ("bottom", "top", "left", "right").
PopupWindow {
    id: root

    property Item target: null
    property string text: ""
    property string edge: "bottom"
    property bool shown: false
    property real gap: 6

    visible: shown && text !== "" && target !== null
    color: "transparent"
    implicitWidth: Math.min(420, label.implicitWidth + Style.spaceMd * 2)
    implicitHeight: label.implicitHeight + Style.spaceSm * 2

    anchor.item: target
    anchor.rect.x: {
        if (!target)
            return 0;
        if (edge === "left")
            return -implicitWidth - gap;
        if (edge === "right")
            return target.width + gap;
        return target.width / 2 - implicitWidth / 2;
    }
    anchor.rect.y: {
        if (!target)
            return 0;
        if (edge === "top")
            return -implicitHeight - gap;
        if (edge === "bottom")
            return target.height + gap;
        return target.height / 2 - implicitHeight / 2;
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusMd
        color: Theme.surfaceVariant
        border.color: Theme.outline
        border.width: Style.borderWidth

        NText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 420 - Style.spaceMd * 2)
            text: root.text
            size: Style.fontSizeCaption
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
