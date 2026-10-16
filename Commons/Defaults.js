// Default configuration for Noctalia-X11.
// Keys and values mirror noctalia v5.3.0 example.toml (snake_case TOML keys) for every
// setting this port understands. X11/XFCE specific settings live in the [x11] table.
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
        app_icon_color: "on_surface",
        clipboard_enabled: true,
        clipboard_history_max_entries: 100,
        clipboard_auto_paste: "auto",
        lang: "",
        avatar_path: "",
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
            launcher_placement: "floating",
            clipboard_placement: "floating",
            control_center_placement: "attached",
            wallpaper_placement: "attached",
            session_placement: "attached",
            launcher_position: "center",
            clipboard_position: "center",
            open_near_click_control_center: false,
            open_near_click_launcher: false,
            open_near_click_clipboard: false,
            open_near_click_wallpaper: false,
            open_near_click_session: false
        },
        launcher: {
            layout: "full",
            width: 760,
            search_position: "top",
            default_view: "recent",
            categories: true,
            category_icons_only: false,
            show_settings_button: true,
            show_session_button: true,
            show_icons: true,
            compact: false,
            app_grid: false,
            track_usage: true,
            sort_by_usage: true,
            pinned: [],
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
        mpris: {
            blacklist: []
        },
        session: {
            actions: [],
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
        "default": { path: "" },
        automation: {
            enabled: false,
            interval_seconds: 1800,
            order: "random",
            recursive: true
        }
    },
    theme: {
        mode: "dark",
        source: "builtin",
        builtin: "Noctalia",
        wallpaper_scheme: "m3-content",
        pure_black_dark: false
    },
    notification: {
        enable_daemon: true,
        show_app_name: true,
        show_actions: true,
        keep_dismissed_in_history: true,
        layer: "top",
        scale: 1.0,
        width: 360,
        background_opacity: 0.97,
        border: true,
        border_color: "outline",
        border_width: 1,
        monitors: [],
        offset_x: 20,
        offset_y: 8,
        position: "top_right",
        default_timeout_ms: 5000,
        critical_timeout_ms: 0,
        max_visible: 5,
        history_max_entries: 100
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
            privacy: true
        }
    },
    lockscreen: {
        enabled: true
    },
    system: {
        monitor: {
            enabled: true,
            cpu_poll_seconds: 2.0,
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
        enabled: false,
        refresh_minutes: 30,
        unit: "celsius",
        effects: true
    },
    audio: {
        enable_overdrive: false,
        enable_sounds: false,
        enable_volume_sounds: true,
        enable_notification_sounds: true,
        sound_volume: 0.5,
        volume_step: 5
    },
    brightness: {
        enable_ddcutil: false,
        minimum_brightness: 0.0,
        step: 5
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
        sunset: "20:30",
        sunrise: "07:30"
    },
    idle: {
        pre_action_fade_seconds: 0,
        behavior: {
            "lock": { timeout: 600, action: "lock", enabled: false },
            "screen-off": { timeout: 660, action: "screen_off", enabled: false }
        }
    },
    bar: {
        main: {
            enabled: true,
            position: "top",
            thickness: 34,
            background_opacity: 1.0,
            border: "outline",
            border_width: 0.0,
            radius: 12,
            margin_ends: 180,
            margin_edge: 10,
            margin_opposite_edge: 0,
            padding: 14,
            widget_spacing: 6,
            hover_highlight: true,
            show_tooltip: true,
            scale: 1.0,
            font_scale: 1.0,
            font_weight: 500,
            font_family: "",
            shadow: true,
            auto_hide: false,
            auto_hide_delay_ms: 0,
            reserve_space: true,
            layer: "top",
            capsule: false,
            capsule_fill: "surface_variant",
            capsule_thickness: 0.76,
            capsule_opacity: 1.0,
            capsule_border_width: 1.0,
            start: ["launcher", "wallpaper", "workspaces"],
            center: ["clock"],
            end: ["media", "tray", "notifications", "clipboard", "network", "bluetooth", "volume", "brightness", "battery", "control-center", "session"]
        }
    },
    dock: {
        enabled: false,
        position: "bottom",
        icon_size: 48,
        main_axis_padding: 16,
        cross_axis_padding: 8,
        item_spacing: 6,
        background_opacity: 0.88,
        radius: 16,
        margin_edge: 8,
        show_running: true,
        auto_hide: false,
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

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Deep merge: arrays and scalars from `over` replace those in `base`.
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

// Bars inherit [bar.main] defaults for keys they omit (named bars are fully independent in
// noctalia, but sharing the base defaults keeps partial bar tables usable).
function barDefaults() {
    return clone(defaults.bar.main);
}
