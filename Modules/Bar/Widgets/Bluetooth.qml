import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property var connected: BluetoothService.connectedDevices
    readonly property string label: connected.length === 1 ? BluetoothService.deviceName(connected[0]) : (connected.length > 1 ? connected.length + "" : "")

    hideWidget: !BluetoothService.available || (settings.hide_when_adapter_off === true && !BluetoothService.enabled) || (settings.hide_when_no_connected_device === true && connected.length === 0)
    tooltipText: !BluetoothService.enabled ? I18n.tr("control-center.bluetooth.off", "Bluetooth is off") : (connected.length > 0 ? connected.map(d => BluetoothService.deviceName(d)).join("\n") : I18n.tr("control-center.shortcuts.bluetooth", "Bluetooth"))

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            icon: BluetoothService.glyph()
            size: root.glyphSize
            color: root.iconColor(BluetoothService.enabled ? Theme.fgSurface : Theme.fgSurfaceVariant)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.settings.show_label === true && !root.vertical && root.label !== ""
            width: Math.min(implicitWidth, 120 * root.contentScale)
            text: root.label
            size: root.fontSize
            weight: root.fontWeight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
