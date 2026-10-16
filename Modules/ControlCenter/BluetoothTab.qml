pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    Component.onDestruction: if (BluetoothService.discovering)
        BluetoothService.setDiscovering(false)

    NText {
        anchors.centerIn: parent
        visible: !BluetoothService.available
        text: "No Bluetooth adapter (BlueZ) found."
        muted: true
    }

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd
        visible: BluetoothService.available

        NCard {
            id: head
            width: parent.width
            height: headRow.implicitHeight + Style.cardPadding
            ListRow {
                id: headRow
                anchors.fill: parent
                anchors.margins: Style.cardPadding / 2
                glyph: BluetoothService.glyph()
                title: I18n.tr("control-center.bluetooth.bluetooth", "Bluetooth")
                subtitle: BluetoothService.adapter ? BluetoothService.adapter.name : ""
                clickable: false
                NButton {
                    visible: BluetoothService.enabled
                    height: Style.controlHeightSm
                    fontSize: Style.fontSizeCaption
                    icon: BluetoothService.discovering ? "busy" : "search"
                    text: BluetoothService.discovering ? I18n.tr("control-center.bluetooth.stop-scan", "Stop") : I18n.tr("control-center.bluetooth.scan", "Scan")
                    onClicked: BluetoothService.setDiscovering(!BluetoothService.discovering)
                }
                NToggle {
                    checked: BluetoothService.enabled
                    onToggled: c => BluetoothService.setEnabled(c)
                }
            }
        }

        NCard {
            width: parent.width
            height: parent.height - head.height - parent.spacing
            visible: BluetoothService.enabled

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Style.spaceSm
                clip: true
                spacing: 2
                model: BluetoothService.pairedDevices.concat(BluetoothService.otherDevices)
                section.property: "paired"
                delegate: ListRow {
                    required property var modelData
                    width: list.width - Style.spaceMd
                    glyph: BluetoothService.deviceGlyph(modelData)
                    title: BluetoothService.deviceName(modelData)
                    subtitle: [modelData.connected ? I18n.tr("bar.widgets.bluetooth.connected", "Connected") : (modelData.paired ? I18n.tr("control-center.bluetooth.sections.paired", "Paired") : ""), modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "", modelData.pairing ? "Pairing…" : ""].filter(x => x).join("  ·  ")
                    active: modelData.connected
                    implicitHeight: Style.controlHeightLg
                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.paired || modelData.bonded)
                            modelData.connect();
                        else {
                            modelData.trusted = true;
                            modelData.pair();
                        }
                    }
                    NIconButton {
                        visible: parent.modelData.paired || parent.modelData.bonded
                        icon: "trash"
                        variant: "ghost"
                        size: Style.controlHeightSm * 0.85
                        onClicked: parent.modelData.forget()
                    }
                }
                NText {
                    anchors.centerIn: parent
                    width: parent.width - Style.spaceLg * 2
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: list.count === 0
                    text: I18n.tr("control-center.bluetooth.no-devices", "No devices found. Start scanning to discover nearby Bluetooth devices.")
                    muted: true
                }
            }
        }

        NText {
            visible: !BluetoothService.enabled
            text: I18n.tr("control-center.bluetooth.off", "Bluetooth is off")
            muted: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
