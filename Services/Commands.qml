pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// noctalia's IPC command vocabulary ("noctalia msg <command>"), shared by IPC, bar widget
// actions ([widget.<name>.actions]), hooks and keybindings.
Singleton {
    id: root

    property var hiddenBars: ({})       // runtime bar-hide state keyed by bar name ("*" = all)

    readonly property var commandList: ["status", "config-reload", "settings-open", "settings-toggle", "settings-close", "session lock|suspend|lock-and-suspend|logout|reboot|shutdown|hibernate", "bar-show [bar]", "bar-hide [bar]", "bar-toggle [bar]", "panel-open <id> [context]", "panel-toggle <id> [context]", "panel-close [id]", "dock-show", "dock-hide", "dock-toggle", "osd-enable", "osd-disable", "osd-toggle", "volume-set <level>", "volume-up [step]", "volume-down [step]", "volume-mute", "volume-osd [level]", "mic-volume-set <level>", "mic-volume-up [step]", "mic-volume-down [step]", "mic-mute", "mic-volume-osd [level]", "brightness-set [monitor] <level>", "brightness-up [monitor] [step]", "brightness-down [monitor] [step]", "brightness-osd [level]", "nightlight-enable", "nightlight-disable", "nightlight-toggle", "nightlight-force-toggle", "wifi-enable", "wifi-disable", "wifi-toggle", "wifi-status", "bluetooth-enable", "bluetooth-disable", "bluetooth-toggle", "bluetooth-status", "caffeine-enable", "caffeine-disable", "caffeine-toggle", "power-set <profile>", "power-cycle", "dpms-on", "dpms-off", "notification-dnd-set on|off", "notification-dnd-toggle", "notification-dnd-status", "notification-show <summary> [body]", "notification-invoke-latest", "notification-clear-active", "notification-clear-history", "clipboard-clear", "clipboard-copy <text>", "clipboard-text", "media previous|next|toggle|play|pause|stop|previous-player|next-player", "wallpaper-random [monitor]", "wallpaper-next [monitor]", "wallpaper-previous [monitor]", "wallpaper-get [monitor]", "wallpaper-set [monitor] <path>", "theme-mode-get", "theme-mode-toggle", "theme-mode-set dark|light|auto", "color-scheme-get", "color-scheme-set builtin <name> | wallpaper", "screenshot-region", "screenshot-fullscreen", "workspace <n>", "workspace-next", "workspace-previous", "show-desktop", "keyboard-layout-next", "keyboard-layout-previous", "exec <command line>"]

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

    function step(arg, fallback) {
        if (arg === undefined || arg === "")
            return fallback;
        var s = String(arg);
        var pct = s.endsWith("%");
        var n = parseFloat(pct ? s.slice(0, -1) : s);
        if (isNaN(n))
            return fallback;
        return n >= 1 || pct ? n / 100 : n;
    }

    function isMonitorArg(a) {
        return a === "*" || Panels.screenByName(a) !== null;
    }

    function screenshot(kind) {
        var custom = String(Config.get(kind === "region" ? "x11.screenshot_region_command" : "x11.screenshot_full_command", ""));
        if (custom !== "") {
            Quickshell.execDetached(["sh", "-c", custom]);
            return;
        }
        var dir = "\"$(xdg-user-dir PICTURES 2>/dev/null || echo $HOME)/Screenshots\"";
        var file = dir + "/Screenshot_$(date +%Y%m%d_%H%M%S).png";
        var cmd = kind === "region" ? "if command -v xfce4-screenshooter >/dev/null; then exec xfce4-screenshooter -r; " + "elif command -v flameshot >/dev/null; then exec flameshot gui; " + "elif command -v maim >/dev/null; then mkdir -p " + dir + "; exec maim -s " + file + "; " + "elif command -v scrot >/dev/null; then mkdir -p " + dir + "; exec scrot -s " + file + "; fi" : "if command -v xfce4-screenshooter >/dev/null; then exec xfce4-screenshooter -f; " + "elif command -v flameshot >/dev/null; then exec flameshot full; " + "elif command -v maim >/dev/null; then mkdir -p " + dir + "; exec maim " + file + "; " + "elif command -v scrot >/dev/null; then mkdir -p " + dir + "; exec scrot " + file + "; fi";
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function openSettings() {
        var custom = String(Config.get("x11.settings_command", ""));
        if (custom !== "") {
            Quickshell.execDetached(["sh", "-c", custom]);
            return;
        }
        var target = Config.ownPath;
        var example = (Quickshell.shellDir + "/config.example.toml");
        Quickshell.execDetached(["sh", "-c", "f='" + target + "'; if [ ! -e \"$f\" ]; then mkdir -p \"$(dirname \"$f\")\"; cp '" + example + "' \"$f\"; fi; " + "if command -v mousepad >/dev/null; then exec mousepad \"$f\"; elif command -v exo-open >/dev/null; then exec exo-open \"$f\"; else exec xdg-open \"$f\"; fi"]);
    }

    // Runs a command line. `origin` (optional): {screen, anchor, bar} from a bar widget.
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
        switch (cmd) {
        case "status":
            return "running (noctalia-x11, quickshell)";
        case "config-reload":
            Config.reload();
            return "ok";
        case "settings-open":
        case "settings-toggle":
            openSettings();
            return "ok";
        case "settings-close":
            return "ok";
        case "session":
            Session.run(a[0] || "");
            return "ok";
        case "bar-show":
        case "bar-hide":
        case "bar-toggle": {
            var key = a[0] || "*";
            var h = Object.assign({}, hiddenBars);
            var cur = h[key] === true || (key !== "*" && h["*"] === true);
            var next = cmd === "bar-hide" ? true : cmd === "bar-show" ? false : !cur;
            if (key === "*")
                h = {};
            h[key] = next;
            hiddenBars = h;
            return next ? "hidden" : "shown";
        }
        case "panel-open":
        case "panel-toggle": {
            var id = a[0] || "";
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
        case "osd-enable":
            Osd.userEnabled = true;
            return "ok";
        case "osd-disable":
            Osd.userEnabled = false;
            return "ok";
        case "osd-toggle":
            Osd.userEnabled = !Osd.userEnabled;
            return Osd.userEnabled ? "enabled" : "disabled";
        case "volume-set":
            Audio.setVolume(Audio.parseLevel(a[0], Audio.volume));
            return "ok";
        case "volume-up":
            Audio.changeVolume(step(a[0], Audio.step));
            return "ok";
        case "volume-down":
            Audio.changeVolume(-step(a[0], Audio.step));
            return "ok";
        case "volume-mute":
            Audio.toggleMute();
            return "ok";
        case "volume-osd":
            Osd.show("volume", Audio.volumeGlyph(Audio.volume, Audio.muted), "", a.length ? Audio.parseLevel(a[0], Audio.volume) : Audio.volume, Audio.maxVolume, Audio.muted);
            return "ok";
        case "mic-volume-set":
            Audio.setMicVolume(Audio.parseLevel(a[0], Audio.micVolume));
            return "ok";
        case "mic-volume-up":
            Audio.changeMicVolume(step(a[0], Audio.step));
            return "ok";
        case "mic-volume-down":
            Audio.changeMicVolume(-step(a[0], Audio.step));
            return "ok";
        case "mic-mute":
            Audio.toggleMicMute();
            return "ok";
        case "mic-volume-osd":
            Osd.show("volume_input", Audio.micMuted ? "microphone-mute" : "microphone", "", a.length ? Audio.parseLevel(a[0], Audio.micVolume) : Audio.micVolume, 1, Audio.micMuted);
            return "ok";
        case "brightness-set": {
            var args = a.length > 1 && isMonitorArg(a[0]) ? a.slice(1) : a;
            Brightness.setBrightness(Audio.parseLevel(args[0], Brightness.brightness));
            return "ok";
        }
        case "brightness-up":
        case "brightness-down": {
            var bargs = a.length > 0 && isMonitorArg(a[0]) ? a.slice(1) : a;
            var d = step(bargs[0], Brightness.step);
            Brightness.change(cmd === "brightness-up" ? d : -d);
            return "ok";
        }
        case "brightness-osd":
            Osd.show("brightness", "brightness-high", "", a.length ? Audio.parseLevel(a[a.length - 1], Brightness.brightness) : Brightness.brightness, 1);
            return "ok";
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
            Network.setWifi(true);
            return "ok";
        case "wifi-disable":
            Network.setWifi(false);
            return "ok";
        case "wifi-toggle":
            Network.toggleWifi();
            return "ok";
        case "wifi-status":
            return Network.wifiEnabled ? "on" : "off";
        case "bluetooth-enable":
            BluetoothService.setEnabled(true);
            return "ok";
        case "bluetooth-disable":
            BluetoothService.setEnabled(false);
            return "ok";
        case "bluetooth-toggle":
            BluetoothService.toggle();
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
            return Idle.caffeine ? "on" : "off";
        case "power-set":
            Power.setProfile(a[0] || "balanced");
            return "ok";
        case "power-cycle":
            if (a[0] === "prev" || a[0] === "previous") {
                var order = Power.hasPerformance ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"];
                var pi = order.indexOf(Power.profileName);
                Power.setProfile(order[(pi - 1 + order.length) % order.length]);
            } else {
                Power.cycleProfile();
            }
            return "ok";
        case "dpms-on":
            Quickshell.execDetached(["xset", "dpms", "force", "on"]);
            return "ok";
        case "dpms-off":
            Quickshell.execDetached(["sh", "-c", "sleep 0.5; xset dpms force off"]);
            return "ok";
        case "notification-dnd-set":
            Notifications.setDnd(a[0] === "on" || a[0] === "true" || a[0] === "1");
            return "ok";
        case "notification-dnd-toggle":
            Notifications.toggleDnd();
            return Notifications.dnd ? "on" : "off";
        case "notification-dnd-status":
            return Notifications.dnd ? "on" : "off";
        case "notification-show": {
            if (rest.charAt(0) === "{") {
                try {
                    var j = JSON.parse(rest);
                    Notifications.notifyInternal(j.summary || "", j.body || "", j.icon || "toast-notice", j.urgency || "normal", j.timeout_ms);
                    return "ok";
                } catch (e) {
                    return "invalid json";
                }
            }
            Notifications.notifyInternal(a[0] || "", a.slice(1).join(" "), "toast-notice");
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
            default: return "unknown media action";
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
            else
                Wallpaper.set("*", rest);
            return "ok";
        }
        case "theme-mode-get":
            return Theme.requestedMode;
        case "theme-mode-toggle":
            ThemeControl.setMode(Theme.isDark ? "light" : "dark");
            return Theme.mode;
        case "theme-mode-set":
            ThemeControl.setMode(a[0] || "dark");
            return "ok";
        case "color-scheme-get":
            return Theme.source === "wallpaper" ? "wallpaper" : "builtin " + Theme.builtinName;
        case "color-scheme-set":
            if (a[0] === "wallpaper")
                ThemeControl.setSource("wallpaper", "");
            else
                ThemeControl.setSource("builtin", a[0] === "builtin" ? a.slice(1).join(" ") : a.join(" "));
            return "ok";
        case "screenshot-region":
        case "screenshot-annotate":
            screenshot("region");
            return "ok";
        case "screenshot-fullscreen":
            screenshot("full");
            return "ok";
        case "workspace":
            X11.switchDesktop(Math.max(0, parseInt(a[0] || "1") - 1));
            return "ok";
        case "workspace-switch":
            X11.relDesktop(a[0] === "prev" || a[0] === "previous" ? -1 : 1);
            return "ok";
        case "network-toggle":
            Network.toggleWifi();
            return "ok";
        case "keyboard-layout-cycle":
            X11.layoutNext();
            return "ok";
        case "settings-open-widget":
            openSettings();
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
        return "unknown command: " + cmd;
    }
}
