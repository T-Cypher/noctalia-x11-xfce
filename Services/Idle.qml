pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Caffeine (idle inhibition) and [idle.behavior.*] timeouts on X11.
//  - Inhibition: xfce4-power-manager presentation mode (when present) + systemd-inhibit +
//    `xset s off -dpms`, all reverted when caffeine is turned off.
//  - Idle time: XScreenSaver extension, reported by the X11 bridge.
Singleton {
    id: root

    readonly property bool caffeine: ShellState.get("caffeine", false) === true
    readonly property var behaviors: {
        var b = Config.get("idle.behavior", {});
        var out = [];
        for (var name in b) {
            var e = b[name];
            if (!e || e.enabled === false)
                continue;
            var t = Number(e.timeout);
            if (!(t > 0))
                continue;
            out.push({
                name: name,
                timeout: t,
                action: String(e.action || "command").trim(),
                command: e.command || "",
                resume_command: e.resume_command || "",
                lock_before_suspend: e.lock_before_suspend !== false
            });
        }
        out.sort((a, b) => a.timeout - b.timeout);
        return out;
    }
    readonly property bool watching: behaviors.length > 0 && !caffeine
    property var fired: ({})
    property bool hasXfpm: false

    signal caffeineToggled(bool on)

    onWatchingChanged: X11.setIdleWatch(watching)
    Component.onCompleted: {
        X11.setIdleWatch(watching);
        if (caffeine)
            applyInhibit(true);
    }

    Connections {
        target: X11
        function onAvailableChanged() {
            if (X11.available)
                X11.setIdleWatch(root.watching);
        }
        function onIdleSecondsChanged() {
            root.evaluate(X11.idleSeconds);
        }
    }

    // [idle] pre_action_fade_seconds: fade a fullscreen overlay in before running an action;
    // any activity during the fade cancels it.
    readonly property real fadeSeconds: Math.max(0, Number(Config.get("idle.pre_action_fade_seconds", 2.0)))
    property var fading: null
    property real fadeProgress: 0
    property real lastSecs: 0
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "fadeProgress"
        from: 0
        to: 1
        duration: Math.max(1, root.fadeSeconds * 1000)
        onFinished: {
            var b = root.fading;
            root.fading = null;
            root.fadeProgress = 0;
            if (b)
                root.runAction(b);
        }
    }
    function cancelFade() {
        if (fading === null)
            return;
        fadeAnim.stop();
        var f = Object.assign({}, fired);
        delete f[fading.name];
        fired = f;
        fading = null;
        fadeProgress = 0;
    }

    function evaluate(secs) {
        var wentBack = secs < lastSecs;
        lastSecs = secs;
        if (!watching) {
            cancelFade();
            return;
        }
        if (fading !== null && (secs < 2 || wentBack))
            cancelFade();
        if (secs < 2) {
            // activity: run resume commands for fired behaviors and reset
            for (var name in fired) {
                var b = behaviors.find(x => x.name === name);
                if (b && b.resume_command)
                    Quickshell.execDetached(["sh", "-c", b.resume_command]);
                if (b && b.action === "screen_off")
                    Quickshell.execDetached(["xset", "dpms", "force", "on"]);
            }
            if (Object.keys(fired).length > 0)
                fired = {};
            return;
        }
        for (var i = 0; i < behaviors.length; i++) {
            var be = behaviors[i];
            if (secs >= be.timeout && !fired[be.name] && fading === null) {
                var f = Object.assign({}, fired);
                f[be.name] = true;
                fired = f;
                if (fadeSeconds > 0) {
                    fading = be;
                    fadeAnim.restart();
                } else {
                    runAction(be);
                }
            }
        }
    }

    function runAction(b) {
        switch (b.action) {
        case "lock":
            Session.lock();
            break;
        case "screen_off":
            Quickshell.execDetached(["xset", "dpms", "force", "off"]);
            break;
        case "suspend":
            // lock_before_suspend (default true): lock first so the session is protected on resume
            if (b.lock_before_suspend !== false)
                Session.lockAndSuspend();
            else
                Session.suspend();
            break;
        case "lock_and_suspend":
            Session.lockAndSuspend();
            break;
        default:
            if (b.command)
                Quickshell.execDetached(["sh", "-c", b.command]);
        }
    }

    function setCaffeine(on) {
        ShellState.set("caffeine", on === true);
        applyInhibit(on === true);
        caffeineToggled(on === true);
    }

    function toggleCaffeine() {
        setCaffeine(!caffeine);
    }

    function applyInhibit(on) {
        inhibitor.running = on;
        if (hasXfpm)
            Quickshell.execDetached(["xfconf-query", "-c", "xfce4-power-manager", "-p", "/xfce4-power-manager/presentation-mode", "-n", "-t", "bool", "-s", on ? "true" : "false"]);
        Quickshell.execDetached(["sh", "-c", on ? "xset s off -dpms" : "xset s on +dpms"]);
    }

    // Holds a logind idle/sleep inhibitor while caffeine is on
    Process {
        id: inhibitor
        command: ["sh", "-c", "command -v systemd-inhibit >/dev/null && exec systemd-inhibit --what=idle:sleep --who=Noctalia --why='Caffeine is on' --mode=block sleep infinity"]
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v xfconf-query >/dev/null && xfconf-query -c xfce4-power-manager -l >/dev/null 2>&1"]
        onExited: (code, status) => root.hasXfpm = code === 0
    }
}
