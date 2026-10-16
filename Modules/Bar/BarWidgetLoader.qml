import QtQuick
import qs.Commons

// Resolves a widget name from a bar section to its [widget.<name>] settings and type, and
// loads the matching implementation from Widgets/.
Loader {
    id: loader

    required property string widgetName
    required property var bar

    readonly property var settings: {
        Config.generation;
        return Config.widgetSettings(widgetName);
    }
    readonly property string file: {
        switch (String(settings.type)) {
        case "launcher":
        case "control-center":
        case "control_center":
        case "session":
        case "wallpaper":
        case "clipboard":
        case "screenshot":
        case "settings":
        case "custom_button":
            return "GlyphButton";
        case "notifications":
        case "notification":
            return "NotificationsButton";
        case "tray": return "Tray";
        case "clock": return "Clock";
        case "media": return "Media";
        case "network": return "Network";
        case "bluetooth": return "Bluetooth";
        case "volume": return "Volume";
        case "brightness": return "Brightness";
        case "battery": return "Battery";
        case "workspaces": return "Workspaces";
        case "taskbar": return "Taskbar";
        case "active_window": return "ActiveWindow";
        case "keyboard_layout": return "KeyboardLayout";
        case "lock_keys": return "LockKeys";
        case "sysmon": return "Sysmon";
        case "caffeine":
        case "nightlight":
        case "power_profile":
        case "theme_mode":
            return "ToggleButton";
        case "spacer": return "Spacer";
        case "text": return "TextWidget";
        case "weather": return "WeatherWidget";
        }
        return "";
    }

    active: file !== "" && settings.enabled !== false
    visible: active && item !== null && !item.hideWidget
    source: file !== "" ? Qt.resolvedUrl("Widgets/" + file + ".qml") : ""

    onLoaded: {
        item.bar = Qt.binding(() => loader.bar);
        item.settings = Qt.binding(() => loader.settings);
        item.widgetName = loader.widgetName;
    }

    Component.onCompleted: {
        if (file === "")
            console.warn("[noctalia-x11] unknown bar widget '" + widgetName + "' (type '" + settings.type + "')");
    }
}
