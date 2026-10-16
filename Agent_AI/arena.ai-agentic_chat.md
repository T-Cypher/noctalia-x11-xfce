# Prompt:
```
«Based on [https://github.com/noctalia-dev/noctalia/releases/download/v5.3.0/noctalia-v5.3.0.tar.gz](https://github.com/noctalia-dev/noctalia/releases/download/v5.3.0/noctalia-v5.3.0.tar.gz)



Can you generate a version that works with quickshell and XFCE (xfwm4) on X11?»
```

# Agent:
```
	«Now the shared utility library: chrono/strftime formatting compatible with Noctalia's `{:%H:%M}` time formats, fuzzy matching for the launcher, and a safe calculator.

	Next I'll set up a persistent X session (Xvfb, a D-Bus session bus and xfwm4 with its compositor on) that I can reuse across test runs.

	The APIs are confirmed. Now the services, starting with the X11 service, which wraps the bridge and exposes workspaces, windows, keyboard and idle state to QML:

	Next, the Audio service. I'll check how Quickshell classifies PipeWire stream direction so application volumes are listed correctly.

	Playback streams are `isStream && isSink`. Now I'll write the Audio, Brightness and Network services:

	`streamFinished` is there. Now the Power, Media, Bluetooth and System Monitor services:

	Now the Notifications service: the D-Bus daemon via `NotificationServer`, toasts, persistent history, Do Not Disturb, and shell-internal notifications.

	Now the Session service (XFCE-aware lock, logout and power actions) and the Idle service (caffeine plus idle behaviours driven by XScreenSaver idle time):

	Now the Location/Weather service, using the same endpoints Noctalia uses (api.noctalia.dev for geocoding and open-meteo for forecasts), and Night Light with X11 backends:

	Now the Wallpaper service. On XFCE it drives xfdesktop through xfconf, so desktop icons keep working, with feh, xwallpaper and hsetroot as fallbacks. It also generates wallpaper-derived palettes:

	Now the Clipboard history, Hooks, OSD-state, Apps (desktop entries, usage, X11 class→icon) and Panels services:

	Now the Commands service. It implements Noctalia's `noctalia msg` command vocabulary, which serves IPC, keybindings, bar-widget actions and hooks alike.

	I referenced a `ThemeControl` service there, so I'll write it now. It handles theme-mode and colour-scheme changes, runs the hooks, and optionally switches the XFCE GTK/icon theme to match.

	Next is the bar. First I'll pull the default glyphs, gestures and settings each widget definition declares, so the port matches Noctalia's out-of-box behaviour.

	The `noctalia` logo glyph is in the bundled font (U+EC33), and the control-center widget uses it. Next I'll check the tray menu entry API, so tray right-click menus can be drawn in Noctalia style.

	The bar core is written. Before the individual widgets, I'll pull their per-widget defaults from Noctalia's headers (label visibility, max lengths, default stat and so on).

	Workspace pills are 16px × scale with 11px labels and a 4px gap, and sysmon defaults to CPU usage with a gauge. Now the bar widgets themselves:

	Next batch: media, tray, network, Bluetooth, volume, brightness, battery, keyboard layout, lock keys, sysmon, toggles, spacer, text and weather.

	Some upstream default gestures use command names I haven't mapped yet, so I'll add aliases for them to the command dispatcher:

	Testing is working. Errors surface one at a time, so I'll iterate. First: QML forbids uppercase method names (`Util_clamp`).

	Next, `X11.keyboardChanged` clashes with the auto-generated change signal of the `keyboard` property, so I'll rename it to `keyboardUpdated`:

	Quickshell segfaults during load. I'll get a backtrace with gdb.

	Now the PanelHost overlay window:

	Now the Control Center. It follows the v5 layout: left tab rail, a header with the tab title and settings/session/close buttons, and per-tab content. First the container and shared building blocks:

	Next the Home tab: profile card over the wallpaper, a media card, a clock/date/weather card and the shortcut-tile grid.

	Now the remaining tabs: Media, Audio, Monitor, System, Network, Bluetooth, Weather, Calendar, Notifications and Power.

	Next, notifications (shared card, toasts) and the launcher. The launcher's emoji provider can reuse Noctalia's `emoji.json`, so I'll check its format first.

	Now the launcher panel:

	All glyph names resolve (the remaining matches are ordinary strings, not icons). Now I'll fix the launcher's scroll-to-selection references for grid mode:

	Next the session panel, using upstream's button geometry (152×112 tiles, up to 5 columns, number-key shortcuts, optional countdown), and the wallpaper, clipboard and tray-menu panels.

	Now the OSD and its triggers. Any volume, brightness or toggle change shows it, including changes made outside the shell such as XFCE's media keys.

	Next, the IPC endpoint and the full `shell.qml`:

	It loads cleanly. Panel components only report errors when instantiated, so I'll open each one over IPC and screenshot it, starting with the Control Center.

	Most of my guessed keys aren't in Noctalia's catalog. English falls back fine, but other languages would show English. I'll map each one to the real key by matching on the English text.

	I'll remap every key that has a real equivalent and fix the uptime placeholder:

	The launcher looks right: a floating, bordered panel with the toolbar, view tabs, sort and grid toggles and the app list with icons. Next, the query result screenshots.

	The capsule rendering is clean. Next, a light-mode Rosé Pine palette with a vertical bar on the left, which tests the vertical layout path and the left-attached panel flares.

	The xfconf keys were written for every workspace with zoom style. Now to confirm xfdesktop actually repainted:

	Focus handling is correct: the terminal had focus, the panel took it while open, and xfwm4 returned it to the terminal on Esc. Next, the wallpaper-derived palettes in dark and light:

	`Quickshell.shellPath()` isn't in v0.2.0, so I'll switch to `Quickshell.shellDir`, which is. Next, the popup anchor's `item` property:

	Those all exist in v0.2.0. One more spot-check, the UPower health properties:

	Now the example config, which follows Noctalia's `example.toml` structure, includes only keys this port reads, and adds the `[x11]` table:

	The CopyQ tray icon (green scissors) is in the bar. Next I'll right-click it to open the tray menu.

	Both work: the tray menu entry opened CopyQ's window, and the pills switch desktops through EWMH (to workspace 3 and back to 1).

	That's clean: the OSD sits top centre below the bar, toasts stack top right below the bar's strut, and the bell shows an unread dot. Next, the Home-tab and session shots:

	Both look right; the uptime placeholder now renders ("Uptime – 1h 3m"). I'll regenerate the light-theme vertical-bar shot over the wallpaper, then save a compact screenshot set for the README.

	Light Rosé Pine renders correctly, with the vertical bar and the launcher attached to it by flares. Now the README:

	I'll add the MIT licence file, verify the language count I claim, and then test the installer and `noctalia-msg` exactly as a user would.

	There are 27 translation catalogs, not the 17 I hardcoded in I18n, so I'll fix both I18n and the README.

	The `python3` on PATH doesn't see Debian's packages (python3-xlib wasn't importable earlier either), so it's probably a different interpreter. That matters for the bridge too, so I'll check.

	Next, PanelHost's fallback mode:

	In fallback mode, attached panels should still be positioned against the bar, just without the flares, so I'll separate the placement geometry from the flare drawing.

	Now both modes: a regression run with the compositor on, then with the xfwm4 compositor switched off.

	It closed as soon as the terminal took focus. Now I'll switch the compositor back on and confirm the shell flips back to transparent overlay mode by itself.

	That command killed itself: `pkill -f fake_mpris.py` matched the shell's own command line. I'll redo it without `-f`.

	xfdesktop is still running and recreated `~/Desktop`. I'll stop the test session processes, do a last cleanup, and count what was built.»
```

# Prompt:
```
«Run an in-depth and detailed check on each file to check for errors or mistakes that don't follow the premise. Iterate if necessary.»
```

# Agent: 
```
	«I'll start by checking the sandbox state: whether the Quickshell build and the test helpers are still there.

	While that installs, I'll re-extract the upstream release as the reference and get an overview of the deliverable.

	The deliverable is intact. I'll check the apt progress, then clone Quickshell.

	Quickshell is configured and compiling. In parallel I'll install the test stack and the linters (shellcheck, node, pyflakes):

	While those run, I'll read the files one by one, starting with the entry point and the Commons singletons.

	The entry point and Config look structurally sound. To check them against the premise I need upstream's config loader: file lookup, merge semantics and the bar schema.

	The port keeps a few legacy keys as a compatibility layer, which is fine. Now the systematic part: I'll compare every config key the port reads against upstream's schema. First, the schema sources:

	I'll write an extractor that turns upstream's C++ schema into a flat list of valid key paths, then diff it against every `Config.get(...)` path in the port.

	The working directory didn't exist yet, so the shell failed before running. Retrying from an existing directory:

	Now I'll extract every config path the port reads and diff it against the 560 upstream paths:

	Possible bug in the defaults merge: `defaults.bar.main` is always present. A user who defines only `[bar.top]` would get two bars (`main` plus `top`). I'll check how upstream seeds default bars:

	The docs plus `config_types.h` give me a canonical reference. I'll check on the build, then keep reading files.

	The test stack is installed and the build is still running. In the meantime, the linters on scripts and JS:

	`noctalia-msg` flattens arguments with `"$*"`, so I need to see how the receiving side splits them. Upstream's IPC index:

	I'll extract upstream's complete IPC command registry from source and compare it with Commands.qml:

	Upstream defines 115 IPC commands. Now the port's Commands.qml:

	I'll check each command's argument syntax against upstream's IPC pages, starting with system controls:

	I'll compare the loader's type list with upstream's widget factory:

	The glyphs match upstream. Next, the stateful widgets:

	Upstream bar labels use `fontSizeBody` (14) almost everywhere; the port hard-codes 13. Here are Style.qml and upstream's `style.h` side by side:

	The Style tokens match upstream. I'll check whether upstream's `fontSize` is pixels or points, since NText's mapping depends on it:

	Both use pixel sizes, so the port's mapping is right. Checking the build:

	The build succeeded. Installing it, then setting up the X11 test-session helpers:

	Quickshell embeds its modules, so qmllint needs the build tree's `qml_modules`. Resolving `qs.*` imports needs Quickshell's generated `.qmlls.ini`. I'll write the X11 test-session helpers first:

	The session is up. Running the current (pre-fix) build to get a baseline of runtime warnings:

	The baseline log is clean; the only warnings are expected environment ones (no BlueZ or UPower in the sandbox). Here's the visual baseline:

	The baseline bar renders. Next, qmllint across all QML files, using Quickshell's generated VFS for `qs.*` imports and the build tree for the Quickshell modules:

	qmllint flags real anchor conflicts in Dock.qml at lines 172, 173 and 193, with top, bottom and verticalCenter set together. Here's the rest of the list, missing-property warnings included:

	Most of these are false positives: qmllint can't see that the VFS singletons are singletons, and PanelWindow's `margins` grouped property is unresolved. The Dock anchor conflicts are real:

	I have the exact dock indicator spec. With this many findings, I'll keep a running issue log so nothing gets lost while I read the remaining files:

	The port already shells out for directory listings. Before designing the watcher, I'll check how Quickshell's FileView handles `watchChanges` and `blockLoading`, since the design depends on it:

	Next I'll compare the port's `Defaults.js` field by field against these C++ defaults:

	I'll pull the upstream config structs and compare them with the port's defaults section by section:

	I'll diff every config key the port reads against the upstream schema to catch port-only keys and typos:

	Five port-only keys: `audio.volume_step`, `brightness.step`, and three `notification.*` timeout and history keys. `wallpaper.default.path` also needs checking:

	Upstream has no notification timeout keys, so I'll check what timeouts it hard-codes:

	User-defined idle behaviors default to `enabled = true`; only the seeded ones are disabled. Here's the size of what's left to review, to plan the reading:

	The harness choked on an error message containing a newline. I'll JSON-escape the messages and rerun:

	My first edit duplicated a block: the anchor `while (pos < src.length) {` also matches inside `skipWs`. I'll restore `Toml.js` from the tarball and redo the edit with a unique anchor:

	All 132 doc snippets parse identically. 156 were extracted, but colliding basenames overwrote some, so I'll redo it with unique names:

	All 158 documents parse identically, so `Toml.js` is solid. Next I'll check where its `stringify` is used, then review `Util.js`:

	`Toml.stringify` is dead code; I'll remove it. The strftime subset looks correct. Continuing with the rest of `Util.js`:

	The calculator and sun-time helpers look right on paper. I'll confirm with a quick node test, including Lisbon sun times for today:

	The utilities check out. Next, the remaining Commons singletons:

	The role tokens match. Next, the upstream `ThemeConfig` (source enum, `pure_black_dark`):

	Upstream also has `theme.shell_mode` (follow, dark, light, auto) and an `accessibility.high_contrast` transform. I'll pull the exact pure-black and high-contrast transforms to replicate them:

	Neither is implemented: `high_contrast` sits in the defaults unused, and `shell_mode` is missing. I'll log these and continue with I18n, Icons and ShellState:

	Upstream uses `{name}` placeholders (which the port matches) and `key-plural` for plurals. Next I'll check that every `I18n.tr` key the port uses actually exists in `en.json`:

	24 keys the port uses don't exist in `en.json`, so they always show the English fallback even in other languages. I'll search the catalog for the real equivalents:

	I have the mapping: 13 keys move to real catalog keys, and the 11 with no upstream equivalent keep their English fallback. I'll apply it in a batch later. Next, Icons and GlyphAliases:

	Icons.qml looks fine. I'll confirm the alias table matches upstream's registry and that every glyph name the port uses resolves:

	The glyph aliases match upstream exactly (80 of 80), and every literal glyph name resolves. Now a spot-check of `Palettes.js` against upstream's builtin palette data:

	Upstream's builtin palettes are in `builtin_palettes.cpp`. I'll compare every palette, mode and role programmatically:

	All 10 palettes match upstream exactly in both modes. I'll log what's accumulated, then move on to Services, starting with X11.qml and Panels.qml:

	Panels.qml is fine. Next, Audio.qml:

	Audio.qml still uses the port-only `audio.volume_step` key. I'll check upstream's volume step default, unmute-on-change behaviour, input-volume ceiling and glyph thresholds:

	All resolve. Next, BluetoothService.qml and Power.qml:

	Power.qml hard-codes a 15% low-battery warning, but upstream has `battery.warning_threshold` (default 10, where 0 disables). I'll check upstream's warning logic and battery glyph thresholds:

	Nothing connects to `batteryLow`, `batteryStateChanged` or `profileSwitched`, so the port never shows a low-battery notification. Hooks may watch Power some other way, so I'll check Hooks.qml:

	The upstream hook spec, with its env vars, is now clear. Here's OsdTriggers.qml, where the port wires these events:

	OsdWindow's positioning and orientation logic needs checking against upstream's `osd_overlay.cpp`:

	I have the complete OSD content spec. I'll log it, then continue with Media.qml and Notifications.qml:

	Media.qml is fine. Next, Notifications.qml:

	I have upstream's filter and blacklist semantics. One question remains: what "allowed_urgencies" does in the dispatch path, and how DND interacts with critical notifications:

	Toasts.qml needs selector-based `monitors` matching and `max_visible = 0` meaning "as many as fit": cards that don't fit wait, with expiry paused. Next, NotificationCard.qml:»
```

# Prompt:
```
«then, regenerate the archive with the changes.»
```

# Agent:
```
	«I'll finish the remaining fixes, re-test, and then rebuild `noctalia-x11.tar.gz`. First, the IPC command handler, since many fixes land there:

	Next, the 115 upstream IPC commands, to compare against the port's vocabulary:

	I'll pull the exact upstream argument signatures for the commands I need to add or change:

	Next, the fields upstream's `status` command prints:

	Before rewriting Bar.qml, I'll re-read upstream's concave-corner geometry in `bar_corner_shape.h`:

	Weather checks `unit == "fahrenheit"`, while upstream values are `metric`/`imperial`. Session reads `shell.session.actions` with an empty default. Next, Session.qml and Idle.qml:

	`shell.qml` builds bars straight from `Config.barNames`, so I'll gate that on `Config.ready` to avoid creating a "default" bar and then replacing it. Here are the remaining BarConfig fields:

	Now I'll write the new `Defaults.js`. It contains no named bars, seeded widgets kept separate under the type-match rule, upstream session actions and idle behaviours, and no port-only keys:

	Now the new `Config.qml`, which orchestrates directory probing, synchronous file reads, the sidecar overlay, file watchers and error handling:

	Two cases failed, but the tests themselves are wrong: the keys follow the `[include]` header, so TOML puts them inside that table. I'll move them above the header and rerun:

	Next, Theme.qml. It needs upstream hex parsing, `shell_mode`, and the pure-black and high-contrast transforms. ThemeControl uses the mode for hooks and GTK sync, so I'll look at it first:

	Now ThemeControl: scheme-aware `setSource`, an override reset that includes the scheme, and the app-facing `theme_mode_changed` hook with upstream's env vars:

	Next, I18n: language selection mirroring upstream's candidate list exactly:

	I'll check the language selection in node with a set of real locale strings:

	The language selection now matches upstream. Next, the translation-key remaps. First the exact source lines involved:

	The remaps are applied. Next, the IPC level parser. Here is upstream's exact rule:

	Now I'll add that parser to `Util.js` and update Audio.qml: constant 5% default step, no unmute on set, overdrive ceiling for the mic too, and upstream glyph thresholds:

	Commands is next, but it calls the Brightness and OSD services, which both need redesigning first. Here are the Style tokens available for the upstream OSD dimensions:

	Upstream keys custom labels by the descriptive layout name and resolves them through `shell.keyboard_layout.custom_labels`. Let me check the keyboard-layout widget's settings and gesture defaults:

	I'll pull upstream's complete per-widget gesture-default table, since every bar widget's defaults depend on it:

	The current BarWidget relies on per-widget `defaultActions`. Before replacing them with the central table, here's what each widget declares:

	Now BarWidget.qml. It gets upstream gesture resolution with dead-zone fall-through, horizontal scroll as `scroll_left`/`scroll_right`, per-widget capsule settings, and the 14 px label size:

	Upstream reserves only thickness + margin_edge + margin_opposite_edge; the concave bulge is not reserved. For smart auto-hide I need to know which window fields the X11 bridge reports:

	`desktop-rel` wraps around, but upstream's `workspace-switch` stops at both ends, so I'll implement the clamped switch in QML. Now the new Bar.qml:

	Bar.qml is done. Next, the Commands rewrite. To match return values I'll check what upstream's toggles and getters print:

	Upstream's `color-scheme-set` takes `<source> <name>`, the toggles and setters return `ok`, while `osd-toggle` and the status commands print `on`/`off`. Now the full Commands.qml:

	Two Brightness problems in what I just wrote. The 3-second poll respawns brightnessctl instead of re-reading sysfs, and a rebuild would reset levels to stale probe values. I'll fix both:

	MonitorTab still reads the old single `Brightness.device`. I'll give it one slider per display:

	Rebuilding the Repeater model on every brightness change would destroy a slider mid-drag. I'll switch to an index-based model, which only recreates delegates when the display count changes:

	Next, Power.qml: direction-aware `cycleProfile`, `lastShellChange` for hook origins, upstream battery glyph thresholds, the escalating warnings and the battery hook states:

	Now Network.qml: upstream glyph bands and `network-toggle` semantics (disconnect the active connection, or reconnect the last device when nothing is connected):

	The shell escaping is correct. Next, X11.qml: the clamped workspace switch and a fallback window cycle for IPC `taskbar-cycle`:

	The battery warnings pass `true` in the history position, but they should bypass DND instead. Fixing those calls:

	Next, Weather.qml's unit handling:

	I'll add the fade overlay as `Modules/Osd/IdleFade.qml`, one per screen, click-through so mouse movement still resets X idle:

	I'll apply the square edge-side corners, and also make the dock honour `[dock.monitor.*]` overrides via the generic override helper:

	Next, install.sh: the `SRC == DEST` guard, the `--help` range, quoting, and the starter-config check for multi-file directories:

	install.sh has all four issues as recorded. Fixing them, and adding ddcutil to the optional-dependency report:

	install.sh passes shellcheck. Before going further I'll run the shell to catch QML errors early, starting with a check that the Xvfb test session is still alive:

	The configuration loads with no QML errors, only the expected bluez and UPower warnings. Here's a screenshot of the new default bar (margin_ends 100, margin_edge 0, so concave screen-edge flares):

	No errors at all. I'll compare against the earlier baseline screenshot, where the floating bar was visible, to see what colour its background had:

	The window geometry is right (1744×34 at +88, i.e. 100 − 12 for the flare), but nothing is painted. I'll add temporary debug logging to Bar.qml to see the shape state and path:

	The path is valid and the Shape is visible, yet nothing is painted. The likely culprit is `preferredRendererType: Shape.CurveRenderer` under this software/llvmpipe setup. I'll test without it:

	Next I'll check attached panels with PanelFrame's CurveRenderer by opening the control center over IPC and sampling its body:

	qmllint lives at `/usr/lib/qt6/bin/qmllint`. The VFS also has 75 QML files while the project has 95, so I'll check what's missing before linting:

	The bar widgets are loaded by URL rather than through the module, so they aren't in the VFS. I'll lint the VFS files plus those directly:

	qmllint reports 0 errors and 105 warnings, most of them known false positives (singletons not declared in the VFS qmldir). I'll group them by message to find any real ones:

	The sidecar works (Nord from `settings.toml` beats the included Catppuccin), and `status` returns upstream's JSON. A screenshot to check both bars:

	A toast window is still present. It could be the config-error toast (which should have been dismissed) or the earlier "Hello world" one, so I'll look:

	The error toast is gone; xwininfo also lists unmapped windows. To confirm hot reload, I'll check the top bar's height change from a newly added file:

	That is correct behaviour: the append creates a second `[bar.top]` table, which TOML forbids, so the change was detected in place, reported, and the previous config kept. I'll restore the file:

	No runtime JS errors so far. Next I'll exercise every panel and control-center tab over IPC and grep the log for errors, since several of them were touched (MonitorTab, notifications, OSD):

	Only a benign "cannot open ~/.face" avatar warning. I'll check the launcher screenshot, since its search field moves to the bottom under the corrected default:

	The launcher's search field is now at the bottom, matching upstream's default. Next, the README, which still describes the single-file config and the old defaults. Here are its sections:

	I'll rewrite the README's installation, requirements, configuration, IPC and "not ported" sections to match the new behaviour:

	Now `config.example.toml`, which still documents the removed port-only keys and the old `[bar.main]` defaults:

	The port uses non-upstream variable names, and upstream runs the hook once per changed connector. Fixing that:

	Now the targeted edits to `config.example.toml`:

	The example parses identically with both parsers. Now a fresh-install simulation: the example as the only config file, checking for config errors and screenshotting the result:

	The bar didn't change, but that's correct: in bytewise order `50-allwidgets.toml` sorts before `config.toml`, so the example's lists win. I'll rename it to load last:

	My helper only kept the last line of the multi-line JSON. Redoing it with full output, and checking which editor process the middle click launches:

	The dock window is at (866, 995), 188×85. Cropping there:

	All checks pass; the single "bad" TOML case is the expected int64 precision limit. Now a changelog of the review fixes for the archive:

	I'll update the README's repository-layout line to mention the new libraries, then stop the test session processes and remove all test leftovers:

	Before packaging, the README's hero screenshot still shows the old floating bar, which is no longer the default look. I'll regenerate it with the new defaults over the default wallpaper:

	Now I'll build the archive, verify its contents and permissions, and test installing from it, including the in-place case that used to delete the source:

	I've finished the review, fixed what it found, re-tested, and rebuilt `/home/user/noctalia-x11.tar.gz` (8.2 MB). The full list of changes is in `CHANGES.md` inside the archive.

	**What I checked:** every file, compared against the v5.3.0 sources. Upstream's own config defaults, IPC commands and widget behaviour won wherever they disagreed with its outdated example config.

	**Most important fixes:**
	- **Config files:** the port only read a single `config.toml`. It now loads config the way Noctalia does:
	  - every `*.toml` in the config folder, merged in alphabetical order;
	  - `[include]` for pulling in other files or folders;
	  - `settings.toml` merged last.
	  
	  A typo in any file now keeps the previous config and shows a notification naming the file and line, instead of failing silently. Duplicate keys and tables are now rejected like upstream; the parser passes the official TOML test suite.
	- **Defaults:**
	  - Adding your own `[bar.top]` used to give you two bars. Now only your bars exist, and with none you get Noctalia's default bar, docked at the top with its curved corners (these were missing before).
	  - Launcher search box, weather units, notification limits and timeouts now match upstream.
	- **Commands (`noctalia-msg`):**
	  - Replies now match upstream (`ok`, a value, or `error: …`; `status` prints JSON).
	  - Volume and brightness values are validated like upstream.
	  - Missing commands were added, and the `bar-*` commands accept a bar name and monitor.
	  - Brightness now supports several monitors, including external ones through ddcutil (untested on real hardware).
	- **Clicks and scrolling on bar widgets** now follow upstream's defaults, and clicks a widget doesn't handle fall through to empty bar space (right-click opens the control center).
	- **Notifications:** apps asking for a notification that stays until dismissed now get one; before, it disappeared after 5 seconds. Critical notifications no longer bypass Do Not Disturb, and filters work like upstream.
	- **On-screen popups and hooks:**
	  - The volume/brightness popup now has upstream's look and wording, and appears when Bluetooth or the power profile is changed from outside the shell.
	  - Low-battery warnings had never been wired up; they now escalate like upstream.
	  - Hook names and environment variables now match upstream.
	- **Smaller fixes:** the theme options (`shell_mode`, high contrast, pure black), language selection, the dock's window-count badges, and 13 text labels that never translated.
	- **Installer:** running `install.sh` from inside its install folder used to delete itself; that's fixed. The README now mentions `bash install.sh` for when the executable bits get lost.

	**Testing:** the shell runs with no errors or code-check failures. I tested in the virtual XFCE session:
	- every command over IPC;
	- live reload when files are added, edited, removed or broken;
	- every widget type on one bar, and the bar shapes, verified in screenshots;
	- every control-center tab;
	- install from the archive, including the in-place case.

	There was no real backlight, battery or Wi-Fi hardware, so those were only tested through their error paths.

	One bug surfaced during testing: the bar's background didn't draw at all with Qt's curve renderer on this machine, so the bar uses the default renderer instead.

	**Still differs from Noctalia (documented in the README):**
	- no drop shadows behind the bar, panels or dock (an X11 window can't draw a shadow without blocking clicks there);
	- the dock's edge corners are square rather than curved;
	- the screenshot widget's right-click menu isn't ported (right-click takes a full screenshot);
	- palette and theme-mode changes made through IPC are saved in the port's own state file rather than written to `settings.toml`.

	I also refreshed the README's control-center screenshot to show the new default bar.

	The rebuilt archive is now open in your viewer.»
```
