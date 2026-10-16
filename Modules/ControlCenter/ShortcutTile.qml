import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

// Home shortcut button ([[control_center.shortcuts]] type = wifi | bluetooth | caffeine |
// nightlight | notification | power_profile | wallpaper | session | theme_mode | screenshot |
// clipboard | launcher | custom).
NButton {
    id: root

    property var shortcut: ({})
    readonly property string type: String(shortcut.type || "")
    readonly property bool showLabel: Config.get("control_center.show_shortcut_labels", true) !== false
    signal requestTab(string id)

    readonly property var info: {
        switch (type) {
        case "wifi":
            return {
                glyph: Network.wifiEnabled ? Network.glyph() : "wifi-off",
                label: I18n.tr("control-center.shortcuts.wifi", "Wi-Fi"),
                active: Network.wifiEnabled,
                left: function () {
                    Network.toggleWifi();
                },
                right: function () {
                    root.requestTab("network");
                }
            };
        case "bluetooth":
            return {
                glyph: BluetoothService.enabled ? "bluetooth" : "bluetooth-off",
                label: I18n.tr("control-center.shortcuts.bluetooth", "Bluetooth"),
                active: BluetoothService.enabled,
                left: function () {
                    BluetoothService.toggle();
                },
                right: function () {
                    root.requestTab("bluetooth");
                }
            };
        case "caffeine":
            return {
                glyph: Idle.caffeine ? "caffeine-on" : "caffeine-off",
                label: I18n.tr("control-center.shortcuts.caffeine", "Caffeine"),
                active: Idle.caffeine,
                left: function () {
                    Idle.toggleCaffeine();
                }
            };
        case "nightlight":
            return {
                glyph: NightLight.forced ? "nightlight-forced" : (NightLight.enabled ? "nightlight-on" : "nightlight-off"),
                label: I18n.tr("control-center.shortcuts.nightlight", "Night Light"),
                active: NightLight.enabled || NightLight.forced,
                left: function () {
                    NightLight.toggle();
                },
                right: function () {
                    NightLight.toggleForce();
                }
            };
        case "notification":
        case "dnd":
            return {
                glyph: Notifications.dnd ? "bell-off" : "bell",
                label: I18n.tr("control-center.shortcuts.notification", "DND"),
                active: Notifications.dnd,
                left: function () {
                    Notifications.toggleDnd();
                },
                right: function () {
                    root.requestTab("notifications");
                }
            };
        case "power_profile":
            return {
                glyph: Power.profilesAvailable ? Power.profileGlyph(Power.profileName) : "balanced",
                label: Power.profilesAvailable ? Power.profileLabel(Power.profileName) : I18n.tr("control-center.tabs.power", "Power"),
                active: Power.profileName === "performance",
                left: function () {
                    Power.cycleProfile();
                },
                right: function () {
                    root.requestTab("power");
                }
            };
        case "wallpaper":
            return {
                glyph: "wallpaper-selector",
                label: I18n.tr("control-center.shortcuts.wallpaper", "Wallpaper"),
                active: false,
                left: function () {
                    Panels.open("wallpaper", Panels.activeScreen, "", Panels.anchor, Panels.sourceBar, null);
                }
            };
        case "session":
            return {
                glyph: "power",
                label: I18n.tr("control-center.shortcuts.session", "Session"),
                active: false,
                left: function () {
                    Panels.open("session", Panels.activeScreen, "", Panels.anchor, Panels.sourceBar, null);
                }
            };
        case "theme_mode":
            return {
                glyph: "theme-mode",
                label: Theme.isDark ? I18n.tr("settings.options.theme.mode.dark", "Dark") : I18n.tr("settings.options.theme.mode.light", "Light"),
                active: !Theme.isDark,
                left: function () {
                    ThemeControl.setMode(Theme.isDark ? "light" : "dark");
                }
            };
        case "screenshot":
            return {
                glyph: "screenshot",
                label: I18n.tr("settings.widgets.types.screenshot", "Screenshot"),
                active: false,
                left: function () {
                    Panels.close();
                    Commands.run("exec sleep 0.4; true", null);
                    Commands.screenshot("region");
                }
            };
        case "clipboard":
            return {
                glyph: "clipboard",
                label: I18n.tr("clipboard.title", "Clipboard"),
                active: false,
                left: function () {
                    Panels.open("clipboard", Panels.activeScreen, "", null, null, null);
                }
            };
        default:
            return {
                glyph: shortcut.glyph || "terminal",
                label: shortcut.label || type,
                active: false,
                left: function () {
                    if (shortcut.command)
                        Commands.run(String(shortcut.command), null);
                }
            };
        }
    }

    vertical: true
    icon: info.glyph
    text: showLabel ? info.label : ""
    iconSize: showLabel ? Style.baseGlyphSize * 1.1 : Math.min(width, height) * 0.36
    fontSize: Style.fontSizeCaption
    selected: info.active
    radius: Style.radiusXl
    onClicked: info.left()
    onRightClicked: if (info.right)
        info.right()
}
