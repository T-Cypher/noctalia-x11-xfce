import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// Shows the OSD whenever a service changes (also for changes made outside the shell, e.g.
// XFCE media keys through xfce4-pulseaudio-plugin / xfce4-power-manager).
Scope {
    id: root

    property bool armed: false

    Timer {
        interval: 2500
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            if (root.armed && Audio.ready)
                Osd.show("volume", Audio.volumeGlyph(Audio.volume, Audio.muted), "", Audio.volume, Audio.maxVolume, Audio.muted);
        }
        function onMutedChanged() {
            if (root.armed && Audio.ready)
                Osd.show("volume", Audio.volumeGlyph(Audio.volume, Audio.muted), "", Audio.volume, Audio.maxVolume, Audio.muted);
        }
        function onMicVolumeChanged() {
            if (root.armed && Audio.micReady)
                Osd.show("volume_input", Audio.micMuted ? "microphone-mute" : "microphone", "", Audio.micVolume, 1, Audio.micMuted);
        }
        function onMicMutedChanged() {
            if (root.armed && Audio.micReady)
                Osd.show("volume_input", Audio.micMuted ? "microphone-mute" : "microphone", "", Audio.micVolume, 1, Audio.micMuted);
        }
    }

    Connections {
        target: Brightness
        function onAdjusted() {
            if (root.armed)
                Osd.show("brightness", Brightness.brightness < 0.5 ? "brightness-low" : "brightness-high", "", Brightness.brightness, 1);
        }
    }

    Connections {
        target: Idle
        function onCaffeineToggled(on) {
            Osd.show("caffeine", on ? "caffeine-on" : "caffeine-off", I18n.tr("control-center.shortcuts.caffeine", "Caffeine") + " " + (on ? I18n.tr("common.states.on", "on") : I18n.tr("common.states.off", "off")));
        }
    }

    Connections {
        target: NightLight
        function onToggled(on) {
            Osd.show("nightlight", NightLight.forced ? "nightlight-forced" : (NightLight.enabled ? "nightlight-on" : "nightlight-off"), I18n.tr("control-center.shortcuts.nightlight", "Night Light") + " " + (NightLight.forced ? I18n.tr("osd.forced", "forced") : (NightLight.enabled ? I18n.tr("common.states.on", "on") : I18n.tr("common.states.off", "off"))));
        }
    }

    Connections {
        target: Notifications
        function onDndToggled(on) {
            Osd.show("dnd", on ? "bell-off" : "bell", I18n.tr("settings.schema.shell.osd-kinds-dnd.label", "Do Not Disturb") + " " + (on ? I18n.tr("common.states.on", "on") : I18n.tr("common.states.off", "off")));
        }
    }

    Connections {
        target: Network
        function onWifiToggled(on) {
            if (root.armed) {
                Osd.show("wifi", on ? "wifi" : "wifi-off", "Wi-Fi " + (on ? I18n.tr("common.states.on", "on") : I18n.tr("common.states.off", "off")));
                Hooks.run(on ? "wifi_enabled" : "wifi_disabled", {});
            }
        }
    }

    Connections {
        target: BluetoothService
        function onToggled(on) {
            Osd.show("bluetooth", on ? "bluetooth" : "bluetooth-off", "Bluetooth " + (on ? I18n.tr("common.states.on", "on") : I18n.tr("common.states.off", "off")));
            Hooks.run(on ? "bluetooth_enabled" : "bluetooth_disabled", {});
        }
    }

    Connections {
        target: Power
        function onProfileSwitched(name) {
            Osd.show("power_profile", Power.profileGlyph(name), Power.profileLabel(name));
            Hooks.run("power_profile_changed", {
                NOCTALIA_POWER_PROFILE: name
            });
        }
        function onBatteryStateChanged(state) {
            Hooks.run("battery_state_changed", {
                NOCTALIA_BATTERY_STATE: state,
                NOCTALIA_BATTERY_PERCENT: Power.percent
            });
        }
        function onBatteryLow(percent) {
            Notifications.notifyInternal(I18n.tr("notifications.internal.battery-low-title", "Battery low"), percent + "%", "battery-1", "critical");
            Hooks.run("battery_under_threshold", {
                NOCTALIA_BATTERY_PERCENT: percent
            });
        }
    }

    Connections {
        target: X11
        function onKeyboardUpdated(layoutChanged, locksChanged) {
            if (layoutChanged)
                Osd.show("keyboard_layout", "keyboard", X11.layoutName);
            else if (locksChanged) {
                var parts = [];
                parts.push("Caps " + (X11.keyboard.caps ? "on" : "off"));
                parts.push("Num " + (X11.keyboard.num ? "on" : "off"));
                Osd.show("lock_keys", "capslock", parts.join("  ·  "));
            }
        }
    }
}
