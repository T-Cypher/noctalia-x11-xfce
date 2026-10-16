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

    property double lastShellChange: 0   // when the shell itself last changed the profile
    signal batteryHookState(string state)              // charging | discharging | plugged
    signal batteryPercentChanged(string state, int percent)
    signal batteryWarning(int level, int percent)      // noctalia's escalating low-battery levels

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
        lastShellChange = Date.now();
        PowerProfiles.profile = p;
    }

    // power-cycle: step through the ordered profile list (wraps), forward by default.
    function cycleProfile(direction) {
        var order = hasPerformance ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"];
        var i = order.indexOf(profileName);
        var d = direction === -1 ? -1 : 1;
        setProfile(order[((i < 0 ? 0 : i) + d + order.length) % order.length]);
    }

    // noctalia's batteryGlyphName
    function batteryGlyph() {
        if (!hasBattery)
            return "battery-plugged";
        if (charging)
            return "battery-charging";
        if (fullyCharged || (device && device.state === UPowerDeviceState.PendingCharge))
            return "battery-plugged";
        if (device && device.state === UPowerDeviceState.Unknown && percent <= 0)
            return "battery-exclamation";
        if (percent >= 85)
            return "battery-4";
        if (percent >= 55)
            return "battery-3";
        if (percent >= 30)
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

    // UPower state names used by NOCTALIA_BATTERY_STATE
    function upowerStateName() {
        if (!device)
            return "unknown";
        switch (device.state) {
        case UPowerDeviceState.Charging: return "charging";
        case UPowerDeviceState.Discharging: return "discharging";
        case UPowerDeviceState.Empty: return "empty";
        case UPowerDeviceState.FullyCharged: return "fully_charged";
        case UPowerDeviceState.PendingCharge: return "pending_charge";
        case UPowerDeviceState.PendingDischarge: return "pending_discharge";
        }
        return "unknown";
    }

    // battery_charging / battery_discharging / battery_plugged hooks: fire on entering a tracked
    // state; intermediate UPower states do not retrigger them.
    property string hookState: ""
    readonly property string currentHookState: {
        if (!hasBattery)
            return "";
        var st = upowerStateName();
        if (st === "charging")
            return "charging";
        if (st === "discharging")
            return "discharging";
        if (st === "fully_charged" || st === "pending_charge")
            return "plugged";
        return "";
    }
    onCurrentHookStateChanged: {
        if (currentHookState === "" || currentHookState === hookState)
            return;
        var first = hookState === "";
        hookState = currentHookState;
        if (!first)
            batteryHookState(currentHookState);
    }
    property int lastHookPercent: -1
    onPercentChanged: {
        if (hasBattery && lastHookPercent >= 0 && percent !== lastHookPercent)
            batteryPercentChanged(upowerStateName(), percent);
        lastHookPercent = hasBattery ? percent : -1;
        evaluateWarning();
    }
    onChargingChanged: evaluateWarning()
    onPluggedInChanged: evaluateWarning()

    // noctalia's BatteryWarningMonitor for the system battery: levels [threshold, 5, 2]; fires
    // once per level while draining, re-arms on charge / plug-in / partial recharge.
    property int firedLevel: 1000
    function evaluateWarning() {
        var threshold = Number(Config.get("battery.warning_threshold", 10));
        var plugged = charging || fullyCharged || (device && device.state === UPowerDeviceState.PendingCharge);
        if (!hasBattery || plugged || !(threshold > 0)) {
            firedLevel = 1000;
            return;
        }
        var points = [threshold];
        if (5 < threshold)
            points.push(5);
        if (2 < threshold)
            points.push(2);
        var level = 1000;
        for (var i = 0; i < points.length; i++)
            if (points[i] >= percent)
                level = points[i];
        if (level === 1000) {
            firedLevel = 1000;
            return;
        }
        if (level < firedLevel) {
            firedLevel = level;
            batteryWarning(level, percent);
        } else if (level > firedLevel) {
            firedLevel = level;
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "busctl --system status net.hadess.PowerProfiles >/dev/null 2>&1 || busctl --system status org.freedesktop.UPower.PowerProfiles >/dev/null 2>&1"]
        onExited: (code, status) => root.profilesAvailable = code === 0
    }
}
