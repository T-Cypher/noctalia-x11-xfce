// Built-in defaults for Noctalia-X11.
// Values mirror noctalia v5.3.0's C++ config structs (src/config/config_types.h /
// config_types.cpp / widget_config.cpp), which are authoritative over the partly stale
// example.toml. Only keys this port understands are listed. X11/XFCE specific settings
// live in the port-only [x11] table.
.pragma library

var defaults = {
    accessibility: {
        ui_scale: 1.0,
        high_contrast: false
    },
    shell: {
        corner_radius_scale: 1.0,
        font_family: "sans-serif",
        time_format: "{:%H:%M}",
        date_format: "%A, %x",
        offline_mode: false,
        show_location: true,
        app_icon_colorize: false,
        app_icon_color: "",
        clipboard_enabled: true,
        clipboard_history_max_entries: 100,
        clipboard_auto_paste: "auto",
        lang: "",
        avatar_path: "",
        panel_anchor_bar: "",
        animation: {
            enabled: true,
            speed: 1.0
        },
        shadow: {
            direction: "down",
            alpha: 0.55
        },
        panel: {
            transparency_mode: "solid",
            borders: true,
            border_color: "outline",
            border_width: 1.0,
            shadow: true,
            list_item_background: false,
            wallpaper_show_names: true,
            floating_layer: "overlay",
            floating_offset: 8,
            launcher_placement: "floating",
            clipboard_placement: "floating",
            control_center_placement: "attached",
            wallpaper_placement: "attached",
            session_placement: "attached",
            launcher_position: "center",
            clipboard_position: "center",
            control_center_position: "auto",
            wallpaper_position: "auto",
            session_position: "auto",
            open_near_click_control_center: false,
            open_near_click_launcher: false,
            open_near_click_clipboard: false,
            open_near_click_wallpaper: false,
            open_near_click_session: false
        },
        launcher: {
            layout: "full",
            width: 760,
            search_position: "bottom",
            default_view: "recent",
            categories: true,
            category_icons_only: false,
            show_settings_button: true,
            show_session_button: true,
            show_icons: true,
            show_app_origin_indicator: true,
            compact: false,
            app_grid: false,
            show_app_actions: false,
            track_usage: true,
            sort_by_usage: true,
            pinned: [],
            fetch_exchange_rates: true,
            provider_prefix: "/",
            auto_paste: "auto",
            providers: {
                calculator: { prefix: "calc", global: true },
                emoji: { prefix: "emo" },
                session: { prefix: "session", global: false },
                wallpaper: { prefix: "wall" },
                windows: { prefix: "win" }
            }
        },
        keyboard_layout: {
            custom_labels: {}
        },
        mpris: {
            blacklist: []
        },
        session: {
            // Seeded only when the key is absent (an explicit `actions = []` shows no buttons).
            actions: [
                { action: "lock", shortcut: "1" },
                { action: "logout", shortcut: "2" },
                { action: "lock_and_suspend", shortcut: "3" },
                { action: "reboot", shortcut: "4" },
                { action: "shutdown", variant: "destructive", shortcut: "5" }
            ],
            grid: false,
            grid_columns: 3,
            show_shortcuts: true,
            power: {}
        }
    },
    wallpaper: {
        enabled: true,
        fill_mode: "crop",
        fill_color: "",
        directory: "",
        directory_light: "",
        directory_dark: "",
        automation: {
            enabled: false,
            interval_seconds: 1800,
            order: "random",
            recursive: false
        }
    },
    theme: {
        mode: "dark",
        shell_mode: "follow",
        source: "builtin",
        builtin: "Noctalia",
        community_palette: "Oxocarbon",
        wallpaper_scheme: "m3-content",
        pure_black_dark: false,
        sync_color_scheme: true
    },
    notification: {
        enable_daemon: true,
        show_app_name: true,
        show_actions: true,
        position: "top_right",
        layer: "top",
        scale: 1.0,
        width: 360,
        background_opacity: 0.97,
        border: true,
        border_color: "outline",
        border_width: 1,
        follow_focused_output: false,
        offset_x: 20,
        offset_y: 8,
        monitors: [],
        collapse_on_dismiss: true,
        keep_dismissed_in_history: true,
        history_retention_hours: 0,
        max_visible: 0
    },
    osd: {
        enabled: true,
        position: "top_center",
        position_vertical: "top_center",
        orientation: "horizontal",
        hide_delay_ms: 1400,
        scale: 1.0,
        background_opacity: 0.97,
        border: true,
        border_color: "outline",
        border_width: 1,
        follow_focused_output: false,
        offset_x: 20,
        offset_y: 8,
        monitors: [],
        kinds: {
            volume: true,
            volume_output: true,
            volume_input: true,
            brightness: true,
            wifi: true,
            bluetooth: true,
            power_profile: true,
            caffeine: true,
            nightlight: true,
            dnd: true,
            lock_keys: true,
            keyboard_layout: true,
            media: true,
            privacy: true,
            keyboard_backlight: true
        }
    },
    lockscreen: {
        enabled: true
    },
    system: {
        monitor: {
            enabled: true,
            cpu_temp_sensor_path: "",
            cpu_poll_seconds: 2.0,
            gpu_poll_seconds: 5.0,
            memory_poll_seconds: 2.0,
            network_poll_seconds: 3.0,
            disk_poll_seconds: 10.0
        }
    },
    calendar: {
        enabled: false
    },
    control_center: {
        sidebar: "compact",
        sidebar_section: "compact",
        width: 700,
        show_shortcut_labels: true,
        show_session_button: true,
        hidden_tabs: [],
        // Seeded only when the key is absent.
        shortcuts: [
            { type: "wifi" },
            { type: "bluetooth" },
            { type: "caffeine" },
            { type: "nightlight" },
            { type: "notification" },
            { type: "power_profile" }
        ],
        calendar: {
            show_events_card: true,
            show_week_numbers: false
        }
    },
    weather: {
        enabled: true,
        effects: true,
        refresh_minutes: 30,
        unit: "metric"
    },
    audio: {
        enable_overdrive: false,
        enable_sounds: true,
        enable_volume_sounds: true,
        enable_notification_sounds: true,
        enable_power_sounds: true,
        enable_screenshot_sounds: true,
        sound_volume: 0.5,
        sound_theme: "freedesktop"
    },
    brightness: {
        enable_ddcutil: false,
        sync_all_monitors: false,
        ignore_mmids: [],
        minimum_brightness: 0.0
    },
    battery: {
        warning_threshold: 10
    },
    nightlight: {
        enabled: false,
        force: false,
        temperature_day: 6500,
        temperature_night: 4000
    },
    location: {
        auto_locate: false,
        address: "",
        custom_schedule: false,
        sunset: "",
        sunrise: ""
    },
    idle: {
        pre_action_fade_seconds: 2.0,
        behavior_order: [],
        // Seeded only when no [idle.behavior.*] table is configured (see Config.finalize).
        behavior: {
            "lock": { enabled: false, timeout: 600, action: "lock", command: "", resume_command: "" },
            "screen-off": { enabled: false, timeout: 660, action: "screen_off", command: "", resume_command: "" },
            "lock-and-suspend": { enabled: false, timeout: 900, action: "lock_and_suspend", command: "", resume_command: "" }
        }
    },
    // Only user-defined [bar.<name>] tables create bars; with none, a single bar named
    // "default" uses barDefaults() (noctalia's BarConfig{}).
    bar: {},
    dock: {
        enabled: false,
        position: "bottom",
        layer: "top",
        icon_size: 48,
        main_axis_padding: 16,
        cross_axis_padding: 8,
        item_spacing: 6,
        background_opacity: 0.88,
        border: "outline",
        border_width: 0,
        radius: 16,
        concave_edge_corners: true,
        margin_edge: 0,
        margin_ends: 0,
        shadow: true,
        show_running: true,
        auto_hide: false,
        smart_auto_hide: false,
        reserve_space: true,
        active_scale: 1.0,
        inactive_scale: 0.85,
        magnification: true,
        magnification_scale: 1.45,
        active_opacity: 1.0,
        inactive_opacity: 0.85,
        show_dots: false,
        show_instance_count: true,
        launcher_position: "none",
        launcher_icon: "grid-dots",
        active_monitor_only: false,
        pinned: []
    },
    keybinds: {},
    hooks: {},
    widget: {},
    x11: {
        // Command used to lock the session. Empty = auto-detect
        // (xflock4, light-locker-command -l, xscreensaver-command -lock, loginctl lock-session).
        lock_command: "",
        // Empty = "xfce4-session-logout --logout --fast" when available, else loginctl terminate-session.
        logout_command: "",
        // auto | xfdesktop | feh | xwallpaper | hsetroot | none
        wallpaper_backend: "auto",
        // Terminal used for Terminal=true desktop entries. Empty = auto (exo-open / x-terminal-emulator).
        terminal: "",
        // Opened by the "settings" bar widget and the settings buttons.
        settings_command: "",
        // Optional GTK / icon themes applied through xfconf (xsettings) when theme mode changes.
        gtk_theme_dark: "",
        gtk_theme_light: "",
        icon_theme_dark: "",
        icon_theme_light: "",
        // Screenshot commands (empty = auto: xfce4-screenshooter, flameshot, maim, scrot).
        screenshot_region_command: "",
        screenshot_full_command: "",
        // Panel keyboard focus strategy: "bridge" (EWMH _NET_ACTIVE_WINDOW from the X11 helper,
        // works with xfwm4 focus-stealing prevention) or "qt" (QWindow.requestActivate()).
        focus_method: "bridge",
        // Use xdotool to paste after picking a clipboard/emoji entry (auto_paste settings).
        paste_tool: "xdotool"
    }
};

// noctalia's BarConfig{} defaults (used for the implicit "default" bar and as the base of every
// [bar.<name>] table, exactly like the C++ struct defaults).
var barDefaultsTable = {
    position: "top",
    enabled: true,
    auto_hide: false,
    auto_hide_delay_ms: 0,
    smart_auto_hide: false,
    show_on_workspace_switch: true,
    reserve_space: true,
    layer: "top",
    thickness: 34,
    background_opacity: 1.0,
    compositor_blur: true,
    border: "outline",
    border_width: 0.0,
    radius: 12,
    concave_edge_corners: true,
    margin_ends: 100,
    margin_edge: 0,
    margin_opposite_edge: 0,
    padding: 14,
    widget_spacing: 6,
    shadow: true,
    contact_shadow: false,
    panel_overlap: 1,
    capsule_thickness: 0.76,
    scale: 1.0,
    font_scale: 1.0,
    font_weight: 500,
    font_family: "",
    start: ["launcher", "wallpaper", "workspaces"],
    center: ["clock"],
    end: ["media", "tray", "notifications", "clipboard", "network", "bluetooth", "volume", "brightness", "battery", "control-center", "session"],
    capsule: false,
    capsule_fill: "surface_variant",
    capsule_padding: 6,
    capsule_opacity: 1.0,
    capsule_border_width: 1.0,
    hover_highlight: true,
    show_tooltip: true
};

// Built-in named widget instances (noctalia's seedBuiltinWidgets). A user [widget.<name>]
// overlays the seeded entry only when it omits `type` or keeps the same type.
var seededWidgets = {
    cpu: { type: "sysmon", stat: "cpu_usage" },
    temp: { type: "sysmon", stat: "cpu_temp" },
    ram: { type: "sysmon", stat: "ram_used" },
    network_tx: { type: "sysmon", stat: "net_tx" },
    network_rx: { type: "sysmon", stat: "net_rx" },
    output_volume: { type: "volume", device: "output" },
    input_volume: { type: "volume", device: "input" },
    date: { type: "clock", format: "{:%a %d %b}" },
    active_window: { type: "active_window", max_length: 260, min_length: 80, icon_size: 14, title_scroll: "none" },
    media: { type: "media", max_length: 220, min_length: 80, art_size: 16, title_scroll: "none" },
    keyboard_layout: { type: "keyboard_layout", hide_when_single_layout: false },
    lock_keys: { type: "lock_keys", show_caps_lock: true, show_num_lock: true, show_scroll_lock: false, hide_when_off: false, display: "short" },
    spacer: { type: "spacer", interactive: false }
};

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Defaults merge: arrays and scalars from `over` replace those in `base`; tables merge.
function merge(base, over) {
    if (!isPlainObject(base))
        return clone(over);
    var out = clone(base);
    if (!isPlainObject(over))
        return out;
    for (var k in over) {
        if (isPlainObject(over[k]) && isPlainObject(out[k]))
            out[k] = merge(out[k], over[k]);
        else
            out[k] = clone(over[k]);
    }
    return out;
}

// noctalia's ConfigService::deepMerge for user files: like merge(), except that any table named
// "session" merges its `actions` array index by index when the action names match.
function deepMergeUser(base, over) {
    var out = isPlainObject(base) ? base : {};
    if (!isPlainObject(over))
        return out;
    for (var k in over) {
        var v = over[k];
        if (isPlainObject(v) && isPlainObject(out[k])) {
            if (k === "session" && Array.isArray(v.actions)) {
                out[k].actions = mergeSessionActions(out[k].actions, v.actions);
                var rest = {};
                for (var rk in v)
                    if (rk !== "actions")
                        rest[rk] = v[rk];
                deepMergeUser(out[k], rest);
                continue;
            }
            deepMergeUser(out[k], v);
            continue;
        }
        out[k] = clone(v);
    }
    return out;
}

function mergeSessionActions(baseActions, overlay) {
    if (!Array.isArray(baseActions))
        return clone(overlay);
    var merged = [];
    for (var i = 0; i < overlay.length; i++) {
        var o = overlay[i];
        var b = i < baseActions.length ? baseActions[i] : null;
        if (!isPlainObject(o) || !isPlainObject(b) || b.action !== o.action) {
            merged.push(clone(o));
            continue;
        }
        merged.push(deepMergeUser(clone(b), o));
    }
    return merged;
}

function clone(v) {
    if (Array.isArray(v))
        return v.map(clone);
    if (isPlainObject(v)) {
        var o = {};
        for (var k in v)
            o[k] = clone(v[k]);
        return o;
    }
    return v;
}

function barDefaults() {
    return clone(barDefaultsTable);
}
