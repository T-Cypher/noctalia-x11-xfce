import QtQuick
import qs.Commons

// Tabler glyph rendered with noctalia's bundled icon font.
Text {
    id: root

    property string icon: ""
    property real size: Style.baseGlyphSize

    text: Icons.glyph(icon)
    font.family: Icons.fontFamily
    font.pixelSize: Math.max(1, Math.round(size))
    color: Theme.fgSurface
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }
}
