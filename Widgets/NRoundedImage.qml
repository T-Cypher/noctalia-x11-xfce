import QtQuick
import Quickshell.Widgets
import qs.Commons

// Image clipped to a rounded rectangle / circle.
ClippingRectangle {
    id: root

    property string source: ""
    property int fillMode: Image.PreserveAspectCrop
    property string fallbackGlyph: "photo"
    property real glyphSize: Math.min(width, height) * 0.45
    readonly property bool hasImage: img.status === Image.Ready

    color: Theme.surfaceVariant
    radius: Style.radiusLg

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
        sourceSize.width: Math.max(64, root.width * 2)
        sourceSize.height: Math.max(64, root.height * 2)
    }

    NIcon {
        anchors.centerIn: parent
        visible: !root.hasImage && root.fallbackGlyph !== ""
        icon: root.fallbackGlyph
        size: root.glyphSize
        color: Theme.fgSurfaceVariant
    }
}
