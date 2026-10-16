pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import "../Commons/Util.js" as Util

// noctalia's IPC command vocabulary ("noctalia msg <command>"), shared by IPC, bar widget
// gestures ([widget.<name>.actions]), the dead zone, hooks and keybindings. Replies follow
// noctalia: "ok", a value, or "error: ...".
Singleton {
    id: root

    // Runtime per-bar-instance state keyed "<bar>@<screen>": {hidden, reserve, autoHide, layer}
    property var barState: ({})
    property string logLevel: "info"

    readonly property var commandList: [
        "status", "config-reload", "settings-open [section]", "settings-toggle [section]", "settings-close", "settings-open-widget [widget]",
        "session lock|suspend|lock-and-suspend|logout|reboot|shutdown",
        "bar-show [bar-name] [monitor-selector]", "bar-hide [bar-name] [monitor-selector]", "bar-toggle [bar-name] [monitor-selector]",
        "bar-reserve-toggle [bar-name] [monitor-selector]", "bar-auto-hide-set on|off|smart [bar-name] [monitor-selector]",
        "bar-layer-set top|overlay [bar-name] [monitor-selector]",
        "panel-open <id> [context]", "panel-toggle <id> [context]", "panel-close [id]",
        "dock-show", "dock-hide", "dock-toggle", "dock-reload",
        "osd-enable", "osd-disable", "osd-toggle",
        "volume-set <value>", "volume-up [step]", "volume-down [step]", "volume-mute", "volume-osd [value]",
        "mic-volume-set <value>", "mic-volume-up [step]", "mic-volume-down [step]", "mic-mute", "mic-volume-osd [value]",
        "brightness-set [target] <value>", "brightness-up [target] [step]", "brightness-down [target] [step]", "brightness-osd <value>", "brightness-list-backlight-devices",
        "nightlight-enable", "nightlight-disable", "nightlight-toggle", "nightlight-force-toggle",
        "wifi-enable", "wifi-disable", "wifi-toggle", "wifi-status", "network-toggle",
        "bluetooth-enable", "bluetooth-disable", "bluetooth-toggle", "bluetooth-status",
        "caffeine-enable", "caffeine-disable", "caffeine-toggle",
        "power-set <profile>", "power-cycle [next|prev]", "dpms-on", "dpms-off",
        "notification-dnd-set on|off", "notification-dnd-toggle", "notification-dnd-status", "notification-show <summary> [body] | <json>",
        "notification-invoke-latest", "notification-clear-active", "notification-clear-history",
        "clipboard-clear", "clipboard-copy <text>", "clipboard-text",
        "media next|previous|toggle|play|pause|stop|next-player|previous-player",
        "wallpaper-random [monitor]", "wallpaper-next [monitor]", "wallpaper-previous [monitor]", "wallpaper-get [monitor]", "wallpaper-set [monitor] <path>",
        "theme-mode-get", "theme-mode-toggle", "theme-mode-set dark|light|auto",
        "color-scheme-get", "color-scheme-set builtin <name> | wallpaper <scheme>",
        "screenshot-region", "screenshot-annotate", "screenshot-fullscreen [pick|monitor|all]",
        "workspace-switch next|prev", "taskbar-cycle next|prev", "keyboard-layout-cycle",
        "log-level-status", "log-level-set debug|info|warn|error",
        // port extras (X11)
        "workspace <n>", "workspace-next", "workspace-previous", "show-desktop", "keyboard-layout-next", "keyboard-layout-previous", "exec <command line>"
    ]

    function tokenize(line) {
        var out = [], cur = "", quote = "", has = false;
        for (var i = 0; i < line.length; i++) {
            var c = line.charAt(i);
            if (quote) {
                if (c === quote)
                    quote = "";
                else if (c === "\\" && quote === "\"" && i + 1 < line.length)
                    cur += line.charAt(++i);
                else
                    cur += c;
            } else if (c === "\"" || c === "'") {
                quote = c;
                has = true;
            } else if (c === " " || c === "\t") {
                if (cur.length > 0 || has) {
                    out.push(cur);
                    cur = "";
                    has = false;
                }
            } else {
                cur += c;
            }
        }
        if (cur.length > 0 || has)
            out.push(cur);
        return out;
    }

    function isMonitorArg(a) {
        if (a === "*" || a === "all")
            return true;
        var s = Quickshell.screens;
        for (var i = 0; i < s.length; i++)
            if (Config.screenMatches(a, s[i]))
                return true;
        return false;
    }

    // Screen of the active window (or the first screen): "the current output".
    function currentScreen() {
        var aw = X11.activeWindow;
        return aw ? X11.screenOf(aw) : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    // ---------------------------------------------------------------- bars
    // Resolve [bar-name] [monitor-selector] into bar instance keys; returns {keys} or {error}.
    function barTargets(barName, selector) {
        var names = Config.barNames;
        if (barName && barName !== "" && barName !== "*") {
            if (names.indexOf(barName) < 0)
                return {
                    error: "error: unknown bar \"" + barName + "\" (available: " + names.join(", ") + ")"
                };
            names = [barName];
        }
        var screens = Quickshell.screens;
        if (selector && selector !== "" && selector !== "*") {
            var matched = [];
            for (var i = 0; i < screens.length; i++)
                if (Config.screenMatches(selector, screens[i]))
                    matched.push(screens[i]);
            if (matched.length === 0)
                return {
                    error: "error: no monitor matched \"" + selector + "\""
                };
            if (matched.length > 1)
                return {
                    error: "error: monitor selector \"" + selector + "\" matched multiple outputs: " + matched.map(s => s.name).join(", ")
                };
            screens = matched;
        }
        var keys = [];
        for (var n = 0; n < names.length; n++)
            for (var j = 0; j < screens.length; j++)
                keys.push(names[n] + "@" + screens[j].name);
        return {
            keys: keys
        };
    }

    function setBarState(keys, field, valueFn) {
        var st = Object.assign({}, barState);
        for (var i = 0; i < keys.length; i++) {
            var e = Object.assign({}, st[keys[i]] || {});
            e[field] = valueFn(e, keys[i]);
            st[keys[i]] = e;
        }
        barState = st;
    }

    function barCommand(cmd, a) {
        var withState = cmd === "bar-auto-hide-set" || cmd === "bar-layer-set";
        var state = withState ? (a[0] || "") : "";
        var rest = withState ? a.slice(1) : a;
        if (rest.length > 2)
            return "error: usage: " + cmd + (withState ? " <state>" : "") + " [bar-name] [monitor-selector]";
        var t = barTargets(rest[0] || "", rest[1] || "");
        if (t.error)
            return t.error;
        if (cmd === "bar-show" || cmd === "bar-hide") {
            setBarState(t.keys, "hidden", () => cmd === "bar-hide");
        } else if (cmd === "bar-toggle") {
            var anyVisible = t.keys.some(k => !(barState[k] && barState[k].hidden === true));
            setBarState(t.keys, "hidden", () => anyVisible);
        } else if (cmd === "bar-reserve-toggle") {
            setBarState(t.keys, "reserve", function (e, key) {
                if (e.reserve !== undefined)
                    return !e.reserve;
                var cfg = Config.barByName(key.split("@")[0]);
                return cfg.reserve_space === false;
            });
        } else if (cmd === "bar-auto-hide-set") {
            var mode = ({
                    on: "on",
                    "true": "on",
                    "1": "on",
                    off: "off",
                    "false": "off",
                    "0": "off",
                    smart: "smart"
                })[state];
            if (mode === undefined)
                return "error: expected on, off, or smart";
            setBarState(t.keys, "autoHide", () => mode);
        } else if (cmd === "bar-layer-set") {
            if (state !== "top" && state !== "overlay")
                return "error: expected top or overlay";
            // X11 docks are always stacked above normal windows; the layer is kept for status only.
            setBarState(t.keys, "layer", () => state);
        }
        return "ok";
    }

    // ---------------------------------------------------------------- misc helpers
    function levelArg(args, name, maxPercent, required) {
        if (args.length > 1)
            return {
                error: "error: " + name + " accepts " + (required ? "exactly one <value>" : "at most one optional [step]")
            };
        if (args.length === 0)
            return required ? {
                error: "error: " + name + " requires <value>"
            } : {
                value: null
            };
        var v = Util.parseNormalizedOrPercent(args[0], maxPercent);
        if (v === null)
            return {
                error: required ? "error: invalid volume value (use percent like 65 or 65%, or normalized like 0.65)" : "error: invalid volume step (use percent like 5 or 5%, or normalized like 0.05)"
            };
        return {
            value: v
        };
    }

    function screenshot(kind, mode) {
        var custom = String(Config.get(kind === "region" ? "x11.screenshot_region_command" : "x11.screenshot_full_command", ""));
        if (custom !== "") {
            Quickshell.execDetached(["sh", "-c", custom]);
            return;
        }
        var dir = "\"$(xdg-user-dir PICTURES 2>/dev/null || echo $HOME)/Screenshots\"";
        var file = dir + "/Screenshot_$(date +%Y%m%d_%H%M%S).png";
        var cmd;
        if (kind === "region" || mode === "pick") {
            cmd = "if command -v xfce4-screenshooter >/dev/null; then exec xfce4-screenshooter -r; " + "elif command -v flameshot >/dev/null; then exec flameshot gui; " + "elif command -v maim >/dev/null; then mkdir -p " + dir + "; exec maim -s " + file + "; " + "elif command -v scrot >/dev/null; then mkdir -p " + dir + "; exec scrot -s " + file + "; fi";
        } else if (mode === "all") {
            cmd = "if command -v xfce4-screenshooter >/dev/null; then exec xfce4-screenshooter -f; " + "elif command -v flameshot >/dev/null; then exec flameshot full; " + "elif command -v maim >/dev/null; then mkdir -p " + dir + "; exec maim " + file + "; " + "elif command -v scrot >/dev/null; then mkdir -p " + dir + "; exec scrot " + file + "; fi";
        } else {
            // one monitor: the named output, else the focused one
            var scr = null;
            if (mode && mode !== "monitor") {
                var all = Quickshell.screens;
                for (var i = 0; i < all.length; i++)
                    if (Config.screenMatches(mode, all[i]))
                        scr = all[i];
            }
            if (!scr)
                scr = currentScreen();
            var g = scr ? scr.width + "x" + scr.height + "+" + scr.x + "+" + scr.y : "";
            var a = scr ? scr.x + "," + scr.y + "," + scr.width + "," + scr.height : "";
            cmd = "if command -v maim >/dev/null; then mkdir -p " + dir + "; exec maim -g " + g + " " + file + "; " + "elif command -v scrot >/dev/null; then mkdir -p " + dir + "; exec scrot -a " + a + " " + file + "; " + "elif command -v xfce4-screenshooter >/dev/null; then exec xfce4-screenshooter -f; " + "elif command -v flameshot >/dev/null; then exec flameshot screen; fi";
        }
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function openSettings() {
        var custom = String(Config.get("x11.settings_command", ""));
        if (custom !== "") {
            Quickshell.execDetached(["sh", "-c", custom]);
            return;
        }
        // Open the active config file (config.toml when present), or create our own from the example.
        var target = Config.ownPath;
        var files = Config.activeFiles || [];
        if (files.length > 0) {
            target = files[0];
            for (var i = 0; i < files.length; i++)
                if (/\/config\.toml$/.test(files[i]))
                    target = files[i];
        }
        var example = (Quickshell.shellDir + "/config.example.toml");
        Quickshell.execDetached(["sh", "-c", "f=\"$1\"; if [ ! -e \"$f\" ]; then mkdir -p \"$(dirname \"$f\")\"; cp \"$2\" \"$f\"; fi; " + "if command -v mousepad >/dev/null; then exec mousepad \"$f\"; elif command -v exo-open >/dev/null; then exec exo-open \"$f\"; else exec xdg-open \"$f\"; fi", "sh", target, example]);
    }

    function statusJson() {
        var anyVisible = false;
        var keys = barTargets("", "").keys || [];
        for (var i = 0; i < keys.length; i++)
            if (!(barState[keys[i]] && barState[keys[i]].hidden === true))
                anyVisible = true;
        return JSON.stringify({
            barVisible: anyVisible,
            panelOpen: Panels.isOpen,
            activePanelId: Panels.isOpen ? Panels.activePanel : null,
            locked: Session.locked === true
        }, null, 2);
    }

    // Runs a command line. `origin` (optional): {screen, anchor, bar, barWindow, widget, widgetName}
    // from a bar widget or the dead zone.
    function run(line, origin) {
        var s = String(line || "").trim();
        if (s.length === 0 || s === "none")
            return "";
        if (s.indexOf("exec ") === 0) {
            Quickshell.execDetached(["sh", "-c", s.slice(5)]);
            return "ok";
        }
        var t = tokenize(s);
        var cmd = t[0];
        var a = t.slice(1);
        var rest = s.slice(cmd.length).trim();
        var o = origin || {};
        var r;
        switch (cmd) {
        case "status":
            return statusJson();
        case "config-reload":
            Config.reload();
            return "ok";
        case "settings-open":
        case "settings-toggle":
        case "settings-open-widget":
            openSettings();
            return "ok";
        case "settings-close":
            return "ok";
        case "session":
            if (["lock", "suspend", "lock-and-suspend", "logout", "reboot", "shutdown", "hibernate"].indexOf(a[0] || "") < 0)
                return "error: expected lock, suspend, lock-and-suspend, logout, reboot, or shutdown";
            Session.run(a[0]);
            return "ok";
        case "bar-show":
        case "bar-hide":
        case "bar-toggle":
        case "bar-reserve-toggle":
        case "bar-auto-hide-set":
        case "bar-layer-set":
            return barCommand(cmd, a);
        case "panel-open":
        case "panel-toggle": {
            var id = a[0] || "";
            if (id === "")
                return "error: " + cmd + " requires <id>";
            if (Panels.knownPanels.indexOf(id) < 0)
                return "error: unknown panel \"" + id + "\"";
            var ctx = a.slice(1).join(" ");
            if (o.screen)
                (cmd === "panel-toggle" ? Panels.toggle : Panels.open)(id, o.screen, ctx, o.anchor || null, o.bar || null, null);
            else
                Panels.ipc(cmd === "panel-toggle" ? "toggle" : "open", id, ctx);
            return "ok";
        }
        case "panel-close":
            Panels.close(a[0] || "");
            return "ok";
        case "dock-show":
            ShellState.set("dock_hidden", false);
            return "ok";
        case "dock-hide":
            ShellState.set("dock_hidden", true);
            return "ok";
        case "dock-toggle":
            ShellState.set("dock_hidden", !ShellState.get("dock_hidden", false));
            return "ok";
        case "dock-reload":
            Config.reload();
            return "ok";
        case "osd-enable":
            Osd.userEnabled = true;
            return "ok";
        case "osd-disable":
            Osd.userEnabled = false;
            return "ok";
        case "osd-toggle":
            if (a.length > 0)
                return "error: osd-toggle takes no arguments";
            Osd.userEnabled = !Osd.enabled;
            return Osd.enabled ? "on" : "off";
        case "volume-set":
            r = levelArg(a, cmd, Audio.maxVolume * 100, true);
            if (r.error)
                return r.error;
            if (!Audio.ready)
                return "error: no default output";
            Audio.setVolume(r.value);
            return "ok";
        case "volume-up":
        case "volume-down":
            r = levelArg(a, cmd, Audio.maxVolume * 100, false);
            if (r.error)
                return r.error;
            if (!Audio.ready)
                return "error: no default output";
            Audio.changeVolume((cmd === "volume-up" ? 1 : -1) * (r.value === null ? Audio.step : r.value));
            return "ok";
        case "volume-mute":
            if (!Audio.ready)
                return "error: no default output";
            Audio.toggleMute();
            return "ok";
        case "volume-osd":
            r = levelArg(a, cmd, Audio.maxVolume * 100, false);
            if (r.error)
                return r.error;
            var vo = r.value === null ? Audio.volume : r.value;
            Osd.showLevel("volume_output", Audio.volumeGlyph(vo, Audio.muted), vo, Audio.muted);
            return "ok";
        case "mic-volume-set":
            r = levelArg(a, cmd, Audio.maxVolume * 100, true);
            if (r.error)
                return r.error;
            if (!Audio.micReady)
                return "error: no default input";
            Audio.setMicVolume(r.value);
            return "ok";
        case "mic-volume-up":
        case "mic-volume-down":
            r = levelArg(a, cmd, Audio.maxVolume * 100, false);
            if (r.error)
                return r.error;
            if (!Audio.micReady)
                return "error: no default input";
            Audio.changeMicVolume((cmd === "mic-volume-up" ? 1 : -1) * (r.value === null ? Audio.step : r.value));
            return "ok";
        case "mic-mute":
            if (!Audio.micReady)
                return "error: no default input";
            Audio.toggleMicMute();
            return "ok";
        case "mic-volume-osd":
            r = levelArg(a, cmd, Audio.maxVolume * 100, false);
            if (r.error)
                return r.error;
            var mo = r.value === null ? Audio.micVolume : r.value;
            Osd.showLevel("volume_input", Audio.micGlyph(mo, Audio.micMuted), mo, Audio.micMuted);
            return "ok";
        case "brightness-set": {
            if (a.length === 0 || a.length > 2)
                return "error: brightness-set requires <value> or <target> <value>";
            var target = a.length === 2 ? a[0] : "current";
            var amount = Util.parseNormalizedOrPercent(a.length === 2 ? a[1] : a[0], 100);
            if (amount === null)
                return "error: invalid brightness value (use percent like 65 or 65%, or normalized like 0.65)";
            var bt = Brightness.resolveTargets(target, o.screen || null);
            if (bt.error)
                return bt.error;
            Brightness.setLevels(bt.ids, function () {
                return amount;
            });
            return "ok";
        }
        case "brightness-up":
        case "brightness-down": {
            if (a.length > 2)
                return "error: " + cmd + " accepts at most [target] [step]";
            var btarget = "current";
            var bstep = Brightness.step;
            if (a.length === 1) {
                var maybe = Util.parseNormalizedOrPercent(a[0], 100);
                if (maybe !== null)
                    bstep = maybe;
                else
                    btarget = a[0];
            } else if (a.length === 2) {
                btarget = a[0];
                bstep = Util.parseNormalizedOrPercent(a[1], 100);
            }
            if (bstep === null)
                return "error: invalid brightness step (use percent like 5 or 5%, or normalized like 0.05)";
            var bts = Brightness.resolveTargets(btarget, o.screen || null);
            if (bts.error)
                return bts.error;
            var dir = cmd === "brightness-up" ? 1 : -1;
            Brightness.setLevels(bts.ids, function (current) {
                return current + dir * bstep;
            });
            return "ok";
        }
        case "brightness-osd": {
            if (a.length !== 1)
                return "error: brightness-osd requires <value>";
            var bo = Util.parseNormalizedOrPercent(a[0], 100);
            if (bo === null)
                return "error: invalid brightness value (use percent like 65 or 65%, or normalized like 0.65)";
            Osd.showLevel("brightness", bo < 0.4 ? "brightness-low" : "brightness-high", bo, false);
            return "ok";
        }
        case "brightness-list-backlight-devices":
            return Brightness.backlightDevices.length > 0 ? Brightness.backlightDevices.join("\n") : "error: no backlight devices available";
        case "nightlight-enable":
            NightLight.setEnabled(true);
            return "ok";
        case "nightlight-disable":
            NightLight.setEnabled(false);
            return "ok";
        case "nightlight-toggle":
            NightLight.toggle();
            return "ok";
        case "nightlight-force-toggle":
            NightLight.toggleForce();
            return "ok";
        case "wifi-enable":
        case "wifi-disable":
        case "wifi-toggle":
            if (!Network.available)
                return "error: network state unavailable";
            Network.setWifi(cmd === "wifi-enable" ? true : cmd === "wifi-disable" ? false : !Network.wifiEnabled);
            return "ok";
        case "wifi-status":
            return Network.wifiEnabled ? "on" : "off";
        case "network-toggle":
            if (!Network.available)
                return "error: network state unavailable";
            Network.toggleConnection();
            return "ok";
        case "bluetooth-enable":
        case "bluetooth-disable":
        case "bluetooth-toggle":
            if (!BluetoothService.available)
                return "error: bluetooth state unavailable";
            BluetoothService.setEnabled(cmd === "bluetooth-enable" ? true : cmd === "bluetooth-disable" ? false : !BluetoothService.enabled);
            return "ok";
        case "bluetooth-status":
            return BluetoothService.enabled ? "on" : "off";
        case "caffeine-enable":
            Idle.setCaffeine(true);
            return "ok";
        case "caffeine-disable":
            Idle.setCaffeine(false);
            return "ok";
        case "caffeine-toggle":
            Idle.toggleCaffeine();
            return "ok";
        case "power-set":
            if (!Power.profilesAvailable)
                return "error: power profiles unavailable";
            if (["power-saver", "balanced", "performance"].indexOf(a[0] || "") < 0)
                return "error: expected power-saver, balanced, or performance";
            Power.setProfile(a[0]);
            return "ok";
        case "power-cycle":
            if (!Power.profilesAvailable)
                return "error: power profiles unavailable";
            if (a.length > 0 && a[0] !== "next" && a[0] !== "prev")
                return "error: expected next or prev";
            Power.cycleProfile(a[0] === "prev" ? -1 : 1);
            return "ok";
        case "dpms-on":
            Quickshell.execDetached(["xset", "dpms", "force", "on"]);
            return "ok";
        case "dpms-off":
            Quickshell.execDetached(["sh", "-c", "sleep 0.5; xset dpms force off"]);
            return "ok";
        case "notification-dnd-set": {
            var dndOn = ({
                    on: true,
                    "true": true,
                    "1": true,
                    off: false,
                    "false": false,
                    "0": false
                })[a[0]];
            if (dndOn === undefined)
                return "error: expected on or off";
            Notifications.setDnd(dndOn);
            return "ok";
        }
        case "notification-dnd-toggle":
            Notifications.toggleDnd();
            return "ok";
        case "notification-dnd-status":
            return Notifications.dnd ? "on" : "off";
        case "notification-show": {
            if (rest.charAt(0) === "{") {
                try {
                    var j = JSON.parse(rest);
                    Notifications.notifyInternal(j.summary || "", j.body || "", j.icon || "toast-notice", j.urgency || "normal", j.timeout_ms);
                    return "ok";
                } catch (e) {
                    return "error: invalid json";
                }
            }
            if (a.length === 0)
                return "error: notification-show requires <summary>";
            Notifications.notifyInternal(a[0], a.slice(1).join(" "), "toast-notice");
            return "ok";
        }
        case "notification-invoke-latest":
            Notifications.invokeLatest();
            return "ok";
        case "notification-clear-active":
            Notifications.clearActive();
            return "ok";
        case "notification-clear-history":
            Notifications.clearHistory();
            return "ok";
        case "clipboard-clear":
            Clipboard.clear();
            return "ok";
        case "clipboard-copy":
            if (rest === "")
                return "error: clipboard-copy requires <text>";
            Clipboard.copy(rest);
            return "ok";
        case "clipboard-text":
            return Quickshell.clipboardText;
        case "media":
            switch (a[0]) {
            case "previous": Media.previous(); break;
            case "next": Media.next(); break;
            case "toggle": Media.togglePlaying(); break;
            case "play": Media.play(); break;
            case "pause": Media.pause(); break;
            case "stop": Media.stop(); break;
            case "previous-player": Media.cyclePlayer(-1); break;
            case "next-player": Media.cyclePlayer(1); break;
            default: return "error: expected next, previous, toggle, play, pause, stop, next-player, or previous-player";
            }
            return "ok";
        case "wallpaper-random":
            Wallpaper.random(a[0] || "*");
            return "ok";
        case "wallpaper-next":
            Wallpaper.next(a[0] || "*");
            return "ok";
        case "wallpaper-previous":
            Wallpaper.previous(a[0] || "*");
            return "ok";
        case "wallpaper-get":
            return Wallpaper.current(a[0] || "");
        case "wallpaper-set": {
            if (a.length >= 2 && isMonitorArg(a[0]))
                Wallpaper.set(a[0], rest.slice(rest.indexOf(a[0]) + a[0].length).trim());
            else if (rest !== "")
                Wallpaper.set("*", rest);
            else
                return "error: wallpaper-set requires [monitor] <path>";
            return "ok";
        }
        case "theme-mode-get":
            return Theme.appMode;
        case "theme-mode-toggle":
            ThemeControl.setMode(Theme.appIsDark ? "light" : "dark");
            return "ok";
        case "theme-mode-set":
            if (["dark", "light", "auto"].indexOf(rest) < 0)
                return "error: expected dark, light, or auto";
            ThemeControl.setMode(rest);
            return "ok";
        case "color-scheme-get":
            return Theme.source === "wallpaper" ? "wallpaper " + Theme.wallpaperScheme : "builtin " + Theme.builtinName;
        case "color-scheme-set": {
            if (a.length < 1)
                return "error: expected <builtin|wallpaper|community|custom> <name-or-scheme>";
            var err = ThemeControl.setSource(a[0], a.slice(1).join(" "));
            return err === "" ? "ok" : err;
        }
        case "screenshot-region":
        case "screenshot-annotate":
            screenshot("region", "");
            return "ok";
        case "screenshot-fullscreen":
            screenshot("full", a[0] || "");
            return "ok";
        case "workspace-switch":
            if (a.length > 0 && a[0] !== "next" && a[0] !== "prev")
                return "error: expected next or prev";
            X11.switchDesktopClamped(a[0] === "prev" ? -1 : 1);
            return "ok";
        case "taskbar-cycle":
            if (a.length > 0 && a[0] !== "next" && a[0] !== "prev")
                return "error: expected next or prev";
            if (o.widget && typeof o.widget.cycle === "function")
                o.widget.cycle(a[0] === "prev" ? -1 : 1);
            else
                X11.cycleWindows(a[0] === "prev" ? -1 : 1);
            return "ok";
        case "keyboard-layout-cycle":
            X11.layoutNext();
            return "ok";
        case "log-level-status":
            return logLevel;
        case "log-level-set":
            if (["debug", "info", "warn", "error"].indexOf(a[0] || "") < 0)
                return "error: invalid log level (use debug, info, warn, or error)";
            logLevel = a[0];
            return "ok";
        // ---- port extras
        case "workspace":
            X11.switchDesktop(Math.max(0, parseInt(a[0] || "1") - 1));
            return "ok";
        case "workspace-next":
            X11.relDesktop(1);
            return "ok";
        case "workspace-previous":
            X11.relDesktop(-1);
            return "ok";
        case "show-desktop":
            X11.showDesktop();
            return "ok";
        case "keyboard-layout-next":
            X11.layoutNext();
            return "ok";
        case "keyboard-layout-previous":
            X11.layoutPrev();
            return "ok";
        case "help":
        case "--help":
            return commandList.join("\n");
        }
        console.warn("[noctalia-x11] unknown command:", s);
        return "error: unknown command: " + cmd;
    }
}
