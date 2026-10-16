import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property string label: X11.layoutLabel(settings.display, settings.custom_labels)

    hideWidget: settings.hide_when_single_layout === true && (X11.keyboard.layouts || []).length <= 1
    tooltipText: X11.layoutName

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            visible: root.settings.show_glyph !== false && root.settings.show_icon !== false
            icon: root.settings.glyph || "keyboard"
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.settings.show_label !== false
            text: root.label
            size: root.fontSize
            weight: Font.Bold
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
