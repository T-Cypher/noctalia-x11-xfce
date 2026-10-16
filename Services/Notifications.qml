pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons

// org.freedesktop.Notifications daemon (replaces xfce4-notifyd), toast queue, history and DND.
Singleton {
    id: root

    readonly property bool daemonEnabled: Config.get("notification.enable_daemon", true) !== false
    readonly property bool dnd: ShellState.get("dnd", false) === true
    readonly property int maxHistory: Math.max(10, Number(Config.get("notification.history_max_entries", 100)))
    readonly property int defaultTimeout: Number(Config.get("notification.default_timeout_ms", 5000))
    readonly property bool keepDismissed: Config.get("notification.keep_dismissed_in_history", true) !== false
    property int unread: ShellState.get("notifications_unread", 0)
    property int nextInternalId: 1000000

    // live toasts and history (newest first)
    property ListModel toasts: ListModel {}
    property ListModel history: ListModel {}
    property var objects: ({})       // id -> Notification object (for actions)

    signal toastAdded
    signal dndToggled(bool on)

    function setDnd(on) {
        ShellState.set("dnd", on === true);
        dndToggled(on === true);
    }
    function toggleDnd() {
        setDnd(!dnd);
    }

    function markRead() {
        unread = 0;
        ShellState.set("notifications_unread", 0);
    }

    function urgencyName(u) {
        if (u === NotificationUrgency.Low)
            return "low";
        if (u === NotificationUrgency.Critical)
            return "critical";
        return "normal";
    }

    // [notification.filter.*] rules (match app name or desktop entry substring)
    function filterFor(appName, desktopEntry) {
        var filters = Config.get("notification.filter", {});
        var a = String(appName || "").toLowerCase();
        var d = String(desktopEntry || "").toLowerCase();
        for (var key in filters) {
            var f = filters[key];
            if (!f || f.enabled === false)
                continue;
            var m = String(f.match !== undefined ? f.match : key).toLowerCase();
            if (m.length > 0 && (a.indexOf(m) >= 0 || d.indexOf(m) >= 0))
                return f;
        }
        return null;
    }

    function addEntry(entry, showToast, saveHistory) {
        if (saveHistory) {
            history.insert(0, entry);
            while (history.count > maxHistory)
                history.remove(history.count - 1);
            unread++;
            ShellState.set("notifications_unread", unread);
            saveTimer.restart();
        }
        if (showToast) {
            // replace an existing toast with the same id
            for (var i = 0; i < toasts.count; i++) {
                if (toasts.get(i).nid === entry.nid) {
                    toasts.set(i, entry);
                    return;
                }
            }
            toasts.insert(0, entry);
            var maxVisible = Math.max(1, Number(Config.get("notification.max_visible", 5)));
            while (toasts.count > maxVisible)
                toasts.remove(toasts.count - 1);
            toastAdded();
        }
    }

    function handle(n) {
        var filter = filterFor(n.appName, n.desktopEntry);
        var urgency = urgencyName(n.urgency);
        if (filter && Array.isArray(filter.allowed_urgencies) && filter.allowed_urgencies.length > 0 && filter.allowed_urgencies.indexOf(urgency) < 0)
            return;
        n.tracked = true;
        objects[n.id] = n;
        var actions = [];
        if (n.actions)
            for (var i = 0; i < n.actions.length; i++)
                actions.push({
                    identifier: n.actions[i].identifier,
                    text: n.actions[i].text
                });
        var timeout = n.expireTimeout > 0 ? n.expireTimeout : (urgency === "critical" ? Number(Config.get("notification.critical_timeout_ms", 0)) : defaultTimeout);
        var entry = {
            nid: n.id,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: n.image || "",
            desktopEntry: n.desktopEntry || "",
            urgency: urgency,
            time: Date.now(),
            timeout: timeout,
            actionsJson: JSON.stringify(actions),
            glyph: "",
            internal: false
        };
        var bypass = filter && filter.bypass_dnd === true;
        var showToast = (!dnd || urgency === "critical" || bypass) && !(filter && filter.show_toast === false);
        var saveHistory = !(filter && filter.save_history === false) && !n.transient;
        addEntry(entry, showToast, saveHistory);
        n.closed.connect(function () {
            root.removeToast(entry.nid);
            delete root.objects[entry.nid];
        });
    }

    // Shell-originated notification (no D-Bus round trip), e.g. errors or `notification-show`
    function notifyInternal(summary, body, glyph, urgency, timeoutMs) {
        var entry = {
            nid: nextInternalId++,
            summary: summary || "",
            body: body || "",
            appName: "Noctalia",
            appIcon: "",
            image: "",
            desktopEntry: "",
            urgency: urgency || "normal",
            time: Date.now(),
            timeout: timeoutMs !== undefined ? timeoutMs : defaultTimeout,
            actionsJson: "[]",
            glyph: glyph || "toast-notice",
            internal: true
        };
        addEntry(entry, !dnd || entry.urgency === "critical", true);
        return entry.nid;
    }

    function removeToast(nid) {
        for (var i = 0; i < toasts.count; i++) {
            if (toasts.get(i).nid === nid) {
                toasts.remove(i);
                return;
            }
        }
    }

    // User dismissed a toast
    function dismiss(nid) {
        removeToast(nid);
        var n = objects[nid];
        if (n) {
            n.dismiss();
            delete objects[nid];
        }
        if (!keepDismissed)
            removeHistory(nid);
    }

    // Toast timed out
    function expire(nid) {
        removeToast(nid);
        var n = objects[nid];
        if (n)
            n.expire();
    }

    function invoke(nid, identifier) {
        var n = objects[nid];
        if (n && n.actions) {
            for (var i = 0; i < n.actions.length; i++) {
                if (n.actions[i].identifier === identifier) {
                    n.actions[i].invoke();
                    break;
                }
            }
        }
        removeToast(nid);
    }

    function invokeDefault(nid) {
        var n = objects[nid];
        if (n && n.actions && n.actions.length > 0) {
            var chosen = n.actions[0];
            for (var i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier === "default")
                    chosen = n.actions[i];
            chosen.invoke();
        }
        removeToast(nid);
    }

    function invokeLatest() {
        if (toasts.count > 0)
            invokeDefault(toasts.get(0).nid);
        else if (history.count > 0)
            invokeDefault(history.get(0).nid);
    }

    function clearActive() {
        for (var i = toasts.count - 1; i >= 0; i--) {
            var nid = toasts.get(i).nid;
            var n = objects[nid];
            if (n)
                n.dismiss();
        }
        toasts.clear();
    }

    function removeHistory(nid) {
        for (var i = 0; i < history.count; i++) {
            if (history.get(i).nid === nid) {
                history.remove(i);
                saveTimer.restart();
                return;
            }
        }
    }

    function clearHistory() {
        history.clear();
        markRead();
        saveTimer.restart();
    }

    function saveHistory() {
        var arr = [];
        for (var i = 0; i < history.count; i++) {
            var e = history.get(i);
            arr.push({
                nid: e.nid,
                summary: e.summary,
                body: e.body,
                appName: e.appName,
                appIcon: e.appIcon,
                image: String(e.image).indexOf("image://") === 0 ? "" : e.image,
                desktopEntry: e.desktopEntry,
                urgency: e.urgency,
                time: e.time,
                timeout: 0,
                actionsJson: "[]",
                glyph: e.glyph,
                internal: e.internal
            });
        }
        historyFile.setText(JSON.stringify(arr));
    }

    Timer {
        id: saveTimer
        interval: 1500
        onTriggered: if (ShellState.dirsReady)
            root.saveHistory()
        else
            restart()
    }

    FileView {
        id: historyFile
        path: Config.stateDir + "/notifications.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                var arr = JSON.parse(text());
                root.history.clear();
                for (var i = 0; i < arr.length && i < root.maxHistory; i++)
                    root.history.append(arr[i]);
            } catch (e) {}
        }
    }

    LazyLoader {
        active: root.daemonEnabled
        NotificationServer {
            keepOnReload: false
            actionsSupported: Config.get("notification.show_actions", true) !== false
            actionIconsSupported: false
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: false
            imageSupported: true
            persistenceSupported: true
            inlineReplySupported: false
            onNotification: n => root.handle(n)
        }
    }
}
