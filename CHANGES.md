# Changes

## Review pass against noctalia v5.3.0

Every file was checked against the v5.3.0 sources (C++ structs, schema, IPC handlers, widgets).
These deviations and bugs were fixed:

### Configuration
- **Config stack:** noctalia's model replaces the single-file loader. Every `*.toml` in the config
  directory is merged in bytewise order, then `[include] files = [...]` (files or directories; `~`,
  `$VAR` and `${VAR}` expanded; relative to the including file; the host file wins; cycle-safe), then
  `[include] autoload = false` profiles, then the `settings.toml` overlay. `NOCTALIA_CONFIG_HOME` and
  `NOCTALIA_STATE_HOME` are honoured, and `session.actions` merges by index.
- **Errors:** a parse error or missing include anywhere keeps the previous configuration and shows a
  persistent "file:line" notification, which is dismissed when the config is fixed.
- **Hot reload:** every loaded file, include directory and `settings.toml` is watched. Adding or
  removing files is noticed too.
- **TOML parser:** now rejects duplicate keys, re-opened tables, modified inline tables and extended
  static arrays, like toml++. It was checked against the official toml-test suite and every TOML
  example in the noctalia docs.
- **Defaults:** now noctalia's C++ defaults instead of the stale `example.toml`:
  - Without any `[bar.*]` table, one bar named `default`, docked with `margin_ends = 100`. Before,
    a built-in `bar.main` always existed, so a user's `[bar.top]` produced two bars. Bars without
    `[bar] order` are ordered by name.
  - Launcher search at the bottom; weather enabled and `metric|imperial`; sounds on; 2 s idle fade.
  - Unlimited visible toasts; non-recursive wallpaper automation; dock flush with the edge.
  - Idle behaviours (with `lock-and-suspend`) seeded only when none are configured; session
    actions seeded only when the key is absent.
- **Seeded widgets:** noctalia's built-in instances (`cpu`, `temp`, `ram`, `network_tx`,
  `network_rx`, `output_volume`, `input_volume`, `date`, `active_window`, `media`, `keyboard_layout`,
  `lock_keys`, `spacer`) exist, with the type-match overlay rule.
- **Removed port-only keys:** `audio.volume_step`, `brightness.step`,
  `notification.default_timeout_ms`, `notification.critical_timeout_ms` and
  `notification.history_max_entries`.
- **Monitor selectors:** an exact connector name, or a whole word of the monitor's make, model or
  serial (bars, dock, OSD, notifications, IPC).
- **Colours:** hex colours follow noctalia (`#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` with alpha last,
  `#` optional).
- **New keys:** `theme.shell_mode`, `accessibility.high_contrast` and an exact `pure_black_dark`
  transform. Also `battery.warning_threshold`, `brightness.enable_ddcutil` / `sync_all_monitors` /
  `[brightness.monitor.*]`, `system.monitor.cpu_temp_sensor_path` and `*_poll_seconds = 0`.

### Bar
- **Concave edge corners:** noctalia's `concave_edge_corners`, with screen-edge flares into the end
  margins, or inner-edge fillets for full-length bars.
- **Gesture model:** builtin, then per-type defaults (noctalia's table), then `[bar.X.actions]`, then
  `[widget.X.actions]`. Unbound gestures fall through to the dead zone. `scroll_left`/`scroll_right`
  and reserved gestures are supported, and the builtin middle click runs `settings-open-widget`.
- **Per-widget settings:** capsule padding, opacity, border and foreground per widget; bar-wide
  `color`/`icon_color`; label size 14 (fontSizeBody).
- **Smart auto-hide:** `smart_auto_hide`, monitor-level `enabled = false`, and a ui-scaled
  `margin_opposite_edge`.
- **Clock:** default format `{:%H:%M}`, tooltip only with `tooltip_format`, stacked two-line formats,
  and the vertical token split.
- **Gesture defaults:** keyboard layout uses `keyboard-layout-cycle`, power profile
  `power-cycle next/prev`, network right-click `network-toggle`.

### IPC
- **Replies:** `ok`, a value or `error: …`. `status` prints JSON, `osd-toggle` prints on/off,
  `theme-mode-get` prints the resolved mode, `color-scheme-get` prints `<source> <name>`, and
  `color-scheme-set wallpaper <scheme>` works.
- **Levels:** parsed with noctalia's `parseNormalizedOrPercent`, with argument validation.
- **Brightness:** targets (`current`, `all`, `*`, display ids, selectors), DDC/CI via ddcutil, and
  `brightness-list-backlight-devices`.
- **Bars:** `bar-show/hide/toggle [bar] [monitor]`, `bar-reserve-toggle`, `bar-auto-hide-set` and
  `bar-layer-set`.
- **Other new commands:** `taskbar-cycle`, `network-toggle` (disconnect/reconnect), a clamped
  `workspace-switch`, `dock-reload` and `log-level-*`.

### Services and surfaces
- **OSD:** noctalia's card geometry and colours (error above 100%, dimmed when off), and
  `position_vertical` for vertical level OSDs. It shows on all outputs unless
  `follow_focused_output` is set. Texts come from noctalia's catalogue (e.g. "Caps Lock On"),
  external Bluetooth and power-profile changes show it, and media tracks and device switches are
  announced.
- **Notifications:**
  - Timeouts: `expire_timeout` 0 is persistent, -1 is 6 s; critical notifications no longer bypass
    DND.
  - History: low-urgency, transient and internal notifications stay out of it; capped at 100,
    with `history_retention_hours`.
  - Filters: noctalia's semantics (`match` / `match_content` / `matches`, `filter_order`,
    `blacklist`, `override_duration`, `allow_permanent`, `allowed_urgencies`).
  - Toasts: as many as fit (expiry paused for waiting toasts); card typography and progress
    colours.
- **Battery:** escalating low-battery warnings at threshold, 5 % and 2 %, and noctalia's glyph
  thresholds.
- **Hooks:** noctalia's names and variables. Battery: `battery_charging`, `battery_discharging`,
  `battery_plugged` and `battery_percentage_changed`. `power_profile_changed` carries `_PREVIOUS`
  and `_ORIGIN`, `wallpaper_changed` runs once per connector with `_PATH` and `_CONNECTOR`, and
  `theme_mode_changed` carries `_PREVIOUS` and `_CONFIGURED`. `session_unlocked` is best effort,
  via logind's LockedHint.
- **Audio:** setting the volume no longer unmutes; overdrive applies to the microphone; noctalia's
  volume glyphs.
- **Network:** noctalia's network glyphs.
- **Idle:** `pre_action_fade_seconds` fade overlay; `lock_before_suspend`.
- **Dock:** `show_dots` dots and `show_instance_count` badges as in noctalia; `[dock.monitor.*]`;
  `border` / `border_width`.
- **Language selection:** noctalia's candidate rules (no cross-region fallback, Chinese script
  inference).
- **Translation keys:** remapped to keys that exist in noctalia's catalogues.
- **Misc:**
  - The state file can no longer be overwritten before it is read.
  - The X11 bridge restart budget resets after a successful start.

### Packaging
- **`install.sh`:**
  - Safe to run from its own install location (it used to delete itself).
  - Correct `--help` output.
  - Detects multi-file configs.
  - Lists ddcutil.
- **README:** documents the config stack, the defaults, `bash install.sh`, and the remaining X11
  limitations.
