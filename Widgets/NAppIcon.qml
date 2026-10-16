import QtQuick
import Quickshell.Widgets
import qs.Commons

// Application icon (theme icon or file) with a glyph fallback.
Item {
    id: root

    property string source: ""          // resolved path (Quickshell.iconPath) or URL
    property string fallbackGlyph: "app-window"
    property real size: 24
    property bool colorize: Config.get("shell.app_icon_colorize", false) === true

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.fill: parent
        source: root.source
        visible: root.source !== "" && status !== Image.Error
        asynchronous: true
        mipmap: true
    }

    NIcon {
        anchors.centerIn: parent
        visible: !img.visible || img.status === Image.Error
        icon: root.fallbackGlyph
        size: root.size * 0.8
        color: Theme.fgSurfaceVariant
    }
}
