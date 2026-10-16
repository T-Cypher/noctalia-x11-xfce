import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    hideWidget: !Brightness.available && settings.show_when_unavailable !== true
    tooltipText: I18n.tr("bar.widgets.brightness.brightness", "Brightness") + ": " + Math.round(Brightness.brightness * 100) + "%"
    defaultActions: ({
            left: "panel-toggle control-center monitor",
            scroll_up: "brightness-up",
            scroll_down: "brightness-down"
        })

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            icon: Brightness.brightness < 0.5 ? "brightness-low" : "brightness-high"
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.settings.show_label !== false && !root.vertical && Brightness.available
            text: Math.round(Brightness.brightness * 100) + "%"
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
