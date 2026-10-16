import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."
import "../../../Commons/Util.js" as Util

BarWidget {
    id: root

    readonly property int warning: Number(settings.warning_threshold !== undefined ? settings.warning_threshold : 15)
    readonly property bool low: Power.percent <= warning && !Power.charging
    readonly property string labelContent: settings.label_content || "percent"
    readonly property string displayMode: settings.display_mode || "glyph"

    hideWidget: !Power.hasBattery || (settings.hide_when_plugged === true && Power.pluggedIn) || (settings.hide_when_full === true && Power.fullyCharged)
    tooltipText: Power.stateText() + " · " + Power.percent + "%" + (Power.charging && Power.timeToFull > 0 ? "\n" + I18n.tr("power.battery.tooltip.time-to-full", "Time to Full") + ": " + Util.formatDuration(Power.timeToFull) : (!Power.pluggedIn && Power.timeToEmpty > 0 ? "\n" + I18n.tr("power.battery.tooltip.time-left", "Time Left") + ": " + Util.formatDuration(Power.timeToEmpty) : ""))

    Row {
        spacing: Style.spaceXs * root.contentScale

        NIcon {
            visible: root.displayMode !== "graphic" && root.displayMode !== "none"
            icon: Power.batteryGlyph()
            size: root.glyphSize
            color: root.low ? Theme.resolve(root.settings.warning_color || "error") : (Power.charging ? Theme.primary : root.iconColor(Theme.fgSurface))
            anchors.verticalCenter: parent.verticalCenter
        }

        // "graphic" mode: a small battery outline filled to the charge level
        Item {
            visible: root.displayMode === "graphic"
            width: root.glyphSize * 1.5
            height: root.glyphSize * 0.75
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                id: shell
                width: parent.width - 2
                height: parent.height
                radius: 3
                color: "transparent"
                border.color: Theme.fgSurface
                border.width: 1.5
                Rectangle {
                    x: 2.5
                    y: 2.5
                    height: parent.height - 5
                    width: Math.max(0, (parent.width - 5) * Power.percent / 100)
                    radius: 1.5
                    color: root.low ? Theme.error : (Power.charging ? Theme.primary : Theme.fgSurface)
                }
            }
            Rectangle {
                anchors.left: shell.right
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height * 0.4
                color: Theme.fgSurface
            }
        }

        NText {
            visible: root.settings.show_label !== false && !root.vertical
            text: root.labelContent === "time" ? Util.formatDuration(Power.charging ? Power.timeToFull : Power.timeToEmpty) : (root.labelContent === "rate" ? Math.abs(Power.changeRate).toFixed(1) + "W" : Power.percent + "%")
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            color: root.low ? Theme.error : Theme.fgSurface
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
