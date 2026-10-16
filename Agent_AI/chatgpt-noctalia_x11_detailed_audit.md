# Noctalia X11 v5.3.0 port — static source-code audit

**Target:** Quickshell configuration for XFCE/xfwm4 on X11  
**Input:** user-supplied `noctalia-x11.tar.gz`  
**Method:** extracted archive; inspected source, manifests, scripts, configuration, and bundled assets; performed Python compilation, shell syntax checks, pattern-based code inspection and structural inventory. **No GUI runtime, X server, Quickshell instance, real D-Bus session, or external dependency test was performed.** Findings about behavior are source-based and must not be confused with successful runtime verification.

## Executive assessment

The archive contains a substantial **reimplementation** of Noctalia-like functionality using Quickshell QML, rather than a binary conversion of the original Wayland application. It uses an X11/EWMH bridge for workspaces, windows, keyboard indicators and idle data; integrates XFCE through `xfconf-query`; and supplies separate services, panels, widgets, configuration, translations, and IPC. This is a credible architectural approach for xfwm4, but **feature completeness, API compatibility, and stable operation remain unverified**. In particular, configuration commands and privileged desktop interactions warrant controlled testing.

### Prioritized findings

| ID | Priority | Evidence | Finding / impact | Recommendation |
|---|---|---|---|---|
| F-01 | **High** | `Services/Clipboard.qml` lines 10–15, 100–118 | Clipboard history is enabled by default and written to a persistent JSON file; copied passwords, tokens, and private text can be retained on disk. | Disable history by default for privacy-focused deployments, or implement exclusion/expiration, permissions and optional encryption. |
| F-02 | **High** | `scripts/xfce-setup.sh` lines 51–62, 77–82 | Notification setup masks/stops XFCE's daemon and writes an autostart override; revert removes the override without preserving a pre-existing file. | Backup/restore original XFCE state, verify D-Bus ownership and handle partial failure. |
| F-03 | **High** | `install.sh` lines 84–90, 35–40 | Installer removes any existing destination directory or symlink without backup; uninstall also removes fixed-path installed items, even if subsequently replaced by user content. | Use guarded ownership checks and timestamped backups; offer a dry run. |
| F-04 | **Medium–High** | `Services/Commands.qml` lines 85–89; `Services/Hooks.qml` lines 11–21 | Command vocabulary includes arbitrary `exec` and configurable shell hooks. This is expected power-user functionality but makes config and IPC trust boundaries important. | Treat configuration and local IPC access as privileged; document threat model and avoid passing untrusted text to shells. |
| F-05 | **Medium** | `Services/Commands.qml` lines 68–78 | Settings command embeds config paths in single-quoted shell literals without escaping single quotes. An unusual but valid path containing `'` can break the command and potentially alter execution. | Pass paths as process arguments or use a rigorous shell-quote helper. |
| F-06 | **Medium** | `Services/Network.qml` lines 73–82 | Wi-Fi password is placed in `nmcli` process arguments. Command-line secrets can be exposed to local process inspection, depending on OS configuration. | Use `nmcli --ask`, D-Bus secret agents, or stdin-based mechanisms where supported. |
| F-07 | **Medium** | `Services/Wallpaper.qml` lines 140–150 | XFCE wallpaper command assembles a shell script with monitor identifiers; quoting assumptions should be validated with special characters and multi-monitor naming. | Prefer argv-based `xfconf-query` calls and validate monitor identifiers. |
| F-08 | **Medium** | `Services/Idle.qml` lines 115–133 | Caffeine changes XFCE presentation mode and launches an inhibitor process; original user settings may be overwritten, and process lifecycle should be tested across crashes. | Snapshot/restore pre-existing state and add lifecycle tests. |
| F-09 | **Medium** | `Services/Notifications.qml` and `scripts/xfce-setup.sh` | Replacement notification service is a session-wide singleton D-Bus role; coexistence with xfce4-notifyd cannot be assumed. | Test service ownership, restart, action handling, DND, and fallback. |
| F-10 | **Medium** | `Commons/Toml.js` | Custom TOML parser claims broad TOML support but is not verified against TOML 1.0 conformance tests. | Run a TOML conformance suite, especially nested arrays/tables, Unicode, date/time and invalid inputs. |
| F-11 | **Medium** | `Services/SystemMonitor.qml` lines 175–216 | Several independent timers sample system data; on low-end hardware this may have a noticeable CPU/wake-up cost. | Measure idle CPU and wake-ups; throttle or pause when widgets/panels are hidden. |
| F-12 | **Medium** | `Services/X11.qml` and `scripts/x11-bridge.py` | A ctypes/Xlib bridge creates a native-process boundary with event and memory-handling complexity; error suppression can conceal failures. | Exercise X errors, client disappearance, WM restart, monitor hotplug, invalid window IDs and bridge restart. |

**Scope note:** Priorities are engineering triage estimates, not CVSS scores. None of these observations alone proves an exploitable vulnerability.

## Architecture and operational model

`ShellRoot` in `shell.qml` initializes lazy service singletons, instantiates bars, panel hosts, notification toasts and OSD per Quickshell screen, conditionally starts docks, and exports IPC. `Commons/Config.qml` and `Commons/Defaults.js` supply runtime configuration; `Commons/Toml.js` parses the TOML input; `Commons/ShellState.qml` persists runtime state. `Services/*` encapsulate OS interfaces and user actions. `Modules/*` render user-facing surfaces. `Widgets/*` provide reusable visual components. `scripts/x11-bridge.py` bridges EWMH/XKB/XScreenSaver to `Services/X11.qml` over newline-delimited JSON; `bin/noctalia-msg` routes user commands to Quickshell IPC.

**Important distinction:** X11 desktop protocols do not provide Wayland's isolation guarantees. An X11 shell with clipboard access, window enumeration and command execution is inherently powerful within the user's X session. This is not an independent sandbox or security boundary.

## Verification performed

- Python AST syntax: `scripts/x11-bridge.py` — **PASS**.
- Shell syntax: `bin/noctalia-msg` — **PASS**.
- Shell syntax: `install.sh` — **PASS**.
- Shell syntax: `scripts/xfce-setup.sh` — **PASS**.
- Inventory: **148 regular files**, **106 inspected text/code/documentation files**, **42 additional assets/licenses/screenshots/translations**.
- Checksums: SHA-256 archive `705c85764e2a78ad3b07447da5e657f3aafb677ca4fffeb9d58f9fb6f656557b`.
- No live Quickshell, Qt QML lint, integration test or actual window-manager execution was available; QML imports, binding validity, visual alignment and APIs are **not confirmed**.

## File-by-file inspection

Each entry identifies its role, implementation evidence and a targeted validation concern. **“Review” is not a confirmed bug.** Line counts refer to the extracted archive.

### core (7 files)

- **`LICENSE`** — 22 lines, 1,184 bytes. Project LICENSE metadata or helper; check packaging and accuracy.
- **`LICENSE.noctalia`** — 21 lines, 1,069 bytes. Project LICENSE.noctalia metadata or helper; check packaging and accuracy.
- **`README.md`** — 240 lines, 14,507 bytes. Claims, dependencies and setup; verify against actual behavior rather than treating as test evidence.
- **`config.example.toml`** — 299 lines, 11,534 bytes. Documented settings and default examples; compare keys/types against Defaults.js and consumers.
- **`install.sh`** — 129 lines, 5,044 bytes. Copies/removes installation tree and autostart; verify safe upgrades and uninstallation.
- **`noctalia-x11.desktop`** — 9 lines, 267 bytes. Project noctalia-x11.desktop metadata or helper; check packaging and accuracy.
- **`shell.qml`** — 69 lines, 1,767 bytes. Top-level shell and per-monitor component instantiation; test screen add/remove and lazy singleton activation. *Indicators:* timer×1.

### Commons (11 files)

- **`Commons/Config.qml`** — 213 lines, 7,048 bytes. Configuration loading, fallback paths, change detection and `get()` access; verify hot reload and malformed-file recovery. *Indicators:* file I/O×2.
- **`Commons/Defaults.js`** — 363 lines, 10,743 bytes. Shared **Defaults** configuration/theme/helper logic; verify missing values, type conversion and consistency.
- **`Commons/GlyphAliases.js`** — 85 lines, 2,681 bytes. Shared **GlyphAliases** configuration/theme/helper logic; verify missing values, type conversion and consistency.
- **`Commons/I18n.qml`** — 100 lines, 3,184 bytes. Shared **I18n** configuration/theme/helper logic; verify missing values, type conversion and consistency. *Indicators:* file I/O×2.
- **`Commons/Icons.qml`** — 64 lines, 2,196 bytes. Shared **Icons** configuration/theme/helper logic; verify missing values, type conversion and consistency. *Indicators:* file I/O×1.
- **`Commons/Palettes.js`** — 387 lines, 10,329 bytes. Shared **Palettes** configuration/theme/helper logic; verify missing values, type conversion and consistency.
- **`Commons/ShellState.qml`** — 83 lines, 2,140 bytes. Persistent runtime JSON state; check file permissions, atomic updates and concurrent writes. *Indicators:* process×1, timer×1, file I/O×1.
- **`Commons/Style.qml`** — 90 lines, 3,467 bytes. Shared **Style** configuration/theme/helper logic; verify missing values, type conversion and consistency.
- **`Commons/Theme.qml`** — 211 lines, 8,852 bytes. Shared **Theme** configuration/theme/helper logic; verify missing values, type conversion and consistency.
- **`Commons/Toml.js`** — 485 lines, 15,042 bytes. Handwritten TOML lexer/parser; test full TOML 1.0 corpus and malformed inputs.
- **`Commons/Util.js`** — 423 lines, 15,194 bytes. Shared **Util** configuration/theme/helper logic; verify missing values, type conversion and consistency.

### Services (21 files)

- **`Services/Apps.qml`** — 83 lines, 2,994 bytes. **Apps** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* exec/shell×1, signals×1.
- **`Services/Audio.qml`** — 122 lines, 4,034 bytes. **Audio** service adapter; verify startup, command failures, refresh and backend availability.
- **`Services/BluetoothService.qml`** — 71 lines, 2,456 bytes. **BluetoothService** service adapter; verify startup, command failures, refresh and backend availability.
- **`Services/Brightness.qml`** — 103 lines, 3,041 bytes. **Brightness** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* exec/shell×1, process×2, timer×2, file I/O×1.
- **`Services/Clipboard.qml`** — 125 lines, 3,521 bytes. Tracks clipboard text and saves history in `clipboard.json`; assess sensitive data retention. *Indicators:* exec/shell×1, timer×2, file I/O×1.
- **`Services/Commands.qml`** — 391 lines, 17,298 bytes. Central IPC command interpreter; inspect arbitrary shell execution and error reporting. *Indicators:* exec/shell×7.
- **`Services/Hooks.qml`** — 27 lines, 769 bytes. Configurable shell hooks and environment prefix; validate event names, escaping and execution trust. *Indicators:* exec/shell×1.
- **`Services/Idle.qml`** — 136 lines, 4,381 bytes. Idle callbacks, XFCE presentation mode, systemd inhibitor; verify original-setting restoration. *Indicators:* exec/shell×8, process×2, signals×1.
- **`Services/Media.qml`** — 108 lines, 3,345 bytes. **Media** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* timer×1, signals×1.
- **`Services/Network.qml`** — 272 lines, 9,314 bytes. NetworkManager CLI polling/monitoring and Wi-Fi connect; check passwords in argv and SSID parsing. *Indicators:* exec/shell×5, process×4, timer×3.
- **`Services/NightLight.qml`** — 132 lines, 4,625 bytes. **NightLight** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* exec/shell×2, process×1, timer×1, signals×1.
- **`Services/Notifications.qml`** — 303 lines, 9,772 bytes. D-Bus notifications ownership, toast/history/action management; check daemon conflict and cleanup. *Indicators:* timer×1, file I/O×1.
- **`Services/Osd.qml`** — 50 lines, 1,320 bytes. **Osd** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* timer×1.
- **`Services/Panels.qml`** — 116 lines, 3,715 bytes. **Panels** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* timer×1, signals×1.
- **`Services/Power.qml`** — 129 lines, 4,948 bytes. **Power** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* exec/shell×1, process×1.
- **`Services/Session.qml`** — 179 lines, 6,152 bytes. Lock/logout/reboot/suspend actions; test lock-before-suspend race and logout command fallbacks. *Indicators:* exec/shell×2, process×1, timer×1.
- **`Services/SystemMonitor.qml`** — 219 lines, 7,470 bytes. Samples /proc, /sys and df; measure polling overhead and missing hardware sensors. *Indicators:* exec/shell×1, process×2, timer×5, file I/O×6.
- **`Services/ThemeControl.qml`** — 94 lines, 3,089 bytes. **ThemeControl** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* exec/shell×2, timer×1, signals×3.
- **`Services/Wallpaper.qml`** — 263 lines, 10,404 bytes. XFCE/other wallpaper backends and file discovery; test quoting, multi-monitor mapping and xfdesktop workspace keys. *Indicators:* exec/shell×3, process×2, timer×1.
- **`Services/Weather.qml`** — 226 lines, 9,344 bytes. **Weather** service adapter; verify startup, command failures, refresh and backend availability. *Indicators:* timer×1.
- **`Services/X11.qml`** — 233 lines, 6,913 bytes. Manages JSON-lines bridge process and state; verify restart, malformed messages and EWMH state synchronization. *Indicators:* process×1, timer×1.

### Modules (52 files)

- **`Modules/Bar/Bar.qml`** — 233 lines, 9,591 bytes. **Bar** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* timer×3, signals×2, X11 panel×1.
- **`Modules/Bar/BarSection.qml`** — 26 lines, 775 bytes. **BarSection** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/Bar/BarWidget.qml`** — 165 lines, 7,342 bytes. **BarWidget** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/Bar/BarWidgetLoader.qml`** — 71 lines, 2,316 bytes. **BarWidgetLoader** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/Bar/Widgets/ActiveWindow.qml`** — 47 lines, 1,780 bytes. Bar widget for **ActiveWindow**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Battery.qml`** — 75 lines, 3,320 bytes. Bar widget for **Battery**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Bluetooth.qml`** — 37 lines, 1,597 bytes. Bar widget for **Bluetooth**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Brightness.qml`** — 35 lines, 1,173 bytes. Bar widget for **Brightness**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Clock.qml`** — 37 lines, 1,144 bytes. Bar widget for **Clock**; check live service state, click/scroll actions, availability fallback and visual scaling. *Indicators:* timer×1.
- **`Modules/Bar/Widgets/GlyphButton.qml`** — 130 lines, 4,667 bytes. Bar widget for **GlyphButton**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/KeyboardLayout.qml`** — 49 lines, 1,508 bytes. Bar widget for **KeyboardLayout**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/LockKeys.qml`** — 59 lines, 1,929 bytes. Bar widget for **LockKeys**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Media.qml`** — 120 lines, 4,719 bytes. Bar widget for **Media**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Network.qml`** — 53 lines, 2,081 bytes. Bar widget for **Network**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/NotificationsButton.qml`** — 43 lines, 1,399 bytes. Bar widget for **NotificationsButton**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Spacer.qml`** — 17 lines, 495 bytes. Bar widget for **Spacer**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Sysmon.qml`** — 160 lines, 5,718 bytes. Bar widget for **Sysmon**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Taskbar.qml`** — 143 lines, 6,631 bytes. Bar widget for **Taskbar**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/TextWidget.qml`** — 16 lines, 340 bytes. Bar widget for **TextWidget**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/ToggleButton.qml`** — 77 lines, 2,521 bytes. Bar widget for **ToggleButton**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Tray.qml`** — 82 lines, 3,090 bytes. Bar widget for **Tray**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Volume.qml`** — 47 lines, 2,005 bytes. Bar widget for **Volume**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/WeatherWidget.qml`** — 41 lines, 1,634 bytes. Bar widget for **WeatherWidget**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/Bar/Widgets/Workspaces.qml`** — 137 lines, 6,493 bytes. Bar widget for **Workspaces**; check live service state, click/scroll actions, availability fallback and visual scaling.
- **`Modules/ClipboardPanel/ClipboardPanel.qml`** — 168 lines, 6,571 bytes. **ClipboardPanel** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/ControlCenter/AudioTab.qml`** — 202 lines, 8,022 bytes. Control Center **AudioTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/BluetoothTab.qml`** — 111 lines, 4,508 bytes. Control Center **BluetoothTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/CalendarTab.qml`** — 140 lines, 5,684 bytes. Control Center **CalendarTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/ControlCenterPanel.qml`** — 257 lines, 9,437 bytes. Control Center **ControlCenterPanel** component; check bindings, user interaction, keyboard navigation and absent-backend fallback. *Indicators:* signals×1.
- **`Modules/ControlCenter/HomeTab.qml`** — 350 lines, 13,410 bytes. Control Center **HomeTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback. *Indicators:* exec/shell×1, process×1, timer×1.
- **`Modules/ControlCenter/ListRow.qml`** — 72 lines, 2,175 bytes. Control Center **ListRow** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/MediaTab.qml`** — 145 lines, 5,692 bytes. Control Center **MediaTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/MonitorTab.qml`** — 123 lines, 4,913 bytes. Control Center **MonitorTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/NetworkTab.qml`** — 199 lines, 8,121 bytes. Control Center **NetworkTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/NotificationsTab.qml`** — 84 lines, 2,756 bytes. Control Center **NotificationsTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/PowerTab.qml`** — 111 lines, 4,662 bytes. Control Center **PowerTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/SectionLabel.qml`** — 11 lines, 221 bytes. Control Center **SectionLabel** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/ShortcutTile.qml`** — 159 lines, 6,094 bytes. Control Center **ShortcutTile** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/ControlCenter/SystemTab.qml`** — 177 lines, 6,345 bytes. Control Center **SystemTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback. *Indicators:* exec/shell×1, process×1.
- **`Modules/ControlCenter/WeatherTab.qml`** — 104 lines, 4,174 bytes. Control Center **WeatherTab** component; check bindings, user interaction, keyboard navigation and absent-backend fallback.
- **`Modules/Dock/Dock.qml`** — 235 lines, 10,799 bytes. **Dock** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* timer×1, X11 panel×1.
- **`Modules/Ipc/Ipc.qml`** — 62 lines, 1,368 bytes. **Ipc** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/Launcher/LauncherPanel.qml`** — 778 lines, 34,373 bytes. **LauncherPanel** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* file I/O×1.
- **`Modules/Notifications/NotificationCard.qml`** — 244 lines, 8,880 bytes. **NotificationCard** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* timer×2.
- **`Modules/Notifications/Toasts.qml`** — 108 lines, 3,899 bytes. **Toasts** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* X11 panel×1.
- **`Modules/Osd/OsdTriggers.qml`** — 121 lines, 4,756 bytes. **OsdTriggers** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* timer×1, signals×9.
- **`Modules/Osd/OsdWindow.qml`** — 178 lines, 6,364 bytes. **OsdWindow** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* signals×1, X11 panel×1.
- **`Modules/Panels/PanelFrame.qml`** — 72 lines, 3,223 bytes. **PanelFrame** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/Panels/PanelHost.qml`** — 352 lines, 13,533 bytes. **PanelHost** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* timer×1, signals×2, X11 panel×1.
- **`Modules/Session/SessionPanel.qml`** — 170 lines, 6,655 bytes. **SessionPanel** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/TrayMenu/TrayMenuPanel.qml`** — 146 lines, 5,785 bytes. **TrayMenuPanel** interface component; test panel focus, visibility, screen placement and cleanup.
- **`Modules/WallpaperPicker/WallpaperPanel.qml`** — 200 lines, 7,998 bytes. **WallpaperPanel** interface component; test panel focus, visibility, screen placement and cleanup. *Indicators:* exec/shell×1.

### Widgets (14 files)

- **`Widgets/NAppIcon.qml`** — 33 lines, 859 bytes. Reusable **NAppIcon** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NButton.qml`** — 123 lines, 4,809 bytes. Reusable **NButton** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NCard.qml`** — 13 lines, 360 bytes. Reusable **NCard** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NDivider.qml`** — 9 lines, 230 bytes. Reusable **NDivider** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NGraph.qml`** — 55 lines, 1,704 bytes. Reusable **NGraph** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NIcon.qml`** — 23 lines, 549 bytes. Reusable **NIcon** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NIconButton.qml`** — 16 lines, 364 bytes. Reusable **NIconButton** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NRoundedImage.qml`** — 38 lines, 994 bytes. Reusable **NRoundedImage** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NScrollBar.qml`** — 65 lines, 2,141 bytes. Reusable **NScrollBar** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NSlider.qml`** — 100 lines, 3,041 bytes. Reusable **NSlider** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NText.qml`** — 23 lines, 538 bytes. Reusable **NText** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NTextField.qml`** — 75 lines, 2,559 bytes. Reusable **NTextField** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NToggle.qml`** — 61 lines, 1,745 bytes. Reusable **NToggle** visual control; test accessibility, focus, scaling and theming.
- **`Widgets/NTooltip.qml`** — 59 lines, 1,705 bytes. Reusable **NTooltip** visual control; test accessibility, focus, scaling and theming.

### scripts (2 files)

- **`scripts/x11-bridge.py`** — 736 lines, 31,956 bytes. ctypes Xlib/EWMH/XKB/Xss backend; exercise native event types, errors, hotplug and command parsing.
- **`scripts/xfce-setup.sh`** — 97 lines, 4,167 bytes. Modifies XFCE shortcuts, notifications and compositor; test backup/revert idempotence.

### bin (1 files)

- **`bin/noctalia-msg`** — 32 lines, 1,049 bytes. CLI wrapper to Quickshell IPC; test argument quoting, spaces and exit codes.

### assets (33 files)

- **`assets/emoji.json`** — 11481 lines, 208,623 bytes. JSON data asset; valid JSON (1913 top-level entries); validate references and size.
- **`assets/fonts/noctalia-tabler.ttf`** — 0 lines, 2,413,312 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`assets/fonts/tabler-icons-license.txt`** — 21 lines, 1,072 bytes. Bundled asset/license; verify provenance and packaging.
- **`assets/fonts/tabler.json`** — 23834 lines, 481,192 bytes. JSON data asset; valid JSON (5958 top-level entries); validate references and size.
- **`assets/noctalia-wallpaper.png`** — 0 lines, 5,387,815 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`assets/noctalia.svg`** — 65 lines, 6,977 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`assets/translations/ar.json`** — 4275 lines, 207,792 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/be-Latn.json`** — 43 lines, 1,804 bytes. Translation catalog; valid JSON, 2 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/be.json`** — 2328 lines, 106,753 bytes. Translation catalog; valid JSON, 24 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/ca.json`** — 4113 lines, 178,033 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/cs.json`** — 3397 lines, 135,004 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/de.json`** — 4149 lines, 177,221 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/en.json`** — 5146 lines, 203,989 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/es.json`** — 4982 lines, 223,997 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/fr.json`** — 3504 lines, 145,972 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/gl-ES.json`** — 3534 lines, 144,667 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/he.json`** — 4149 lines, 194,445 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/hu.json`** — 3884 lines, 169,069 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/it.json`** — 5113 lines, 223,172 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/ja.json`** — 3783 lines, 179,093 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/ko.json`** — 4249 lines, 177,614 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/ku.json`** — 1245 lines, 33,278 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/nl.json`** — 3058 lines, 113,976 bytes. Translation catalog; valid JSON, 25 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/nn.json`** — 4109 lines, 161,457 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/pl.json`** — 2969 lines, 113,329 bytes. Translation catalog; valid JSON, 25 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/pt-BR.json`** — 5113 lines, 224,978 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/ru.json`** — 4967 lines, 289,874 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/sv.json`** — 1080 lines, 33,183 bytes. Translation catalog; valid JSON, 20 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/tr.json`** — 4150 lines, 174,393 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/uk-UA.json`** — 3746 lines, 205,780 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/vi.json`** — 3686 lines, 160,765 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/zh-Hans.json`** — 5020 lines, 194,866 bytes. Translation catalog; valid JSON, 26 top-level keys; verify placeholder and key parity with English.
- **`assets/translations/zh-Hant.json`** — 1151 lines, 39,859 bytes. Translation catalog; valid JSON, 17 top-level keys; verify placeholder and key parity with English.

### docs (7 files)

- **`docs/screenshots/capsule-bar-catppuccin.jpg`** — 0 lines, 15,116 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/control-center.jpg`** — 0 lines, 75,969 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/launcher.jpg`** — 0 lines, 87,401 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/light-vertical-bar.jpg`** — 0 lines, 81,502 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/notifications-osd.jpg`** — 0 lines, 72,153 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/session-menu.jpg`** — 0 lines, 30,138 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.
- **`docs/screenshots/tray-menu.jpg`** — 0 lines, 69,579 bytes. Bundled binary/vector visual asset; inspect licensing, dimensions and runtime load paths.

## Focused integration and security observations

### XFCE/xfwm4

The approach relies on xfwm4 exposing standard EWMH window/workspace properties. Validate `_NET_SUPPORTED`, `_NET_CLIENT_LIST`, `_NET_ACTIVE_WINDOW`, `_NET_NUMBER_OF_DESKTOPS`, `_NET_CURRENT_DESKTOP`, `_NET_WM_DESKTOP`, `_NET_WM_STATE`, `_NET_WM_STRUT_PARTIAL` and panel focus behavior against the actual xfwm4 version. Test multiple monitors, fullscreen apps, desktop switching, panels on all edges, and hotplug. EWMH compatibility is a contract with the window manager, not an unconditional guarantee.

### Privacy and persistence

Audit the actual paths and permissions of config, state and cache. Clipboard content is more sensitive than normal UI state. Notification history may contain one-time codes or message previews. Do not assume `atomicWrites: true` implies encryption or restrictive access permissions. Verify whether history survives logout, crash and uninstall; supply explicit deletion controls and retention policy.

### Reliability and performance

Test startup with missing `nmcli`, `wpctl`, `brightnessctl`, BlueZ, UPower, libXss and XFCE-specific programs; ensure the shell degrades gracefully. Verify every QML singleton resolves, the bundled icon font loads, translations resolve, and timers stop when unnecessary. On a 4 GB RAM system, measure resident memory, CPU and process count with shell idle, panel open and multiple monitors.

### Tests to add (ordered)

1. **Static CI:** `bash -n`, `sh -n`, Python AST/ruff, ShellCheck, QML formatting/lint and JSON validity.
2. **Config:** TOML conformance corpus, valid/invalid config, hot reload, backward compatibility and per-monitor overrides.
3. **Bridge:** Xvfb + lightweight EWMH WM; create/rename/close/minimize windows, workspace transitions, keyboard group changes, X server disconnect and restart.
4. **Session D-Bus:** notification daemon ownership/action replies, Media/UPower/BlueZ interactions, missing-service recovery.
5. **XFCE safety:** fixture-based test for install, upgrade, uninstall, setup and revert, preserving pre-existing shortcuts and autostart files.
6. **Security:** paths containing quotes/spaces, adversarial window titles/SSIDs, clipboard secrets, malformed bridge JSON and IPC `exec` policy.
7. **GUI:** dual monitors, mixed DPI, bar struts, fullscreen windows, panel focus, pointer escape, keyboard accessibility, notification OSD overlap.
8. **Resource regression:** idle CPU/RSS, subprocess churn, battery impact and wake-ups over 30–60 minutes.

## Practical deployment recommendation

**Do not run `xfce-setup.sh --all` or replace the existing XFCE notification daemon immediately.** First use `./install.sh --no-autostart` only after backing up any existing Quickshell destination, inspect the generated config, and launch manually in a disposable X11 session. Begin with the bar and launcher, then enable notification takeover, clipboard persistence, wallpaper automation and XFCE integration individually. Keep the original xfce4-panel and notification configuration recoverable until behavior has been validated.

## Evidence limitations and conclusion

This report provides a per-file inventory and targeted source-level review, with concrete high-priority observations. It is **not** a claim that every code path was executed or that all possible semantic bugs were identified. No comparison against the upstream Noctalia v5.3.0 repository was performed, so exact parity with upstream is unverified. The strongest conclusions concern **observable source behavior**: persistent clipboard history, destructive installer replacement, XFCE notification takeover, shell-command surfaces and external command dependencies. A release-quality verdict requires QML lint, X11/xfwm4 runtime testing, automated tests and a review of the live user configuration.
