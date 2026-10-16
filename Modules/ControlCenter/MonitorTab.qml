import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd

        NCard {
            width: parent.width
            height: bCol.implicitHeight + Style.cardPadding * 2
            Column {
                id: bCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                SectionLabel {
                    text: I18n.tr("bar.widgets.brightness.brightness", "Brightness") + (Brightness.device !== "" ? " · " + Brightness.device : "")
                    width: parent.width
                }
                Row {
                    width: parent.width
                    spacing: Style.spaceSm
                    visible: Brightness.available
                    NIcon {
                        icon: "brightness-low"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    NSlider {
                        width: parent.width - Style.baseGlyphSize * 2 - pct.width - parent.spacing * 3
                        value: Brightness.brightness
                        anchors.verticalCenter: parent.verticalCenter
                        onMoved: v => Brightness.setBrightness(v)
                    }
                    NIcon {
                        icon: "brightness-high"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    NText {
                        id: pct
                        text: Math.round(Brightness.brightness * 100) + "%"
                        width: 44 * Style.uiScale
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                NText {
                    visible: !Brightness.available
                    width: parent.width
                    wrapMode: Text.Wrap
                    muted: true
                    size: Style.fontSizeCaption
                    text: "No writable backlight found. Install brightnessctl (and make sure your user may write /sys/class/backlight, e.g. via the video group or logind)."
                }
            }
        }

        NCard {
            width: parent.width
            height: nCol.implicitHeight + Style.cardPadding * 2
            Column {
                id: nCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                SectionLabel {
                    text: I18n.tr("control-center.shortcuts.nightlight", "Night Light") + (NightLight.backend !== "" ? " · " + NightLight.backend : "")
                    width: parent.width
                }
                ListRow {
                    width: parent.width
                    glyph: NightLight.enabled ? "nightlight-on" : "nightlight-off"
                    title: I18n.tr("osd.nightlight.scheduled", "Scheduled")
                    subtitle: NightLight.enabled ? (NightLight.isNight ? "Active · " + NightLight.nightTemp + "K" : "Waiting for sunset") : "Off"
                    clickable: false
                    NToggle {
                        checked: NightLight.enabled
                        onToggled: c => NightLight.setEnabled(c)
                    }
                }
                ListRow {
                    width: parent.width
                    glyph: "nightlight-forced"
                    title: I18n.tr("osd.nightlight.forced", "Always on")
                    subtitle: NightLight.backend === "" ? "Install redshift, gammastep, sct or xrandr" : ""
                    clickable: false
                    NToggle {
                        checked: NightLight.forced
                        onToggled: c => NightLight.toggleForce()
                    }
                }
            }
        }

        NCard {
            width: parent.width
            height: sCol.implicitHeight + Style.cardPadding * 2
            Column {
                id: sCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceXs
                SectionLabel {
                    text: I18n.tr("control-center.monitor.displays", "Displays")
                    width: parent.width
                }
                Repeater {
                    model: Quickshell.screens
                    delegate: NText {
                        required property var modelData
                        text: modelData.name + "  ·  " + modelData.width + "×" + modelData.height + (modelData.model ? "  ·  " + modelData.model : "")
                        size: Style.fontSizeCaption
                    }
                }
            }
        }
    }
}
