pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons

// Battery (UPower) and power profiles (power-profiles-daemon through Quickshell).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.isLaptopBattery && device.isPresent
    readonly property real percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device !== null && device.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: device !== null && device.state === UPowerDeviceState.FullyCharged
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0
    readonly property real changeRate: device ? device.changeRate : 0
    readonly property real health: device && device.healthSupported ? device.healthPercentage : -1
    readonly property var otherDevices: UPower.devices.values.filter(d => d && !d.isLaptopBattery && d.isPresent && d.percentage > 0 && d.type !== UPowerDeviceType.LinePower)

    // power-profiles-daemon presence (avoid noisy errors when missing)
    property bool profilesAvailable: false
    readonly property int profile: profilesAvailable ? PowerProfiles.profile : -1
    readonly property string profileName: {
        switch (profile) {
        case PowerProfile.PowerSaver: return "power-saver";
        case PowerProfile.Balanced: return "balanced";
        case PowerProfile.Performance: return "performance";
        }
        return "";
    }
    readonly property bool hasPerformance: profilesAvailable && PowerProfiles.hasPerformanceProfile

    signal profileSwitched(string name)
    signal batteryStateChanged(string state)
    signal batteryLow(int percent)

    function profileLabel(name) {
        switch (name) {
        case "power-saver": return I18n.tr("power.profiles.power-saver", "Power Saver");
        case "balanced": return I18n.tr("power.profiles.balanced", "Balanced");
        case "performance": return I18n.tr("power.profiles.performance", "Performance");
        }
        return name;
    }

    function profileGlyph(name) {
        switch (name) {
        case "power-saver": return "powersaver";
        case "performance": return "performance";
        }
        return "balanced";
    }

    function setProfile(name) {
        if (!profilesAvailable)
            return;
        var p = name === "power-saver" ? PowerProfile.PowerSaver : name === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
        if (p === PowerProfile.Performance && !hasPerformance)
            return;
        PowerProfiles.profile = p;
        profileSwitched(name);
    }

    function cycleProfile() {
        var order = hasPerformance ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"];
        var i = order.indexOf(profileName);
        setProfile(order[(i + 1) % order.length]);
    }

    function batteryGlyph() {
        if (!hasBattery)
            return "battery-plugged";
        if (charging)
            return "battery-charging";
        if (pluggedIn && fullyCharged)
            return "battery-plugged";
        if (percent >= 85)
            return "battery-4";
        if (percent >= 60)
            return "battery-3";
        if (percent >= 35)
            return "battery-2";
        if (percent >= 10)
            return "battery-1";
        return "battery-0";
    }

    function stateText() {
        if (!hasBattery)
            return "";
        if (charging)
            return I18n.tr("power.battery.states.charging", "Charging");
        if (fullyCharged)
            return I18n.tr("power.battery.full", "Fully charged");
        if (pluggedIn)
            return I18n.tr("power.battery.states.plugged-in", "Plugged in");
        return I18n.tr("power.battery.states.discharging", "Discharging");
    }

    property string lastState: ""
    property bool warnedLow: false
    onChargingChanged: emitState()
    onPluggedInChanged: emitState()
    onPercentChanged: {
        if (hasBattery && !charging && percent <= 15 && !warnedLow) {
            warnedLow = true;
            batteryLow(percent);
        } else if (percent > 20) {
            warnedLow = false;
        }
    }
    function emitState() {
        var s = charging ? "charging" : (pluggedIn ? "plugged" : "discharging");
        if (s !== lastState && lastState !== "")
            batteryStateChanged(s);
        lastState = s;
    }

    Process {
        running: true
        command: ["sh", "-c", "busctl --system status net.hadess.PowerProfiles >/dev/null 2>&1 || busctl --system status org.freedesktop.UPower.PowerProfiles >/dev/null 2>&1"]
        onExited: (code, status) => root.profilesAvailable = code === 0
    }
}
