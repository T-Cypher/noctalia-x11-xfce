pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd

        NCard {
            id: battery
            visible: Power.hasBattery
            width: parent.width
            height: visible ? 120 * Style.uiScale : 0
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Style.cardPadding * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.spaceLg
                NIcon {
                    icon: Power.batteryGlyph()
                    size: 56 * Style.uiScale
                    color: Power.charging ? Theme.primary : (Power.percent <= 15 ? Theme.error : Theme.fgSurface)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    NText {
                        text: Power.percent + "%"
                        size: 30 * Style.uiScale
                        weight: Font.Bold
                    }
                    NText {
                        text: Power.stateText() + (Power.charging && Power.timeToFull > 0 ? " · " + Util.formatDuration(Power.timeToFull) : (!Power.pluggedIn && Power.timeToEmpty > 0 ? " · " + Util.formatDuration(Power.timeToEmpty) : ""))
                    }
                    NText {
                        visible: Power.health >= 0 || Power.changeRate !== 0
                        text: [Power.health >= 0 ? I18n.tr("power.battery.tooltip.health", "Health") + " " + Math.round(Power.health) + "%" : "", Power.changeRate !== 0 ? Math.abs(Power.changeRate).toFixed(1) + " W" : ""].filter(x => x).join("  ·  ")
                        size: Style.fontSizeCaption
                        muted: true
                    }
                }
            }
        }

        NCard {
            id: profiles
            visible: Power.profilesAvailable
            width: parent.width
            height: visible ? profCol.implicitHeight + Style.cardPadding * 2 : 0
            Column {
                id: profCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                SectionLabel {
                    text: I18n.tr("control-center.power.power-profile", "Power profile")
                }
                Row {
                    width: parent.width
                    spacing: Style.spaceSm
                    Repeater {
                        model: Power.hasPerformance ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]
                        delegate: NButton {
                            required property var modelData
                            width: (profCol.width - Style.spaceSm * (Power.hasPerformance ? 2 : 1)) / (Power.hasPerformance ? 3 : 2)
                            icon: Power.profileGlyph(modelData)
                            text: Power.profileLabel(modelData)
                            variant: Power.profileName === modelData ? "tabActive" : "default"
                            onClicked: Power.setProfile(modelData)
                        }
                    }
                }
            }
        }

        NCard {
            visible: Power.otherDevices.length > 0
            width: parent.width
            height: visible ? devCol.implicitHeight + Style.cardPadding * 2 : 0
            Column {
                id: devCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceXs
                SectionLabel {
                    text: I18n.tr("control-center.power.peripherals", "Connected Devices")
                }
                Repeater {
                    model: Power.otherDevices
                    delegate: ListRow {
                        required property var modelData
                        width: devCol.width
                        glyph: modelData.type === UPowerDeviceType.Mouse ? "mouse-2" : modelData.type === UPowerDeviceType.Keyboard ? "keyboard" : modelData.type === UPowerDeviceType.Phone ? "device-mobile" : "battery-2"
                        title: modelData.model || UPowerDeviceType.toString(modelData.type)
                        subtitle: Math.round(modelData.percentage * 100) + "%"
                        clickable: false
                    }
                }
            }
        }
    }
}
