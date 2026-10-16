import QtQuick
import qs.Commons
import qs.Widgets
import ".."

BarWidget {
    id: root
    tooltipText: settings.tooltip || ""
    NText {
        text: String(root.settings.text || "")
        size: root.fontSize
        weight: root.fontWeight
        font.family: root.fontFamily
        color: root.iconColor(Theme.fgSurface)
    }
}
