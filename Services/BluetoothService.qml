pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Commons

// BlueZ through Quickshell.Bluetooth.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property bool discovering: adapter !== null && adapter.discovering
    readonly property var devices: adapter ? adapter.devices.values.filter(d => d !== null) : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var pairedDevices: devices.filter(d => d.paired || d.bonded)
    readonly property var otherDevices: devices.filter(d => !(d.paired || d.bonded) && (d.name || d.deviceName))

    signal toggled(bool enabled)

    function setEnabled(on) {
        if (!adapter)
            return;
        adapter.enabled = on;
        toggled(on);
    }

    function toggle() {
        setEnabled(!enabled);
    }

    function setDiscovering(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }

    function deviceName(d) {
        return d ? (d.name || d.deviceName || d.address || "") : "";
    }

    function deviceGlyph(d) {
        var icon = d ? String(d.icon || "") : "";
        if (icon.indexOf("headset") >= 0)
            return "bluetooth-device-headset";
        if (icon.indexOf("headphone") >= 0 || icon.indexOf("audio-card") >= 0)
            return "bluetooth-device-headphones";
        if (icon.indexOf("mouse") >= 0)
            return "bluetooth-device-mouse";
        if (icon.indexOf("keyboard") >= 0)
            return "bluetooth-device-keyboard";
        if (icon.indexOf("phone") >= 0)
            return "bluetooth-device-phone";
        if (icon.indexOf("gaming") >= 0 || icon.indexOf("joystick") >= 0)
            return "bluetooth-device-gamepad";
        if (icon.indexOf("watch") >= 0)
            return "bluetooth-device-watch";
        if (icon.indexOf("speaker") >= 0)
            return "bluetooth-device-speaker";
        if (icon.indexOf("video-display") >= 0 || icon.indexOf("tv") >= 0)
            return "bluetooth-device-tv";
        return "bluetooth-device-generic";
    }

    function glyph() {
        if (!available || !enabled)
            return "bluetooth-off";
        return connectedDevices.length > 0 ? "bluetooth-connected" : "bluetooth";
    }
}
