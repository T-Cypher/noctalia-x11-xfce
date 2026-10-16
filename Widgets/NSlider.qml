import QtQuick
import qs.Commons

// Horizontal slider: track (surface_variant), fill (primary), thumb.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0.01
    property bool live: true
    property color fillColor: Theme.primary
    readonly property bool dragging: mouse.pressed
    property real dragValue: value

    signal moved(real value)
    signal released(real value)

    implicitWidth: 180
    implicitHeight: Style.sliderThumbSize

    readonly property real shown: dragging ? dragValue : value
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: Style.sliderThumbSize / 2
        width: parent.width - Style.sliderThumbSize
        height: Style.sliderTrackHeight
        radius: height / 2
        color: Theme.surfaceVariant
        border.color: Theme.alpha(Theme.outline, 0.6)
        border.width: Style.borderWidth

        Rectangle {
            width: Math.max(height, track.width * root.ratio)
            height: parent.height
            radius: height / 2
            color: root.fillColor
            visible: root.ratio > 0
        }
    }

    Rectangle {
        id: thumb
        width: Style.sliderThumbSize
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: track.x + track.width * root.ratio - width / 2
        color: mouse.containsMouse || mouse.pressed ? Theme.hover : Theme.fgSurface
        border.color: Theme.surface
        border.width: 2
        Behavior on color {
            ColorAnimation {
                duration: Style.animFast
            }
        }
    }

    function valueAt(px) {
        var r = Math.max(0, Math.min(1, (px - track.x) / Math.max(1, track.width)));
        var v = from + r * (to - from);
        if (stepSize > 0)
            v = Math.round(v / stepSize) * stepSize;
        return Math.max(from, Math.min(to, v));
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => {
            root.dragValue = root.valueAt(mouse.x);
            if (root.live)
                root.moved(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.dragValue = root.valueAt(mouse.x);
            if (root.live)
                root.moved(root.dragValue);
        }
        onReleased: {
            root.moved(root.dragValue);
            root.released(root.dragValue);
        }
        onWheel: wheel => {
            var d = (wheel.angleDelta.y > 0 ? 1 : -1) * Math.max(root.stepSize, (root.to - root.from) / 20);
            var v = Math.max(root.from, Math.min(root.to, root.value + d));
            root.moved(v);
            root.released(v);
        }
    }
}
