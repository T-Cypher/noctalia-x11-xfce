import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property var cur: Weather.current
    hideWidget: !Weather.enabled
    tooltipText: cur ? (Weather.locationName + "\n" + Weather.describe(cur.code) + " · " + Weather.temp(cur.temp) + "\n" + I18n.tr("control-center.weather.details.feels-like", "Feels like") + " " + Weather.temp(cur.feels)) : (Weather.error || I18n.tr("weather.loading", "Loading weather…"))

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            icon: root.cur ? Weather.glyphFor(root.cur.code, root.cur.isDay) : "weather-cloud-off"
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: !root.vertical && root.cur !== null && root.settings.show_temperature !== false
            text: root.cur ? Weather.temp(root.cur.temp) : ""
            size: root.fontSize
            weight: root.fontWeight
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: !root.vertical && root.cur !== null && root.settings.show_condition !== false
            width: Math.min(implicitWidth, Number(root.settings.max_length || 160) * root.contentScale)
            text: root.cur ? Weather.describe(root.cur.code) : ""
            size: root.fontSize
            muted: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
