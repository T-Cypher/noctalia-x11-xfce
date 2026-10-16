import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// Shows noctalia's OSD contents whenever a service changes - including changes made outside
// the shell (XFCE media keys through xfce4-pulseaudio-plugin / xfce4-power-manager, nmcli,
// bluetoothctl, powerprofilesctl, ...) - and runs the matching [hooks].
Scope {
    id: root

    // Ignore the initial snapshots taken while services start up.
    property bool armed: false
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            root.lastSinkName = Audio.nodeName(Audio.sink);
            root.lastSourceName = Audio.nodeName(Audio.source);
            root.lastBtEnabled = BluetoothService.enabled;
            root.lastProfile = Power.profileName;
            root.armed = true;
        }
    }

    // ------------------------------------------------------------------ audio
    property string lastSinkName: ""
    property string lastSourceName: ""
    property double lastOutputOsd: 0

    function showOutput() {
        if (!root.armed || !Audio.ready)
            return;
        root.lastOutputOsd = Date.now();
        Osd.showLevel("volume_output", Audio.volumeGlyph(Audio.volume, Audio.muted), Audio.volume, Audio.muted);
    }
    function showInput() {
        // noctalia suppresses input OSDs right after an output change (shared hardware keys).
        if (!root.armed || !Audio.micReady || Date.now() - root.lastOutputOsd < 500)
            return;
        Osd.showLevel("volume_input", Audio.micGlyph(Audio.micVolume, Audio.micMuted), Audio.micVolume, Audio.micMuted);
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            root.showOutput();
        }
        function onMutedChanged() {
            root.showOutput();
        }
        function onMicVolumeChanged() {
            root.showInput();
        }
        function onMicMutedChanged() {
            root.showInput();
        }
        // Default device changes show the device name.
        function onSinkChanged() {
            var name = Audio.nodeName(Audio.sink);
            if (root.armed && name !== "" && name !== root.lastSinkName)
                Osd.show("volume_output", Audio.volumeGlyph(1, Audio.muted), name, -1, false, Audio.muted);
            root.lastSinkName = name;
        }
        function onSourceChanged() {
            var name = Audio.nodeName(Audio.source);
            if (root.armed && name !== "" && name !== root.lastSourceName)
                Osd.show("volume_input", Audio.micGlyph(1, Audio.micMuted), name, -1, false, Audio.micMuted);
            root.lastSourceName = name;
        }
    }

    // ------------------------------------------------------------------ brightness
    Connections {
        target: Brightness
        function onAdjusted(level) {
            if (root.armed)
                Osd.showLevel("brightness", level < 0.4 ? "brightness-low" : "brightness-high", level, false);
        }
    }

    // ------------------------------------------------------------------ toggles
    function onOff(key, on) {
        return I18n.tr(key + (on ? ".on" : ".off"), on ? "On" : "Off");
    }

    Connections {
        target: Idle
        function onCaffeineToggled(on) {
            Osd.show("caffeine", on ? "caffeine-on" : "caffeine-off", root.onOff("osd.caffeine", on), -1, false, !on);
        }
    }

    Connections {
        target: NightLight
        function onToggled(on) {
            var icon, text;
            if (NightLight.forced) {
                icon = "nightlight-forced";
                text = I18n.tr("osd.nightlight.forced", "Always On");
            } else if (!NightLight.enabled) {
                icon = "nightlight-off";
                text = I18n.tr("osd.nightlight.off", "Night Light Off");
            } else {
                icon = "nightlight-on";
                text = NightLight.active ? I18n.tr("osd.nightlight.running", "Running") : I18n.tr("osd.nightlight.scheduled", "Scheduled");
            }
            Osd.show("nightlight", icon, text, -1, false, !NightLight.enabled && !NightLight.forced);
        }
    }

    Connections {
        target: Notifications
        function onDndToggled(on) {
            Osd.show("dnd", on ? "bell-off" : "bell", root.onOff("osd.dnd", on), -1, false, !on);
        }
    }

    Connections {
        target: Network
        function onWifiToggled(on) {
            if (!root.armed)
                return;
            Osd.show("wifi", on ? "wifi" : "wifi-off", root.onOff("osd.wifi", on), -1, false, !on);
            Hooks.run(on ? "wifi_enabled" : "wifi_disabled", {});
        }
    }

    // Bluetooth: watch the adapter state itself so external changes are reported too.
    property bool lastBtEnabled: false
    Connections {
        target: BluetoothService
        function onEnabledChanged() {
            var on = BluetoothService.enabled;
            if (!root.armed || !BluetoothService.available || on === root.lastBtEnabled) {
                root.lastBtEnabled = on;
                return;
            }
            root.lastBtEnabled = on;
            Osd.show("bluetooth", on ? "bluetooth" : "bluetooth-off", root.onOff("osd.bluetooth", on), -1, false, !on);
            Hooks.run(on ? "bluetooth_enabled" : "bluetooth_disabled", {});
        }
    }

    // Power profiles: any change (shell, IPC or powerprofilesctl) shows the OSD and runs the hook.
    property string lastProfile: ""
    Connections {
        target: Power
        function onProfileNameChanged() {
            var name = Power.profileName;
            var previous = root.lastProfile;
            root.lastProfile = name;
            if (!root.armed || name === "" || name === previous)
                return;
            Osd.show("power_profile", Power.profileGlyph(name), Power.profileLabel(name));
            Hooks.run("power_profile_changed", {
                NOCTALIA_POWER_PROFILE: name,
                NOCTALIA_POWER_PROFILE_PREVIOUS: previous,
                NOCTALIA_POWER_PROFILE_ORIGIN: Date.now() - Power.lastShellChange < 3000 ? "noctalia" : "external"
            });
        }
        function onBatteryHookState(state) {
            Hooks.run("battery_" + state, {});
        }
        function onBatteryPercentChanged(state, percent) {
            Hooks.run("battery_percentage_changed", {
                NOCTALIA_BATTERY_STATE: state,
                NOCTALIA_BATTERY_PERCENT: percent
            });
        }
        function onBatteryWarning(level, percent) {
            var label = I18n.tr("notifications.internal.battery", "Battery");
            if (level <= 2)
                Notifications.notifyInternal(I18n.tr("notifications.internal.battery-critical-title", "Battery critically low"), I18n.tr("notifications.internal.battery-critical-body", "{device}: {percent}%; your computer will shut down soon", {
                    device: label,
                    percent: percent
                }), "battery-exclamation", "critical", 0, false, true);
            else
                Notifications.notifyInternal(I18n.tr("notifications.internal.battery-low-title", "Battery low"), I18n.tr("notifications.internal.battery-low-body", "{device}: {percent}% remaining", {
                    device: label,
                    percent: percent
                }), "battery-exclamation", level > 5 ? "normal" : "critical", level > 5 ? 6000 : 12000, false, true);
        }
    }

    // ------------------------------------------------------------------ media track changes
    property string lastTrack: ""
    property string pendingTrack: ""
    Connections {
        target: Media
        function onTitleChanged() {
            root.trackChanged();
        }
        function onArtistChanged() {
            root.trackChanged();
        }
        function onPlayerChanged() {
            // a different active player is not a track change
            root.lastTrack = Media.title !== "" ? Media.title + "\u0001" + Media.artist + "\u0001" + (Media.player ? Media.player.dbusName : "") : "";
            trackSettle.stop();
        }
    }
    function trackChanged() {
        if (!Media.player || Media.title === "")
            return;
        var sig = Media.title + "\u0001" + Media.artist + "\u0001" + Media.player.dbusName;
        if (root.lastTrack === "" || !root.armed) {
            root.lastTrack = sig;
            return;
        }
        if (sig === root.lastTrack) {
            trackSettle.stop();
            return;
        }
        root.pendingTrack = sig;
        trackSettle.restart();
    }
    Timer {
        id: trackSettle
        interval: 600
        onTriggered: {
            if (!Media.player || !Media.isPlaying)
                return;
            root.lastTrack = root.pendingTrack;
            Osd.show("media", "disc", Media.artist !== "" ? Media.title + " - " + Media.artist : Media.title);
        }
    }

    // ------------------------------------------------------------------ keyboard
    Connections {
        target: X11
        function onKeyboardUpdated(layoutChanged, locksChanged, previous) {
            if (layoutChanged) {
                Osd.show("keyboard_layout", "keyboard", X11.layoutLabel("short"));
                return;
            }
            if (!locksChanged || !previous)
                return;
            var k = X11.keyboard;
            if (previous.caps !== k.caps)
                Osd.show("lock_keys", "capslock", I18n.tr(k.caps ? "osd.lock-keys.caps-on" : "osd.lock-keys.caps-off", k.caps ? "Caps Lock On" : "Caps Lock Off"), -1, false, !k.caps);
            else if (previous.num !== k.num)
                Osd.show("lock_keys", "numlock", I18n.tr(k.num ? "osd.lock-keys.num-on" : "osd.lock-keys.num-off", k.num ? "Num Lock On" : "Num Lock Off"), -1, false, !k.num);
            else if (previous.scroll !== k.scroll)
                Osd.show("lock_keys", "scrolllock", I18n.tr(k.scroll ? "osd.lock-keys.scroll-on" : "osd.lock-keys.scroll-off", k.scroll ? "Scroll Lock On" : "Scroll Lock Off"), -1, false, !k.scroll);
        }
    }
}
