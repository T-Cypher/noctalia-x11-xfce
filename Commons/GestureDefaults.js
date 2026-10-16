// noctalia v5.3.0 bar gesture defaults (src/shell/bar/widget_gesture_defaults.cpp).
// Resolution order for a widget gesture:
//   builtin < type defaults < [bar.<name>.actions] < [widget.<name>.actions]
// An unbound gesture (or "none") falls through to the bar dead zone.
.pragma library

var gestures = ["left", "right", "middle", "back", "forward", "scroll_up", "scroll_down", "scroll_left", "scroll_right"];

var builtin = {
    middle: "settings-open-widget"
};

var deadZone = {
    right: "panel-toggle control-center home"
};

var types = {
    battery: { left: "panel-toggle control-center power" },
    bluetooth: { left: "panel-toggle control-center bluetooth", right: "bluetooth-toggle" },
    brightness: { left: "panel-toggle control-center monitor", scroll_up: "brightness-up", scroll_down: "brightness-down" },
    caffeine: { left: "caffeine-toggle" },
    clipboard: { left: "panel-toggle clipboard" },
    clock: { left: "panel-toggle control-center calendar" },
    "control-center": { left: "panel-toggle control-center home" },
    keyboard_layout: { left: "keyboard-layout-cycle" },
    launcher: { left: "panel-toggle launcher" },
    media: { left: "panel-toggle control-center media", right: "media toggle", back: "media previous", forward: "media next", scroll_up: "media next", scroll_down: "media previous" },
    network: { left: "panel-toggle control-center network", right: "network-toggle" },
    nightlight: { left: "nightlight-toggle", right: "nightlight-force-toggle" },
    notifications: { left: "panel-toggle control-center notifications", right: "notification-dnd-toggle" },
    power_profile: { left: "power-cycle next", right: "power-cycle prev", scroll_up: "power-cycle next", scroll_down: "power-cycle prev" },
    screenshot: { left: "screenshot-region", right: "screenshot-fullscreen" },
    session: { left: "panel-toggle session" },
    settings: { left: "settings-open" },
    sysmon: { left: "panel-toggle control-center system" },
    taskbar: { scroll_up: "taskbar-cycle prev", scroll_down: "taskbar-cycle next" },
    theme_mode: { left: "theme-mode-toggle" },
    wallpaper: { left: "panel-toggle wallpaper" },
    weather: { left: "panel-toggle control-center weather" },
    workspaces: { scroll_up: "workspace-switch prev", scroll_down: "workspace-switch next" }
};

var volumeOutput = { left: "panel-toggle control-center audio", right: "volume-mute", scroll_up: "volume-up", scroll_down: "volume-down" };
var volumeInput = { left: "panel-toggle control-center audio", right: "mic-mute", scroll_up: "mic-volume-up", scroll_down: "mic-volume-down" };

// Gestures a widget handles itself on its sub-items (never dispatched as widget actions).
// noctalia also reserves the screenshot widget's right click for its capture menu; this port has
// no capture menu, so that gesture takes a fullscreen screenshot instead (see types.screenshot).
var reserved = {
    workspaces: ["left"],
    taskbar: ["left", "middle"],
    tray: ["left", "right"]
};

function forType(type, settings) {
    if (type === "volume")
        return settings && String(settings.device) === "input" ? volumeInput : volumeOutput;
    return types[type] || {};
}

function isReserved(type, gesture) {
    var r = reserved[type];
    return r !== undefined && r.indexOf(gesture) >= 0;
}
