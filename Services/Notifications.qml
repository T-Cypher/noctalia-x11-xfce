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
    readonly property int maxHistory: 100            // noctalia's kMaxHistoryEntries
    readonly property int defaultTimeout: 6000       // noctalia's kDefaultNotificationTimeout
    readonly property int retentionHours: Math.max(0, Number(Config.get("notification.history_retention_hours", 0)))
    readonly property bool keepDismissed: Config.get("notification.keep_dismissed_in_history", true) !== false
    property int unread: ShellState.get("notifications_unread", 0)
    property int nextInternalId: 1000000
    property string targetScreen: ""   // focused screen when the latest toast arrived

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

    // Freedesktop expire_timeout: 0 = persistent, -1 = server default, > 0 = milliseconds.
    function normalizeTimeout(t) {
        var v = Number(t);
        if (v === 0)
            return 0;
        return v < 0 || isNaN(v) ? defaultTimeout : v;
    }

    // [notification.filter.*] (ordered by filter_order, then by name) or the legacy
    // `blacklist` array; noctalia's notification_filter.cpp semantics.
    readonly property var filters: {
        var tbl = Config.get("notification.filter", {});
        var names = Object.keys(tbl).filter(k => tbl[k] && typeof tbl[k] === "object").sort();
        var order = Config.get("notification.filter_order", []);
        var ordered = [];
        if (Array.isArray(order))
            for (var i = 0; i < order.length; i++)
                if (names.indexOf(order[i]) >= 0 && ordered.indexOf(order[i]) < 0)
                    ordered.push(order[i]);
        for (var j = 0; j < names.length; j++)
            if (ordered.indexOf(names[j]) < 0)
                ordered.push(names[j]);
        var globalUrgencies = Config.get("notification.allowed_urgencies", []);
        var out = ordered.map(function (n) {
            var f = Object.assign({}, tbl[n]);
            if (!f.match && Array.isArray(f.matches))
                f.match = f.matches.find(x => String(x).trim() !== "") || "";
            if ((!Array.isArray(f.allowed_urgencies) || f.allowed_urgencies.length === 0) && Array.isArray(globalUrgencies))
                f.allowed_urgencies = globalUrgencies;
            return f;
        });
        var bl = Config.get("notification.blacklist", []);
        if (out.length === 0 && Array.isArray(bl))
            for (var b = 0; b < bl.length; b++)
                if (String(bl[b]).trim() !== "")
                    out.push({
                        match: String(bl[b]),
                        show_toast: false,
                        save_history: false,
                        play_sound: false
                    });
        return out;
    }

    function matchesToken(token, appName, desktopEntry, category) {
        var t = String(token || "").trim().toLowerCase();
        if (t === "")
            return false;
        var app = String(appName || "").trim().toLowerCase();
        var de = String(desktopEntry || "").trim().toLowerCase();
        var cat = String(category || "").trim().toLowerCase();
        if (t === app || (cat !== "" && t === cat) || (de !== "" && t === de))
            return true;
        return app !== "" && app.indexOf(t) >= 0;
    }

    function filterFor(appName, desktopEntry, category, summary, body) {
        for (var i = 0; i < filters.length; i++) {
            var f = filters[i];
            if (f.enabled === false || (!f.match && !f.match_content))
                continue;
            if (f.match && !matchesToken(f.match, appName, desktopEntry, category))
                continue;
            if (f.match_content) {
                try {
                    var re = new RegExp(String(f.match_content), "i");
                    if (!re.test(String(summary || "")) && !re.test(String(body || "")))
                        continue;
                } catch (e) {
                    continue;
                }
            }
            return f;
        }
        return null;
    }

    function pruneHistory() {
        if (retentionHours <= 0)
            return;
        var cutoff = Date.now() - retentionHours * 3600 * 1000;
        var changed = false;
        for (var i = history.count - 1; i >= 0; i--) {
            if (history.get(i).time < cutoff) {
                history.remove(i);
                changed = true;
            }
        }
        if (changed)
            saveTimer.restart();
    }

    function addEntry(entry, showToast, saveHistory) {
        if (saveHistory) {
            history.insert(0, entry);
            while (history.count > maxHistory)
                history.remove(history.count - 1);
            pruneHistory();
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
            var aw = X11.activeWindow;
            var scr = aw ? X11.screenOf(aw) : null;
            targetScreen = scr ? scr.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            toasts.insert(0, entry);
            // max_visible = 0: unlimited (Toasts shows as many as fit on the screen)
            var maxVisible = Number(Config.get("notification.max_visible", 0));
            while (maxVisible > 0 && toasts.count > maxVisible)
                toasts.remove(toasts.count - 1);
            toastAdded();
        }
    }

    function handle(n) {
        var urgency = urgencyName(n.urgency);
        var category = n.hints && n.hints.category ? String(n.hints.category) : "";
        var filter = filterFor(n.appName, n.desktopEntry, category, n.summary, n.body);
        if (filter && Array.isArray(filter.allowed_urgencies) && filter.allowed_urgencies.length > 0 && filter.allowed_urgencies.map(u => String(u).toLowerCase()).indexOf(urgency) < 0) {
            n.dismiss();
            return;
        }
        var showToastAllowed = !(filter && filter.show_toast === false);
        var saveAllowed = !(filter && filter.save_history === false) && !n.transient && urgency !== "low";
        if (!showToastAllowed && !saveAllowed) {
            n.dismiss();
            return;
        }
        n.tracked = true;
        objects[n.id] = n;
        var actions = [];
        if (n.actions)
            for (var i = 0; i < n.actions.length; i++)
                actions.push({
                    identifier: n.actions[i].identifier,
                    text: n.actions[i].text
                });
        var timeout = normalizeTimeout(n.expireTimeout);
        if (filter && filter.override_duration !== undefined)
            timeout = normalizeTimeout(filter.override_duration);
        if (timeout === 0 && filter && filter.allow_permanent === false)
            timeout = defaultTimeout;
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
        addEntry(entry, showToastAllowed && (!dnd || bypass), saveAllowed);
        n.closed.connect(function () {
            root.removeToast(entry.nid);
            delete root.objects[entry.nid];
        });
    }

    // Shell-originated notification (no D-Bus round trip), e.g. errors or `notification-show`.
    // Like noctalia, internal notifications are toast-only unless `persist` opts into history.
    function notifyInternal(summary, body, glyph, urgency, timeoutMs, persist, bypassDnd) {
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
            timeout: timeoutMs !== undefined && timeoutMs !== null ? timeoutMs : defaultTimeout,
            actionsJson: "[]",
            glyph: glyph || "toast-notice",
            internal: true
        };
        addEntry(entry, !dnd || bypassDnd === true, persist === true && entry.urgency !== "low");
        return entry.nid;
    }

    // Config errors: one persistent critical notification, replaced on every new error and
    // dismissed once the configuration is valid again (noctalia's setConfigParseError).
    property int configErrorId: 0
    Connections {
        target: Config
        function onLastErrorChanged() {
            if (root.configErrorId !== 0) {
                root.removeToast(root.configErrorId);
                root.configErrorId = 0;
            }
            if (Config.lastError === "")
                return;
            var located = Config.lastErrorTitle !== "";
            root.configErrorId = root.notifyInternal(located ? Config.lastErrorTitle : "Config error", located ? "Error: " + Config.lastError : Config.lastError, "toast-error", "critical", 0, false, true);
        }
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
                root.pruneHistory();
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
