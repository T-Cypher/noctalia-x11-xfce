pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Session actions for X11/XFCE. Locking is delegated to a real X11 screen locker (xflock4 by
// default) because an X11 client cannot implement a secure session lock like
// ext-session-lock-v1; power actions go through xfce4-session when available, else logind.
Singleton {
    id: root

    readonly property bool isXfce: String(Quickshell.env("XDG_CURRENT_DESKTOP") || "").toUpperCase().indexOf("XFCE") >= 0
    property bool hasXfceLogout: false

    readonly property var defaultActions: [
        { action: "lock", shortcut: "1" },
        { action: "logout", shortcut: "2" },
        { action: "lock_and_suspend", shortcut: "3" },
        { action: "reboot", shortcut: "4" },
        { action: "shutdown", variant: "destructive", shortcut: "5" }
    ]

    readonly property var actions: {
        var src = Config.get("shell.session.actions", []);
        if (!Array.isArray(src) || src.length === 0)
            src = defaultActions;
        var lockEnabled = Config.get("lockscreen.enabled", true) !== false;
        return src.filter(function (a) {
            if (!a || a.enabled === false || !a.action)
                return false;
            if ((a.action === "lock" || a.action === "lock_and_suspend") && !lockEnabled)
                return false;
            if (a.action === "command" && !a.command)
                return false;
            return ["lock", "logout", "suspend", "lock_and_suspend", "reboot", "shutdown", "hibernate", "command"].indexOf(a.action) >= 0;
        });
    }

    signal aboutTo(string action)

    function label(a) {
        if (a.label)
            return a.label;
        var key = {
            "lock": "session.actions.lock",
            "logout": "session.actions.logout",
            "suspend": "session.actions.suspend",
            "lock_and_suspend": "session.actions.lock-and-suspend",
            "reboot": "session.actions.reboot",
            "shutdown": "session.actions.shutdown",
            "hibernate": "session.actions.hibernate"
        }[a.action];
        var fallback = {
            "lock": "Lock",
            "logout": "Log Out",
            "suspend": "Suspend",
            "lock_and_suspend": "Lock & Suspend",
            "reboot": "Reboot",
            "shutdown": "Shut Down",
            "hibernate": "Hibernate"
        }[a.action] || "Custom";
        return key ? I18n.tr(key, fallback) : I18n.tr("session.actions.custom", fallback);
    }

    function glyph(a) {
        if (a.glyph)
            return a.glyph;
        return {
            "lock": "lock",
            "logout": "logout",
            "suspend": "suspend",
            "lock_and_suspend": "suspend",
            "reboot": "reboot",
            "shutdown": "shutdown",
            "hibernate": "hibernate"
        }[a.action] || "terminal";
    }

    function sh(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function lockCommand() {
        var custom = String(Config.get("x11.lock_command", ""));
        if (custom.length > 0)
            return custom;
        return "if command -v xflock4 >/dev/null 2>&1; then exec xflock4; " + "elif command -v light-locker-command >/dev/null 2>&1; then exec light-locker-command -l; " + "elif command -v xscreensaver-command >/dev/null 2>&1; then exec xscreensaver-command -lock; " + "elif command -v i3lock >/dev/null 2>&1; then exec i3lock -c 070722; " + "else exec loginctl lock-session; fi";
    }

    function lock() {
        Hooks.run("session_locked", {});
        sh(lockCommand());
    }

    function powerCommand(kind) {
        var overrides = Config.get("shell.session.power", {});
        if (overrides && overrides[kind])
            return String(overrides[kind]);
        if (hasXfceLogout && isXfce) {
            var flag = {
                "reboot": "--reboot",
                "shutdown": "--halt",
                "suspend": "--suspend",
                "hibernate": "--hibernate"
            }[kind];
            return "xfce4-session-logout " + flag + " --fast";
        }
        return {
            "reboot": "systemctl reboot",
            "shutdown": "systemctl poweroff",
            "suspend": "systemctl suspend",
            "hibernate": "systemctl hibernate"
        }[kind];
    }

    function logout() {
        Hooks.run("logging_out", {});
        var custom = String(Config.get("x11.logout_command", ""));
        if (custom.length > 0)
            sh(custom);
        else if (hasXfceLogout)
            sh("xfce4-session-logout --logout --fast");
        else
            sh("loginctl terminate-session \"${XDG_SESSION_ID:-self}\"");
    }

    function suspend() {
        sh(powerCommand("suspend"));
    }
    function hibernate() {
        sh(powerCommand("hibernate"));
    }
    function lockAndSuspend() {
        lock();
        suspendTimer.start();
    }
    function reboot() {
        Hooks.run("rebooting", {});
        sh(powerCommand("reboot"));
    }
    function shutdown() {
        Hooks.run("shutting_down", {});
        sh(powerCommand("shutdown"));
    }

    function run(a) {
        var action = typeof a === "string" ? a : a.action;
        aboutTo(action);
        if (typeof a === "object" && a.command && action !== "command") {
            sh(a.command);
            return;
        }
        switch (action) {
        case "lock": lock(); break;
        case "logout": logout(); break;
        case "suspend": suspend(); break;
        case "hibernate": hibernate(); break;
        case "lock_and_suspend":
        case "lock-and-suspend": lockAndSuspend(); break;
        case "reboot": reboot(); break;
        case "shutdown": shutdown(); break;
        case "command": if (a.command) sh(a.command); break;
        }
    }

    Timer {
        id: suspendTimer
        interval: 1200 // give the locker time to map before the machine sleeps
        onTriggered: root.suspend()
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v xfce4-session-logout"]
        onExited: (code, status) => root.hasXfceLogout = code === 0
    }
}
