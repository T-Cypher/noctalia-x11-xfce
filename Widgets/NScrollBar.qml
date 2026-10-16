import QtQuick
import qs.Commons

// Overlay scrollbar for a Flickable (thin at rest, wider on hover like noctalia).
Item {
    id: root

    property Flickable flickable: null
    readonly property bool needed: flickable !== null && flickable.contentHeight > flickable.height + 1
    readonly property real ratio: needed ? flickable.height / flickable.contentHeight : 1
    readonly property real maxY: needed ? flickable.contentHeight - flickable.height : 0

    width: hover.containsMouse || drag.pressed ? Style.scrollbarHoverWidth : Style.scrollbarWidth
    visible: needed
    Behavior on width {
        NumberAnimation {
            duration: Style.animFast
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(Theme.outline, hover.containsMouse ? 0.5 : 0.0)
    }

    Rectangle {
        id: thumb
        width: parent.width
        radius: width / 2
        height: Math.max(32, root.height * root.ratio)
        y: root.maxY > 0 ? (root.flickable.contentY / root.maxY) * (root.height - height) : 0
        color: Theme.alpha(Theme.fgSurfaceVariant, drag.pressed ? 0.8 : 0.5)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.leftMargin: -6
        hoverEnabled: true
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        property real startY: 0
        property real startContent: 0
        onPressed: mouse => {
            startY = mouse.y;
            startContent = root.flickable.contentY;
            if (mouse.y < thumb.y || mouse.y > thumb.y + thumb.height) {
                var r = mouse.y / root.height;
                root.flickable.contentY = Math.max(0, Math.min(root.maxY, r * root.maxY));
                startContent = root.flickable.contentY;
            }
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            var dy = mouse.y - startY;
            var scale = root.maxY / Math.max(1, root.height - thumb.height);
            root.flickable.contentY = Math.max(0, Math.min(root.maxY, startContent + dy * scale));
        }
    }
}
