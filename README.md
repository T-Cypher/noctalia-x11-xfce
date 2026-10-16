# Noctalia X11

A [Quickshell](https://quickshell.org) port of **[noctalia](https://github.com/noctalia-dev/noctalia) v5.3.0**
for **X11** window managers, made for **XFCE / xfwm4**.

![Control Center](docs/screenshots/control-center.jpg)

noctalia v5 is a native C++/Wayland shell. It talks to Wayland compositors (Niri, Hyprland,
Sway, labwc…) through layer-shell, ext-workspace, foreign-toplevel and session-lock protocols,
so it cannot run on X11. This project re-implements its design, defaults, config schema and IPC
vocabulary as a Quickshell (QML) configuration, and replaces every Wayland-only piece with an
X11 equivalent:

| noctalia v5 (Wayland) | Noctalia X11 |
|---|---|
| layer-shell bars and panels | Quickshell `PanelWindow` → X11 dock windows with `_NET_WM_STRUT_PARTIAL` |
| ext-workspace / compositor IPC | EWMH desktops (`_NET_CURRENT_DESKTOP`, …) through `scripts/x11-bridge.py` |
| foreign-toplevel (taskbar, active window, `/win`) | `_NET_CLIENT_LIST`, `_NET_ACTIVE_WINDOW`, `WM_CLASS` from the bridge |
| compositor keyboard-layout IPC, lock keys | XKB group and indicator state from the bridge |
| ext-idle-notify | XScreenSaver idle time from the bridge |
| ext-session-lock lock screen | your XFCE screen locker (`xflock4`; configurable) |
| wlr-gamma night light | redshift / gammastep / sct / `xrandr --gamma` |
| wallpaper surface + transitions | xfdesktop through xfconf (desktop icons keep working), or feh / xwallpaper / hsetroot |
| idle inhibitor | xfce4-power-manager presentation mode + `systemd-inhibit` + `xset` |

The bridge is a small dependency-free Python 3 script (ctypes against libX11). It streams
JSON events and accepts commands, so the shell reacts instantly to workspace and window changes
instead of polling `wmctrl`.

## Features

<table>
<tr><td><img src="docs/screenshots/launcher.jpg" width="420"></td><td><img src="docs/screenshots/notifications-osd.jpg" width="420"></td></tr>
<tr><td><img src="docs/screenshots/light-vertical-bar.jpg" width="420"></td><td><img src="docs/screenshots/tray-menu.jpg" width="420"></td></tr>
</table>

- **Look**
  - The 10 built-in noctalia palettes, generated from the v5.3.0 sources: Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Noctalia, Nord, Rosé Pine and Tokyo-Night.
  - Dark, light and auto (sunset/sunrise) modes, plus wallpaper-derived palettes (`[theme] source = "wallpaper"`).
  - noctalia's style tokens (radii, spacing, typography, control sizes).
  - The bundled noctalia Tabler icon font and its glyph aliases.
  - noctalia's own translation catalogs (27 languages).
- **Bar**
  - Several bars, on any edge (`[bar.<name>]`), with per-monitor overrides.
  - Floating or full-width, with capsule styles, hover highlight, tooltips and auto-hide.
  - `[widget.<name>.actions]` gesture bindings.
  - Widgets: `launcher`, `control-center`, `workspaces` (regular, minimal and focus_hint styles), `taskbar`, `active_window`, `clock`, `media`, `tray`, `notifications`, `clipboard`, `network`, `bluetooth`, `volume`, `brightness`, `battery`, `sysmon`, `keyboard_layout`, `lock_keys`, `caffeine`, `nightlight`, `power_profile`, `theme_mode`, `weather`, `wallpaper`, `screenshot`, `session`, `settings`, `spacer`, `text` and `custom_button`.
- **Panels**
  - Attached panels grow out of the bar with noctalia's concave corners. Floating panels are centred.
  - All panels close on Esc or an outside click, and take keyboard focus through EWMH.
- **Control Center**
  - Tabs: Home (user card, media, clock and weather, six shortcut tiles), Media, Audio (devices, inputs, per-app volume), Monitor (backlight, night light), System (live graphs), Network (Wi-Fi via NetworkManager), Bluetooth (BlueZ), Weather (open-meteo), Calendar, Notifications and Power.
- **Launcher**
  - The "full" layout (Recent, Pinned, All, Categories, Providers), or the "simple" layout.
  - Fuzzy search with usage boosting, pinning (right-click), and list or grid view.
  - Providers: calculator (global), `/emo`, `/win`, `/session`, `/wall` and `/pan`.
- **Other surfaces**
  - Session menu: lock, log out, lock & suspend, reboot, shut down and custom entries, with number-key shortcuts and optional countdowns.
  - Notifications daemon: toasts, actions, history, Do Not Disturb and filters.
  - OSD for volume, brightness, toggles, keyboard layout and lock keys.
  - Clipboard history with pinning and auto-paste.
  - Wallpaper picker with per-monitor support, random/next and automation.
  - Dock: pinned and running apps, magnification, auto-hide.
- **Plumbing**
  - TOML config compatible with noctalia's schema, with hot reload.
  - `[hooks]` for shell events.
  - The noctalia IPC command set through `noctalia-msg`.

## Requirements

- **Quickshell ≥ 0.2.0**, built with X11 support (on by default), and **Qt ≥ 6.7**. Tested with Quickshell 0.3.2 and Qt 6.8.2 under xfwm4 4.20.
- **python3** (for the X11 bridge; standard library only) and libX11. libXss is optional and provides idle detection.
- **An X11 compositor for transparency and rounded corners.** xfwm4's built-in compositor is on by default.
- **Optional:**

  | Tool | Used for |
  |---|---|
  | NetworkManager (`nmcli`) | network widget and Wi-Fi panel |
  | PipeWire | volume widgets and the Audio tab |
  | BlueZ | Bluetooth |
  | UPower and power-profiles-daemon | battery and power profiles |
  | `brightnessctl` | backlight |
  | `xfconf-query` | XFCE integration |
  | `xdotool` | auto-paste |
  | redshift, gammastep, sct or xrandr | night light |
  | xfce4-screenshooter, flameshot, maim or scrot | screenshots |
  | `snixembed` (or `xembedsniproxy`) | showing old XEmbed-only tray icons |

Distro package hints:

```sh
# Debian/Ubuntu (Quickshell itself: build from source, see below)
sudo apt install python3 network-manager pipewire wireplumber upower power-profiles-daemon \
                 brightnessctl xdotool redshift xfce4-screenshooter fonts-noto-color-emoji
# Arch
sudo pacman -S quickshell python networkmanager pipewire wireplumber upower power-profiles-daemon \
               brightnessctl xdotool redshift
# Fedora
sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell
```

### Installing Quickshell

Prebuilt packages:

- Arch: `quickshell` from the official repos or the AUR.
- Fedora: COPR `errornointernet/quickshell`.
- NixOS: the flake.

Building from source on Debian 13 or Ubuntu 25.04+:

```sh
sudo apt install cmake ninja-build pkg-config qt6-base-dev qt6-base-private-dev \
  qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev qt6-svg-dev spirv-tools \
  libcli11-dev libdrm-dev libxcb1-dev libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev \
  libglib2.0-dev libjemalloc-dev qml6-module-qtquick-shapes qml6-module-qtquick-effects
git clone https://git.outfoxxed.me/quickshell/quickshell && cd quickshell
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DWAYLAND=OFF -DCRASH_HANDLER=OFF
cmake --build build && sudo cmake --install build
```

## Installation

```sh
./install.sh                 # copies into ~/.config/quickshell/noctalia-x11, installs noctalia-msg,
                             # creates ~/.config/noctalia-x11/config.toml and an autostart entry
qs -c noctalia-x11           # start it
```

Use `./install.sh --link` to symlink instead of copying, and `./install.sh --uninstall` to remove
it again. Your config and state are kept.

### XFCE integration

`scripts/xfce-setup.sh` makes the common adjustments. Run it with `--all`, or pick individual steps:

| Option | What it does |
|---|---|
| `--compositor` | Turns on xfwm4 compositing. Without it, transparent areas render black. |
| `--notifications` | Stops and masks **xfce4-notifyd**. Only one notification daemon can own `org.freedesktop.Notifications`, so this is required for Noctalia toasts. |
| `--shortcuts` | Binds <kbd>Super</kbd>+<kbd>Space</kbd> launcher, <kbd>Super</kbd>+<kbd>S</kbd> control center, <kbd>Super</kbd>+<kbd>V</kbd> clipboard, <kbd>Super</kbd>+<kbd>Esc</kbd> session menu and <kbd>Super</kbd>+<kbd>,</kbd> wallpaper picker. |
| `--media-keys` | Sends volume and media keys to Noctalia. Use this if you remove xfce4-panel, because its PulseAudio plugin normally handles those keys. |
| `--hide-panel` | Quits **xfce4-panel** for the current session. To make that permanent, open *Settings → Session and Startup → Current Session*, set xfce4-panel's *Restart Style* to *Never*, then *Save Session*. You can also keep xfce4-panel; Noctalia's bars reserve their own space next to it. |
| `--revert` | Undoes the shortcut, media-key and notifyd changes. |

Other notes:

- **Locking:** the *Lock* action runs `xflock4`, which uses whatever locker XFCE is set to (xfce4-screensaver, light-locker, xscreensaver…). Set `[x11] lock_command` to use another one. An X11 client cannot implement a secure lock screen the way ext-session-lock does, so Noctalia deliberately does not draw its own.
- **Wallpaper:** the picker and `wallpaper-*` commands write xfdesktop's `last-image` keys for every workspace.

## Configuration

Settings come from `~/.config/noctalia-x11/config.toml`, which is hot-reloaded on save.

- If that file does not exist, `~/.config/noctalia/config.toml` (a native noctalia v5 config) is read as-is.
- `$NOCTALIA_X11_CONFIG` points at any other file.

The schema is noctalia's, with `[bar.main]`, `[widget.<name>]`, `[shell.launcher]`, `[notification]` and so on. Unknown keys are ignored. See [`config.example.toml`](config.example.toml) for everything this port reads.

X11-specific settings live in `[x11]`:

| Key | Purpose |
|---|---|
| `lock_command`, `logout_command` | Session commands. Empty means auto-detect. |
| `wallpaper_backend` | `auto`, `xfdesktop`, `feh`, `xwallpaper`, `hsetroot` or `none`. |
| `gtk_theme_dark`, `gtk_theme_light`, `icon_theme_dark`, `icon_theme_light` | Themes to switch through xsettings when the theme mode changes. |
| `terminal` | Terminal for `Terminal=true` apps. |
| `screenshot_region_command`, `screenshot_full_command` | Override the screenshot tools. |
| `focus_method` | How panels take keyboard focus: `bridge` (EWMH `_NET_ACTIVE_WINDOW`) or `qt` (`QWindow.requestActivate`). |

Runtime state lives in `~/.local/state/noctalia-x11/`. It holds DND, caffeine, theme toggles,
wallpapers, launcher usage, clipboard history and notification history.

## IPC

```sh
noctalia-msg panel-toggle launcher            # or: control-center [tab] | session | clipboard | wallpaper
noctalia-msg volume-up 5 | volume-mute | mic-mute | brightness-down 10
noctalia-msg media toggle | media next
noctalia-msg notification-dnd-toggle | notification-clear-history
noctalia-msg wallpaper-random | wallpaper-set ~/Pictures/wall.jpg
noctalia-msg theme-mode-toggle | color-scheme-set builtin Nord
noctalia-msg caffeine-toggle | nightlight-toggle | wifi-toggle | bluetooth-toggle
noctalia-msg session lock | session reboot
noctalia-msg workspace 2 | workspace-next | keyboard-layout-next   # X11 extras
noctalia-msg --help                            # full list
```

`noctalia-msg` wraps `qs -c noctalia-x11 ipc call noctalia msg "<command>"`. The same commands
work in `[widget.<name>.actions]`, `[bar.<name>.dead_zone.actions]` and the Control Center
shortcuts. `exec <cmd>` runs a shell command.

## Layout of this repository

```
shell.qml              entry point (bars, panel hosts, toasts, OSD, dock per screen; IPC)
Commons/               Config (TOML loader + defaults), Theme (palettes), Style, Icons, I18n, State, utils
Services/              X11 (bridge), Audio, Network, Bluetooth, Power, Media, Notifications, Session,
                       Idle, NightLight, Wallpaper, Clipboard, Weather, SystemMonitor, Panels, Commands …
Widgets/               N* controls (buttons, toggles, sliders, cards, text fields, graphs, tooltips)
Modules/Bar/           bar window, widget loader, all bar widgets
Modules/Panels/        per-screen panel host + attached/floating panel frame
Modules/ControlCenter/ Control Center and its tabs
Modules/{Launcher,Session,WallpaperPicker,ClipboardPanel,TrayMenu,Notifications,Osd,Dock,Ipc}/
scripts/x11-bridge.py  EWMH / XKB / XScreenSaver bridge (python3 + ctypes)
scripts/xfce-setup.sh  XFCE integration helper
assets/                noctalia's Tabler icon font + glyph map, translations, emoji data, wallpaper, logo
```

## Not ported (yet)

These parts of noctalia v5.3.0 are not reproduced:

- The settings GUI and setup wizard. The settings buttons open `config.toml`.
- Luau plugins, desktop widgets and lock-screen widgets.
- The Wayland lock screen. Locking is delegated, as described above.
- Wallpaper transition shaders. xfdesktop draws the wallpaper.
- CalDAV/ICS calendar accounts and Screen Time.
- Polkit agent, audio visualizer, privacy indicators and screenshot annotation.
- The window switcher. xfwm4 provides <kbd>Alt</kbd>+<kbd>Tab</kbd>.
- App-theming templates for GTK, Qt and terminals.
- Community palettes. Wallpaper palettes are an HSL approximation of noctalia's Material schemes.
- The calculator has no unit or currency conversion (upstream uses libqalculate).

## Troubleshooting

- **Black boxes around the bar or panels:** enable the compositor (`scripts/xfce-setup.sh --compositor`).
- **No notifications appear:** another daemon owns the bus name. Run `--notifications` and restart Noctalia.
- **Typing in the launcher does nothing:** try `[x11] focus_method = "qt"`. If xfwm4 *Focus stealing prevention* is enabled, keep `bridge`.
- **Tray icons missing:** the tray only shows StatusNotifierItem apps. Run `snixembed` for XEmbed-only apps.
- **No volume widget:** PipeWire (with pipewire-pulse) must be running. `wpctl status` should list your devices.
- **No brightness:** install `brightnessctl` and make sure your user may write the backlight (logind usually allows this).
- **Logs:** run `qs -c noctalia-x11` in a terminal, or use `qs log -c noctalia-x11`.
- **xfwm4 warning "unmanaged net_wm_state … _NET_WM_STATE_STAYS_ON_TOP":** this is harmless. Qt sets that legacy atom alongside `_NET_WM_STATE_ABOVE`, which xfwm4 does honour.

## Credits and licence

- Design, palettes, icon aliases, translations, default wallpaper and logo come from [noctalia](https://github.com/noctalia-dev/noctalia) (MIT, © noctalia-dev). See `LICENSE.noctalia`.
- The icon font is based on [Tabler Icons](https://tabler.io/icons) (MIT, © Paweł Kuna). See `assets/fonts/tabler-icons-license.txt`.
- This port is released under the MIT licence as well.
