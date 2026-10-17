# Noctalia X11 — Deep Analysis Report

**Subject:** `noctalia-x11_tar.gz` — a Quickshell (QML) port of Noctalia Shell v5.3.0 for XFCE / xfwm4 on X11
**Method:** static review of every source file (QML, JS, Python, shell, TOML, JSON, docs, licences), plus mechanical validation (syntax checks, translation coverage, glyph resolution, palette integrity)
**Not done:** the shell was not executed (no Quickshell/Qt/X server in the analysis sandbox). Runtime-dependent findings are marked **[verify]**.

---

## 1. Executive summary

This is a well-structured, unusually complete port. It re-implements Noctalia's design, config schema, IPC vocabulary, ten palettes, icon font and translations on top of Quickshell, and replaces every Wayland-only dependency with an X11 equivalent through a small, dependency-free Python/ctypes bridge. Code is consistent, readable, and mostly defensive.

**Overall assessment:** good quality, close to usable as-is. No critical vulnerabilities were found. The most important issues are:

| # | Finding | Severity |
|---|---|---|
| F1 | Notification bodies are rendered as Qt StyledText from untrusted senders, with clickable links that go to `Qt.openUrlExternally`, and `<img>` is not stripped | **Medium** (phishing / tracking) |
| F2 | Notification `expireTimeout` is probably treated in the wrong unit (seconds vs. ms) **[verify]** | **Medium–High** (functional) |
| F3 | Wi-Fi passwords are passed on the `nmcli` command line (visible in `/proc/<pid>/cmdline`) | **Medium** |
| F4 | Clipboard history persists *everything* copied (including secrets) as plaintext JSON, uncapped per entry | **Medium** |
| F5 | PipeWire object tracking only covers the default sink/source/streams; device list and per-app volumes may be empty **[verify]** | **Medium** (functional) |

Everything else is low severity or informational (§6). Positive findings (§7) include safe command construction in most places, a non-`eval` calculator, atomic state writes, a bridge that never crashes on bad input, 100 % resolvable glyph references, and complete, valid palettes.

---

## 2. Archive inventory

| Item | Count / size |
|---|---|
| Files (excluding directories) | 149 |
| QML files | 94 (11,884 lines) |
| JS modules (`Commons/*.js`) | 5 (1,743 lines) |
| Python | `scripts/x11-bridge.py` (736 lines) |
| Shell | `install.sh` (129), `scripts/xfce-setup.sh` (97), `bin/noctalia-msg` (32) |
| Config / docs | `config.example.toml` (299), `README.md` (240), `.desktop` autostart, 2 licence files + Tabler licence |
| Assets | 27 translation catalogs, `emoji.json` (1,913 emoji), Tabler icon font (2.4 MB TTF) + `tabler.json` (5,958 glyphs), 4K wallpaper PNG (5.4 MB), SVG logo, 7 screenshots |
| Code by layer | Commons 2,504 · Services 3,382 · Widgets 693 · Modules 6,979 lines |
| Process spawns | 25 `execDetached` call sites, ~20 `Process` objects |

**Mechanical validation results**

- `x11-bridge.py` compiles; `install.sh`, `xfce-setup.sh`, `noctalia-msg` pass `bash -n`/`sh -n`.
- All five JS modules pass `node --check`.
- All 10 palettes × 2 modes contain all 16 colour roles with valid `#rrggbb` values.
- All 80 glyph aliases resolve to real Tabler glyphs; every glyph name referenced from QML resolves.
- All 27 translation files are valid JSON, but coverage is uneven (see §5.9).
- Executable bits are set on the four scripts in the archive.

---

## 3. Architecture

```
shell.qml (ShellRoot)
 ├─ per screen: Bar × N bars, PanelHost, Toasts, OsdWindow, [Dock via LazyLoader]
 ├─ OsdTriggers   (signals from services → OSD)
 └─ Ipc           (IpcHandler → Commands.run)

Commons/   Config (TOML→merge defaults, hot reload) · Theme · Style · Icons · I18n · ShellState (JSON)
Services/  singletons: X11 bridge client, Audio, Network, Bluetooth, Power, Media, Notifications,
           Session, Idle, NightLight, Wallpaper, Clipboard, Weather, SystemMonitor, Panels, Commands, Hooks…
Widgets/   N* primitives (button, slider, toggle, card, text field, graph, tooltip…)
Modules/   Bar (+ 20 widgets) · Panels (host+frame) · Launcher · ControlCenter (11 files) · Notifications
           · Osd · Session · ClipboardPanel · WallpaperPicker · TrayMenu · Dock · Ipc

scripts/x11-bridge.py  ⇄ stdin/stdout JSON lines ⇄ Services/X11.qml
```

Key design decisions (all sound):

1. **Single active panel** (`Services/Panels.qml`) shown by one `PanelHost` window per screen, so keyboard focus and "click outside closes" are handled in one place.
2. **Bridge instead of polling** — EWMH/XKB/XScreenSaver events are streamed as JSON; commands go back on stdin.
3. **Delegated locking** — no fake lock screen; `xflock4` (or another locker) is used. This is the correct security call on X11.
4. **Config fidelity** — noctalia's snake_case TOML schema is honoured; unknown keys are ignored; a native `~/.config/noctalia/config.toml` is accepted read-only.
5. **Compositor awareness** — `X11.composited` flips `Style.cornerScale` to 0 and switches `PanelHost` to an opaque, panel-sized fallback window when no compositing manager runs.

---

## 4. Component analysis

### 4.1 Top level

| File | Purpose | Notes |
|---|---|---|
| `shell.qml` | Entry point. Forces creation of lazy singletons via a `boot` array, runs the `started` hook after 1.5 s, instantiates per-screen windows. | Clean. The `boot` array trick works but is implicit; a comment explains it. |
| `install.sh` | Copies or symlinks into `~/.config/quickshell/noctalia-x11`, installs `noctalia-msg`, seeds config, creates autostart. | `set -euo pipefail`; `--uninstall` keeps user config/state. It does `rm -rf "$DEST"` on reinstall (expected). Dependency report only warns. |
| `noctalia-x11.desktop` | Autostart with `sleep 2` before `qs -c noctalia-x11`. | A fixed sleep is a heuristic; xfdesktop/xfwm4 normally start earlier. |
| `bin/noctalia-msg` | Wraps `qs ipc call noctalia msg "<command>"`. | **F14:** joins args with `"$*"`, losing quoting (see §6). |
| `config.example.toml` | Documented defaults for everything the port reads, plus `[x11]`. | Consistent with `Defaults.js`. |
| `README.md` | Install, XFCE integration, config, IPC, limitations, troubleshooting. | Accurate overall; a few claims are slightly ahead of the code (§6, F23). |
| `LICENSE`, `LICENSE.noctalia`, `assets/fonts/tabler-icons-license.txt` | MIT for the port, Noctalia and Tabler. | Attribution is correct and present. |

### 4.2 `scripts/x11-bridge.py` (736 lines)

Pure Python 3 + `ctypes` against libX11 (optional libXss). Streams `state`, `keyboard`, `idle`, `pointer`, `compositor`, `ready`, `error` events; accepts ~20 commands on stdin.

Strengths
- Struct layouts (`XEvent` union, `XkbStateRec`, `XScreenSaverInfo`) and every function signature are declared explicitly; format-32 properties are read as `c_ulong`, which is correct on 64-bit.
- A no-op X error handler is installed and kept referenced, so stale window IDs cannot kill the process.
- `emit()` exits quietly on `BrokenPipeError`; the main loop returns when stdin closes (parent gone); each command is wrapped in `try/except`.
- State emission is coalesced (40 ms) and de-duplicated against the last state.
- Compositor detection via `_NET_WM_CM_S<n>` selection owner (every 3 s) feeds the opaque fallback.
- Idle polling only runs when the shell asks (`idle on`), at 1 Hz.
- Client messages follow EWMH (`_NET_ACTIVE_WINDOW` with source=pager, `_NET_CLOSE_WINDOW`, `_NET_WM_STATE` toggle, `_NET_CURRENT_DESKTOP`, `_NET_WM_DESKTOP`).

Observations
- The bridge's own bar windows are filtered by `_NET_WM_PID == parent pid && type == dock`; docks are also in `SKIP_TYPES`, so this is belt-and-braces.
- Keyboard layout names come from `/usr/share/X11/xkb/rules/{evdev,base}.lst`; if absent they fall back to the upper-cased layout code. Fine.
- `focus-title` walks the window tree to depth 3 by `_NET_WM_NAME`. The only caller (`PanelHost`) sets the title itself to `noctalia-x11-panel-<screen>`, so there is no injection path through window titles.
- Minor: a redundant condition in `poll_idle` (`secs > 0 or last_idle > 0 or last_idle < 0` is always true when `secs != last_idle`).

### 4.3 `scripts/xfce-setup.sh`

Sets xfwm4 compositing, masks/hides `xfce4-notifyd`, binds `Super` shortcuts and media keys through `xfconf-query`, optionally quits `xfce4-panel`, and can revert.
- Idempotent (`-n -t` create, fall back to update).
- **F19:** `--revert` removes the shortcut keys outright, which also deletes any binding the user had on the same accelerator before (e.g. a pre-existing `<Super>space`). It does not touch the compositor setting. On non-systemd systems, killing `xfce4-notifyd` is not durable because D-Bus activation can respawn it whenever Noctalia isn't yet owning the name.

### 4.4 `Commons/`

| File | Role | Review |
|---|---|---|
| `Config.qml` | Locates own/shared config, watches both files, merges over defaults, exposes `get("a.b.c")`, `bars`, `barForScreen`, `widgetSettings`. | Parse errors keep the previous config (good). Bar names are stable strings so `Variants` doesn't recreate windows on reload. `~`/`$HOME` expansion only. |
| `Toml.js` | Self-contained TOML parser/serializer. | Handles tables, arrays of tables, inline tables, dotted keys, multiline strings, escapes, hex/oct/bin, CRLF. Validation is "loose": duplicate keys/tables silently overwrite; dates become strings; `arrayTables` variable is unused. Adequate for config use. |
| `Defaults.js` | Full default tree + deep `merge`/`clone`/`barDefaults`. | Contains keys not consumed anywhere (e.g. `dock.launcher_position`, `dock.show_dots`, `brightness.enable_ddcutil`, `weather.effects`, `shell.panel.*_near_click_*` partly). Harmless. |
| `Util.js` | strftime + chrono-format shim, fuzzy scorer, recursive-descent calculator, byte/speed/duration formatters, NOAA sunrise/sunset, shell-quote, HH:MM parser. | Calculator never uses `eval` (safe). `%j` can be off by one in the first hour after midnight during DST (floor of a 23-h day difference). `,`→`.` assumes decimal-comma usage, so `1,000` evaluates to 1. |
| `Theme.qml` | Palette resolution, mode (dark/light/auto), pure-black option, wallpaper-derived palettes, `resolve("primary/0.5")` colour specs. | Comment promises "smooth cross-fades" but `fadeMs` is unused in the singleton; cross-fades actually come from `Behavior on color` inside `NText/NIcon/NButton`. `paletteFromColors` tracks "second best" colour imperfectly (it is the *previous* best, not the true runner-up). |
| `Style.qml` | Design tokens (radii, spacing, type, control sizes) × `ui_scale` and `corner_radius_scale`. | Clean; `composited` zeroes corner radii when no compositor. |
| `Icons.qml` | Tabler font + alias registry; unknown glyph → skull (matches upstream). | Paths derived via `Qt.resolvedUrl(...).replace("file://","")` are not URL-decoded, so an install path containing spaces/`%` would break font/JSON/translation loading. |
| `GlyphAliases.js` | 80 curated aliases. | All resolve. |
| `I18n.qml` | Loads `en.json` + selected language; `tr(key, fallback, vars)`; maps `zh-CN`→`zh-Hans`, `nb`→`nn`, etc. | **F13:** switching the language back to English at runtime leaves the previous catalog in `current` (the non-English loader's path becomes `""` and never resets `current`). |
| `ShellState.qml` | JSON state in `$XDG_STATE_HOME/noctalia-x11/state.json`, atomic writes, 600 ms debounce. | `save()` does not wait for `loaded`; a `set()` that lands before the initial read completes could be persisted before/over loaded data (tiny window). |
| `Palettes.js` | 10 generated palettes. | Complete and valid. |

### 4.5 `Services/`

| Service | What it does | Review |
|---|---|---|
| `X11.qml` | Spawns the bridge, parses events, exposes desktops/windows/keyboard/idle/compositor, helper geometry functions. | Auto-restarts the bridge (max 20). `restarts` is never reset after a stable run. |
| `Panels.qml` | Active-panel state machine; IPC opens on the screen under the pointer (asks the bridge, 400 ms fallback to active window). | Good multi-monitor handling. |
| `Commands.qml` | The IPC vocabulary (≈110 commands), tokenizer, screenshot/settings helpers. | `exec <cmd>` runs arbitrary shell by design. `openSettings()` embeds the config path in a single-quoted shell string without escaping `'` (path comes from env/config, so low risk). `screenshot-annotate` is aliased to region screenshot. A handful of accepted commands (`workspace-switch`, `network-toggle`, `keyboard-layout-cycle`, `settings-open-widget`) are not listed in `help`. |
| `Notifications.qml` | `NotificationServer`, toasts, history (100), DND, filters, persistence. | See F1, F2, F5-history below. Handles `replaces` by overwriting a toast with the same id; whether Quickshell re-emits `onNotification` for replaced notifications should be confirmed **[verify]**. |
| `Audio.qml` | PipeWire sink/source/streams, volume ops, IPC level parsing. | See F5. |
| `Network.qml` | `nmcli` status via one batched shell call; `nmcli monitor` for events; scan/connect/forget. | See F3. If `nmcli` is missing, the monitor process restarts every 10 s (harmless busy-wait). |
| `BluetoothService.qml` | Thin wrapper over `Quickshell.Bluetooth`. | Fine. |
| `Power.qml` | UPower battery + power-profiles-daemon (presence probed via `busctl`). | Good guard against noisy errors. |
| `Media.qml` | MPRIS player selection (blacklist, manual cycle, playing-first). | Good. |
| `Brightness.qml` | `brightnessctl` get/set + sysfs watch + 3 s poll. | **F9:** `setter.command` is replaced while a previous run may still be active, so rapid scroll steps can be dropped (setting `running = true` on a running Process is a no-op). Header comment mentions `ddcutil` support that is not implemented. |
| `NightLight.qml` | Sun schedule → `redshift`/`gammastep`/`sct`/`xrandr --gamma`; also drives `Theme.autoIsNight`. | **F10:** only resets gamma if *this session* applied warm; a warm gamma left from a previous session stays until night light next toggles. |
| `Idle.qml` | Caffeine (xfpm presentation mode + `systemd-inhibit` + `xset`) and idle behaviors (lock, screen-off, suspend, command). | **F20:** turning caffeine off runs `xset s on +dpms` unconditionally, overwriting whatever the user had before. At startup with caffeine already on, `hasXfpm` may not be known yet, so presentation mode may be skipped. |
| `Session.qml` | Lock/logout/suspend/reboot/shutdown via `xflock4`/`xfce4-session-logout`/logind fallback; hook events. | Good. Lock fallback chain ends in `loginctl lock-session`. |
| `Wallpaper.qml` | xfdesktop (xfconf), feh, xwallpaper, hsetroot; directory scan (`find -L … | head -2000`); automation timer; ColorQuantizer palette. | Uses `sh -c script sh "$dir"` (safe). **F11:** `"file://" + path` URLs are not encoded (`#`, `%`, `?`, spaces in filenames break thumbnails/quantizer). |
| `Clipboard.qml` | Text history from `Quickshell.clipboardText`, pinning, auto-paste via `xdotool`. | See F4, F7. |
| `Weather.qml` | Open-Meteo forecast; geocoding through `api.noctalia.dev` with Open-Meteo fallback. | **F18:** XHR has no timeout, so a hung request leaves `loading = true` forever and blocks refreshes. Network calls only happen when enabled and not in offline mode. |
| `SystemMonitor.qml` | CPU/mem/net/disk/temp from `/proc`, `/sys`, `df`; polling only while consumers exist. | Net totals include VPN/tunnel interfaces (double counting traffic); only `/` for disk. |
| `ThemeControl.qml` | Mode/source state, optional GTK/icon theme switch through xsettings, config-change reset of runtime overrides. | Only GTK theme and icon theme are switched — not the xfwm4 window-manager theme, cursor theme or terminal/app themes. |
| `Hooks.qml` | Runs `[hooks]` commands with `NOCTALIA_*` exports (values single-quote-escaped). | Safe. |
| `Osd.qml` | OSD state and hide timer. | Fine. |
| `Apps.qml` | Desktop entries, usage tracking, window-class→icon resolution. | `Terminal=true` launch builds a quoted command; the two branches of the final ternary are identical (dead code). |

### 4.6 `Widgets/` (N* primitives, 693 lines)

`NButton` (8 variants incl. selected/hover/pressed), `NIconButton`, `NText` (**PlainText** — good), `NIcon`, `NSlider` (live/commit modes, wheel), `NToggle`, `NCard`, `NDivider`, `NTextField` (focus ring, key-navigation signals), `NScrollBar`, `NGraph` (Canvas area chart), `NTooltip` (override-redirect `PopupWindow`), `NRoundedImage` (`ClippingRectangle`), `NAppIcon` (`IconImage` + glyph fallback). Consistent, theme-driven, no keyboard focus handling beyond the text field (accessibility is mouse-centric).

### 4.7 `Modules/Bar/`

- **`Bar.qml`** — a `PanelWindow` per bar per screen; position, thickness, margins, struts (`exclusiveZone`), auto-hide with peek on workspace switch, dead-zone gestures, tooltips. Margins are clamped so ends never collapse below ~320 px.
- **`BarWidget.qml`** — shared base: capsule styling, hover highlight, tooltip delegation, gesture→action resolution (`widget.actions` > `bar.actions` > widget defaults > global defaults). Widget-level `MouseArea` sits *below* content so child controls get clicks first.
- **`BarSection.qml`, `BarWidgetLoader.qml`** — grid layout (horizontal/vertical), name→type→file mapping, unknown widgets warn once.
- **Widgets (20 files):** `GlyphButton` (launcher, control-center, session, wallpaper, clipboard, screenshot, settings, custom_button), `Workspaces` (regular/minimal/focus_hint), `Taskbar`, `ActiveWindow`, `Clock`, `Media`, `Tray`, `NotificationsButton`, `Network`, `Bluetooth`, `Volume`, `Brightness`, `Battery`, `Sysmon`, `KeyboardLayout`, `LockKeys`, `ToggleButton` (caffeine/nightlight/power_profile/theme_mode), `WeatherWidget`, `Spacer`, `TextWidget`.
  - Behaviour is rich and matches the README list. `Taskbar` only shows the active desktop by default; middle-click closes, right-click minimizes, left toggles.
  - `Tray` shows StatusNotifierItems only (XEmbed needs `snixembed`) and routes menus through `Panels` → `TrayMenuPanel`.
  - `Media` supports marquee scrolling, rotating art, progress line.
  - Remote album-art URLs (e.g. `https://…`) are fetched directly by Qt `Image`.

### 4.8 `Modules/Panels/`

- **`PanelHost.qml`** — one overlay window per screen. With a compositor: full-screen transparent overlay inside the strut area, with backdrop dim, outside-click close, open/close animations, attached ("grows out of the bar") or floating placement, anchor-aware clamping. Without: an opaque window exactly panel-sized that closes on focus loss. Keyboard focus: sets the window title, asks the bridge for `_NET_ACTIVE_WINDOW`, then `requestActivate()`; `focus_method = "qt"` bypasses the bridge.
  - Panels are re-instantiated on every open (state such as the launcher query is not kept). Acceptable.
- **`PanelFrame.qml`** — `Shape`/`PathSvg` drawing of the attached panel with concave "flare" corners for all four edges (neat, correct arcs).

### 4.9 `Modules/Launcher/LauncherPanel.qml` (778 lines)

Full and simple layouts; views Recent/Pinned/All/Categories/Providers; fuzzy search with usage boost; list or grid; right-click pin. Providers: calculator (global), `/emo` (1,913 emoji with keywords and usage ranking), `/win`, `/session`, `/wall` (200 results), `/pan` (panels and Control Center tabs).
- **F12:** `launcher_pinned`, `launcher_grid`, `launcher_sort_usage` in runtime state permanently override `[shell.launcher]` config once the user clicks the UI controls.
- **F16:** `results` depends on `ShellState.data`; any unrelated state write (e.g. unread-notification counter) re-evaluates the list and resets `selected` to 0.
- The toolbar avatar only checks `~/.face`, while Home tab also checks `.face.icon` and AccountsService; the example config comment promises both.

### 4.10 `Modules/ControlCenter/` (11 files, ~2,300 lines)

`ControlCenterPanel` (sidebar full/compact/none, tab keyboard navigation, tabs hidden by config/availability), `HomeTab` (profile card with wallpaper, media summary, clock/weather, up-to-6 shortcut tiles), `ShortcutTile` (13 tile types), `ListRow`, `SectionLabel`, and tabs: `MediaTab`, `AudioTab`, `MonitorTab`, `SystemTab`, `NetworkTab`, `BluetoothTab`, `WeatherTab`, `CalendarTab`, `NotificationsTab`, `PowerTab`.
- Clean and consistent. Items worth knowing:
  - `NetworkTab`: the show-password toggle (`showPw`) is permanently `visible: false`, so the password can never be revealed (dead UI). Password handling: see F3.
  - `BluetoothTab`: clicking an unknown device sets `trusted = true` *before* `pair()`. `section.property: "paired"` has no effect on a JS-array model and no section delegate exists. Quickshell has no BlueZ pairing agent, so PIN/passkey pairing needs another agent running (e.g. `blueman-applet`).
  - `SystemTab` shells out to `wmctrl -m` for the WM name; `wmctrl` is not in the README's optional-tools table.
  - `CalendarTab`: `today` is captured once and never refreshed after midnight.
  - `ShortcutTile` "screenshot": `Commands.run("exec sleep 0.4; true")` is detached and does not delay the following screenshot call (no effect).
  - Several UI strings are hard-coded English (e.g. "Waiting for sunset", "Hardware switch is off", "No Bluetooth adapter (BlueZ) found.").

### 4.11 `Modules/Notifications`, `Osd`, `Session`, `ClipboardPanel`, `WallpaperPicker`, `TrayMenu`, `Dock`, `Ipc`

- **`Toasts.qml`** — one stack window per screen (or `monitors` allow-list), slide/fade-in, max visible 5.
- **`NotificationCard.qml`** — summary is plain text; **body is `Text.StyledText`** with `onLinkActivated: Qt.openUrlExternally(link)` (F1). Left-click invokes the default action; right/middle dismisses; progress bar for timeout; hover pauses timer.
- **`OsdWindow.qml` / `OsdTriggers.qml`** — horizontal/vertical OSD; triggers from audio, brightness (also external changes), caffeine, night light, DND, Wi-Fi, Bluetooth, power profile, keyboard layout, lock keys; battery-low internal notification. Armed after 2.5 s to avoid startup noise (a slow first `nmcli` could still produce a spurious "Wi-Fi on" OSD/hook at startup).
- **`SessionPanel.qml`** — list/grid of actions, number-key shortcuts, optional countdown with cancel. Default actions have **no countdown**, so pressing `5` while the menu is open shuts down immediately (UX safety note).
- **`ClipboardPanel.qml`** — search, pin, delete, clear, Enter to paste; entries are shown as PlainText (first 600 chars). See F4, F7, F8.
- **`WallpaperPanel.qml`** — thumbnail grid with fuzzy filter, per-monitor targets, random/rescan/open folder.
- **`TrayMenuPanel.qml`** — DBusMenu rendering with submenu stack. The mnemonic stripper `replace(/_([^_])/g, "$1")` also removes legitimate underscores in labels (e.g. file names).
- **`Dock.qml`** — pinned+running apps, magnification, grouping, indicators, auto-hide. The window is as tall as the *magnified* dock while `exclusiveZone` only reserves the base thickness, so a transparent strip overlaps application windows and swallows clicks there (F15).
- **`Ipc.qml`** — IPC targets `noctalia` (`msg`, `help`), `panel`, `launcher`, `controlCenter`, `session`. Any same-user process can call `exec`; this is equivalent to upstream and not an escalation.

### 4.12 Assets and docs

- **Translations:** see §5.9.
- **Fonts/icons:** `noctalia-tabler.ttf` + `tabler.json` map 5,958 names; licence file included.
- **`emoji.json`:** 1,913 entries, all with `emoji`, `name`, `category`.
- **Wallpaper:** 3840×2160 PNG (5.4 MB — 66 % of the compressed archive). Converting to JPEG/WebP would shrink the install considerably.
- **Screenshots:** 7 JPEGs (two are thin crops: 1600×60 and 1600×260).

---

## 5. Cross-cutting analysis

### 5.1 Security posture
- Shell strings are built carefully almost everywhere: `sh -c 'script' sh "$arg"` for directories, single-quote escaping for hook values and wallpaper paths, argv arrays for `nmcli`/`xfconf-query`.
- No `eval`, no `Function()`; the calculator is a hand-written parser; `NText` renders PlainText.
- Persistent data: state JSON, clipboard JSON, notification JSON — all plaintext in `~/.local/state/noctalia-x11/` (permissions follow the umask).
- Network: Open-Meteo, `api.noctalia.dev` (geolocation/geocoding, only if configured). `shell.offline_mode` disables it.
- The shell trusts local D-Bus senders for notifications (see F1).

### 5.2 Robustness and error handling
Good: bridge never dies on bad input; config parse errors keep last config; missing tools degrade (widgets hide). Weaker: several one-shot probes (`hasXfpm`, `profilesAvailable`, wallpaper backend, `hasXfceLogout`) run once at startup and are never refreshed.

### 5.3 Performance
Polling is demand-driven (SystemMonitor consumers; idle watch only when needed). Per-screen always-existing windows (PanelHost, Toasts, OSD) are unmapped when idle. Launcher results are one large binding re-evaluated on any dependency change (F16). Wallpaper scan is bounded (depth 4, 2,000 files).

### 5.4 X11 specifics
EWMH usage is correct. Struts via Quickshell `exclusiveZone`. Transparency needs a compositor (handled). Focus-stealing prevention in xfwm4 is why the bridge activation path exists. `xdotool key ctrl+v` auto-paste cannot paste into terminals (they use Ctrl+Shift+V).

### 5.5 Config fidelity
Schema is largely noctalia's. Ported-but-reduced: lock screen (delegated), wallpaper transitions, calendar accounts, polkit agent, window switcher, community palettes, app theming templates, plugins/desktop widgets. README lists these honestly.

### 5.6 Theming and Catppuccin users
- The builtin **Catppuccin** palette is Mocha (dark: surface `#1e1e2e`, primary mauve `#cba6f7`) and Latte (light: surface `#eff1f5`, primary mauve `#8839ef`). There is no Macchiato or accent (peach) variant, and palettes are compiled into `Palettes.js` (no user palette files).
- Mode switching only drives GTK theme + icon theme through `xsettings` (`[x11] gtk_theme_dark/light`, `icon_theme_dark/light`). It does **not** change the xfwm4 theme, cursor theme, or terminals/apps — those need `[hooks] theme_mode_changed` commands (the hook receives `NOCTALIA_THEME_MODE`).

### 5.7 Documentation accuracy
README is thorough and mostly exact. Slight overstatements: translations "27 languages" (coverage varies), Brightness header mentions ddcutil, example config says avatar falls back to AccountsService (launcher doesn't), Theme comment about cross-fades.

### 5.8 Dead code and leftovers
Identical ternary branches (`Apps.launch`, `NotificationCard` left-click), unused `volumeAdjusted` signal, unused `arrayTables`, invisible show-password button, no-op `section.property`, unused defaults keys.

### 5.9 Translation coverage (computed against `en.json`, 3,126 keys)

| Coverage | Languages |
|---|---|
| ≥ 95 % | es (97 %), it, pt-BR (99 %), ru (96 %), zh-Hans (98 %) |
| 75–95 % | ar, ca, de, he, ko, nn, tr, uk-UA, vi, hu, ja |
| 40–75 % | cs, fr, gl-ES, nl, pl, be |
| < 30 % | sv (22 %), ku (24 %), zh-Hant (27 %), be-Latn (<1 %) |

Missing keys fall back to English per key (correct). Additionally, **23 keys requested from QML do not exist in `en.json`** (e.g. `clipboard.search`, `control-center.network.password-for`, `power.battery.remaining`, `wallpaper.empty`, `weather.loading`, `launcher.workspace`), so those strings are never translated in any language. A few catalogs have a placeholder mismatch in 1–2 entries (ar, cs, fr, gl-ES, it, ko, pl, sv, uk-UA, vi).

---

## 6. Findings register

Severity: **High / Medium / Low / Info**. "[verify]" = depends on runtime behaviour I could not execute.

### Security / privacy

**F1 — Untrusted notification markup (Medium).** `NotificationCard.qml` renders `body` with `Text.StyledText` (only newline→`<br>`; no escaping or allow-list) and opens clicked links with `Qt.openUrlExternally`. The server advertises `bodyMarkupSupported` and `bodyHyperlinksSupported`, and declares `bodyImagesSupported: false` but nothing strips `<img>`.
Impact: any app (browser, chat client) can show deceptive link text pointing elsewhere, trigger `xdg-open` on arbitrary URL schemes, and possibly cause image fetches (tracking). A plain `<` or `&` in a body also renders incorrectly.
Fix: sanitize to the freedesktop subset (`b`, `i`, `u`, `a href` with `http(s)` only), escape everything else, and show the real URL on hover/confirm; strip `<img>`.

**F3 — Wi-Fi password in argv (Medium).** `Network.connect()` runs `nmcli device wifi connect <ssid> password <pw>`, exposing the secret to other local users via `ps`/`/proc`. Fix: use `nmcli --ask` and write the password to the process stdin, or create the connection through D-Bus.

**F4 — Clipboard history stores secrets (Medium).** Every text copy (including password-manager copies) is saved to `clipboard.json` in plaintext, displayed in the panel, and has no per-entry size cap (only an entry-count cap). `clipboard-clear` removes history but not the live selection. Mitigations: ignore entries when a password-manager hint/known source is present, add a max-length, allow a "pause recording" toggle, keep history in memory only (or `0600`), and clear the live clipboard on "clear".

**F5b — Notification history on disk (Low–Medium).** Bodies of up to 100 notifications are persisted in `notifications.json` (`keep_dismissed_in_history` default true). Consider an option to not persist, or set restrictive file mode.

### Functional

**F2 — `expireTimeout` units (Medium–High) [verify].** `Notifications.handle()` passes `n.expireTimeout` straight into `timeout`, and `NotificationCard` compares it against elapsed **milliseconds** (50 ms ticks). Quickshell documents `Notification.expireTimeout` in **seconds**; if so, an app that requests 5 s yields `timeout = 5`, and the toast disappears after ~50 ms. Test: `notify-send -t 5000 test`. Fix: multiply by 1000 (and handle `-1` / `0`).

**F5 — PipeWire tracking (Medium) [verify].** `PwObjectTracker` binds only `[sink, source] + streams`, while `sinks`, `sources` and `streams` are filtered with `n.audio` (which may be null until a node is bound). That can (a) hide all non-default devices and (b) create a chicken-and-egg where streams are never bound because they are not yet in `streams`. The usual pattern is to track `Pipewire.nodes.values` and filter afterwards.

**F7 — Auto-paste race (Low–Medium).** Selecting a clipboard/emoji entry closes the panel (≈200 ms animation + unmap) and pastes after 220 ms. If focus has not returned to the previous window, `Ctrl+V` goes to the wrong target. Consider waiting for the host's `shown=false`/active-window change instead of a fixed timer.

**F8 — Delete key in clipboard search (Low).** `Keys.onDeletePressed` on the search field deletes the *selected history entry*, so editing the query with Delete can destroy an entry.

**F9 — Brightness set coalescing (Low).** See §4.5; rapid wheel steps can be lost.

**F10 — Stale warm gamma after restart (Low).** See §4.5.

**F11 — Unencoded `file://` URLs (Low).** Wallpaper thumbnails, quantizer source, custom button images, avatars and notification images use string concatenation; names containing `#`, `%`, `?` break. Use `Qt.resolvedUrl`/`encodeURI`.

**F12 — Runtime state shadows config (Low).** Pinned apps/grid/sort once changed in the UI are never read from config again (unlike theme, which resets on config change).

**F13 — I18n edge cases (Low).** Language switch back to `en` leaves old catalog; 23 untranslated keys; uneven catalogs (§5.9).

**F14 — `noctalia-msg` quoting (Low).** `"$*"` flattens arguments, so `noctalia-msg notification-show "Hello world" "Body"` is tokenized as three words. Fix: build the command line with explicit re-quoting (`printf '%q '`) or pass JSON.

**F15 — Dock overlap (Low).** See §4.11; set an input `mask` or reserve the magnified size.

**F16 — Launcher selection reset (Low).** See §4.9.

**F17 — Session menu safety (Low/UX).** Default Shut Down/Reboot have no countdown or confirmation; a single key triggers them.

**F18 — Weather robustness/privacy (Low).** No XHR timeout; geolocation/geocoding use `api.noctalia.dev` (third-party dependency for a port).

**F19 — XFCE helper side effects (Low).** See §4.3.

**F20 — Idle side effects (Low).** See §4.5.

**F21 — State/history load races (Low).** `ShellState.save()` doesn't wait for `loaded`; `notifications.json` load clears the in-memory history (notifications arriving before the load completes are lost).

### Informational

**F22 —** Dead code/leftovers listed in §5.8.
**F23 —** Documentation/code mismatches listed in §5.7.
**F24 —** `%j` DST off-by-one; TOML duplicate keys accepted; decimal-comma handling in calculator; tray-menu underscore stripping; net monitor counts tunnel interfaces; one-shot capability probes never refreshed.

---

## 7. Strengths

1. **Faithfulness**: schema, IPC commands, palettes, glyph aliases, translations and style tokens are generated from upstream sources.
2. **Bridge design**: dependency-free, event-driven, resilient.
3. **Graceful degradation**: missing `nmcli`/BlueZ/UPower/brightnessctl/PipeWire hides or disables the relevant UI instead of erroring.
4. **Safe-by-default choices**: delegated screen locking, PlainText rendering, calculator without `eval`, atomic writes, quoted shell construction.
5. **Compositor fallback**: opaque panel path when no compositing manager runs.
6. **Multi-monitor and multi-bar support** including per-monitor overrides and IPC resolution by pointer position.
7. **Documentation and licensing**: thorough README, honest "not ported" list, correct attributions.
8. **Hygiene**: syntax checks pass for Python, shell and JS; no unresolved glyphs; complete palettes.

---

## 8. Recommended actions (priority order)

1. Verify and fix **F2** (timeout units) and **F5** (PipeWire tracking) — they affect everyday use.
2. Sanitize notification bodies and links (**F1**).
3. Stop putting the Wi-Fi password in argv (**F3**).
4. Harden clipboard history (**F4**): size cap, pause toggle, no-persist option, restrictive permissions; make "clear" also clear the live selection.
5. Fix small correctness issues: URL encoding (F11), Delete key (F8), brightness coalescing (F9), I18n reset (F13), `noctalia-msg` quoting (F14), add the 23 missing `en.json` keys.
6. Add confirmation/countdown defaults for destructive session actions (F17); wait for focus return before auto-paste (F7).
7. Document `[hooks] theme_mode_changed` recipes for xfwm4/cursor/terminal theme switching, and optionally extend `ThemeControl` to set the xfwm4 theme (`xfconf-query -c xfwm4 -p /general/theme`) and cursor theme.
8. Optionally shrink the wallpaper (PNG→WebP/JPEG) and add a `--check` mode to `install.sh` that probes Quickshell/Qt versions.

---

## 9. Scope and limitations

- The analysis is static. Quickshell/Qt behaviour (notification replacement events, `PwNode.audio` availability, `expireTimeout` units, PanelWindow struts under xfwm4 4.20) should be confirmed on a live session.
- QML was not linted (no `qmllint` available); syntax of QML cannot be asserted beyond careful reading. The README states testing with Quickshell 0.3.2 / Qt 6.8.2 / xfwm4 4.20.
- Line numbers and counts come from the supplied archive as-is.
