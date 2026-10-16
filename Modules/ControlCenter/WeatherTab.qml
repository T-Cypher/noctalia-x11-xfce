pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    readonly property var cur: Weather.current

    NText {
        anchors.centerIn: parent
        visible: root.cur === null
        text: Weather.error !== "" ? Weather.error : (Weather.hasLocation ? I18n.tr("desktop-widgets.weather.loading", "Loading…") : "Set [location] address, coordinates or auto_locate")
        muted: true
    }

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd
        visible: root.cur !== null

        NCard {
            id: now
            width: parent.width
            height: 130 * Style.uiScale
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.cardPadding * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spaceLg
                NIcon {
                    icon: root.cur ? Weather.glyphFor(root.cur.code, root.cur.isDay) : "weather-cloud"
                    size: 64 * Style.uiScale
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    NText {
                        text: root.cur ? Math.round(root.cur.temp) + Weather.unitSymbol : ""
                        size: 34 * Style.uiScale
                        weight: Font.Bold
                    }
                    NText {
                        text: root.cur ? Weather.describe(root.cur.code) + "  ·  " + Weather.locationName : ""
                    }
                    NText {
                        text: root.cur ? I18n.tr("control-center.weather.details.feels-like", "Feels like") + " " + Weather.temp(root.cur.feels) + "  ·  " + Math.round(root.cur.wind) + (Weather.fahrenheit ? " mph" : " km/h") + "  ·  " + root.cur.humidity + "%" : ""
                        size: Style.fontSizeCaption
                        muted: true
                    }
                }
            }
        }

        NCard {
            width: parent.width
            height: parent.height - now.height - parent.spacing
            Row {
                id: days
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                Repeater {
                    model: Weather.daily
                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: (days.width - days.spacing * 6) / 7
                        spacing: Style.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        NText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index === 0 ? I18n.tr("control-center.calendar.today", "Today") : Qt.locale().dayName(new Date(modelData.date + "T12:00").getDay(), 1)
                            size: Style.fontSizeCaption
                            weight: Font.Medium
                        }
                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: Weather.glyphFor(modelData.code, true)
                            size: 26 * Style.uiScale
                            color: Theme.primary
                        }
                        NText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.temp(modelData.max)
                            weight: Font.Bold
                        }
                        NText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.temp(modelData.min)
                            muted: true
                            size: Style.fontSizeCaption
                        }
                    }
                }
            }
        }
    }
}
