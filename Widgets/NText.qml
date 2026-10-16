import QtQuick
import qs.Commons

Text {
    id: root

    property real size: Style.fontSizeBody
    property int weight: Font.Normal
    property bool muted: false

    font.family: Style.fontFamily
    font.pixelSize: Math.max(1, Math.round(size))
    font.weight: weight
    color: muted ? Theme.fgSurfaceVariant : Theme.fgSurface
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }
}
