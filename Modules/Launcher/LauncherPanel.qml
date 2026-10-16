pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

// noctalia launcher: "full" layout (toolbar + views Recent/Pinned/All/Categories/Providers) or
// "simple" layout (search + category chips). Providers: apps, calculator (global), /emo, /win,
// /session, /wall, /pan, and "/" for the provider overview.
Item {
    id: root

    required property var screenRef

    readonly property bool simple: String(Config.get("shell.launcher.layout", "full")) === "simple"
    readonly property bool searchBottom: !simple && String(Config.get("shell.launcher.search_position", "top")) === "bottom"
    readonly property string prefix: String(Config.get("shell.launcher.provider_prefix", "/"))
    readonly property var providers: Config.get("shell.launcher.providers", {})
    property bool grid: ShellState.get("launcher_grid", Config.get("shell.launcher.app_grid", false) === true)
    property bool sortByUsage: ShellState.get("launcher_sort_usage", Config.get("shell.launcher.sort_by_usage", true) !== false)
    readonly property bool trackUsage: Config.get("shell.launcher.track_usage", true) !== false
    readonly property var pinnedIds: {
        var p = Config.get("shell.launcher.pinned", []);
        var s = ShellState.get("launcher_pinned", null);
        return s !== null ? s : (Array.isArray(p) ? p : []);
    }

    property string query: Panels.context
    property string view: {
        var v = String(Config.get("shell.launcher.default_view", "recent"));
        if (v === "pinned" && pinnedIds.length === 0)
            return "all";
        if (v === "recent" && Apps.recent.length === 0)
            return "all";
        return v;
    }
    property string category: ""
    property int selected: 0
    property point lastHover: Qt.point(-1, -1)
    property var emojis: []

    // Only follow the pointer when it really moves (delegates recreated under a still cursor
    // must not steal the keyboard selection).
    function hoverAt(item, mx, my, index) {
        var p = item.mapToItem(root, mx, my);
        if (lastHover.x < 0) {
            lastHover = p;
            return;
        }
        if (Math.abs(p.x - lastHover.x) + Math.abs(p.y - lastHover.y) > 3) {
            lastHover = p;
            selected = index;
        }
    }
    property var emojiUsage: ShellState.get("emoji_usage", ({}))

    implicitWidth: Math.round((simple ? 560 : Math.max(560, Math.min(1100, Number(Config.get("shell.launcher.width", 760))))) * Style.uiScale)
    implicitHeight: Math.round((simple ? 500 : 620) * Style.uiScale)

    function focusFirst() {
        search.focusInput();
    }

    // ---------------------------------------------------------------- data
    FileView {
        path: (Quickshell.shellDir + "/assets/emoji.json")
        blockLoading: false
        onLoaded: {
            try {
                root.emojis = JSON.parse(text());
            } catch (e) {}
        }
    }

    readonly property var categories: {
        var map = {
            "AudioVideo": ["Multimedia", "device-tv"],
            "Audio": ["Multimedia", "device-tv"],
            "Video": ["Multimedia", "device-tv"],
            "Development": ["Development", "code"],
            "Education": ["Education", "school"],
            "Game": ["Games", "device-gamepad-2"],
            "Graphics": ["Graphics", "palette"],
            "Network": ["Internet", "world"],
            "Office": ["Office", "file-text"],
            "Science": ["Science", "flask"],
            "Settings": ["Settings", "settings"],
            "System": ["System", "device-desktop"],
            "Utility": ["Utilities", "tool"]
        };
        var found = {};
        var out = [];
        Apps.all.forEach(a => {
            (a.categories || []).forEach(c => {
                var m = map[c];
                if (m && !found[m[0]]) {
                    found[m[0]] = true;
                    out.push({
                        key: m[0],
                        glyph: m[1],
                        members: Object.keys(map).filter(k => map[k][0] === m[0])
                    });
                }
            });
        });
        return out.sort((x, y) => x.key.localeCompare(y.key));
    }

    function inCategory(app, cat) {
        if (!cat)
            return true;
        var c = categories.find(x => x.key === cat);
        if (!c)
            return true;
        return (app.categories || []).some(k => c.members.indexOf(k) >= 0);
    }

    function appItem(a, score) {
        return {
            kind: "app",
            title: a.name,
            subtitle: a.genericName || a.comment || "",
            icon: Apps.iconFor(a),
            glyph: "app-window",
            score: score || 0,
            pinned: pinnedIds.indexOf(a.id) >= 0,
            entry: a,
            run: function () {
                Apps.launch(a);
            }
        };
    }

    function providerKey(q) {
        if (q.indexOf(prefix) !== 0)
            return "";
        var rest = q.slice(prefix.length);
        var keys = ["calculator", "emoji", "session", "wallpaper", "windows", "panels"];
        for (var i = 0; i < keys.length; i++) {
            var p = providers[keys[i]] || {};
            var pre = String(p.prefix || ({
                    calculator: "calc",
                    emoji: "emo",
                    session: "session",
                    wallpaper: "wall",
                    windows: "win",
                    panels: "pan"
                })[keys[i]]);
            if (rest === pre || rest.indexOf(pre + " ") === 0)
                return keys[i] + "|" + rest.slice(pre.length).trim();
        }
        return rest.length === 0 || rest.indexOf(" ") < 0 ? "overview|" + rest : "";
    }

    readonly property var results: {
        var q = query;
        var out = [];
        var pk = providerKey(q);
        if (pk !== "") {
            var parts = pk.split("|");
            var kind = parts[0], arg = parts.slice(1).join("|");
            switch (kind) {
            case "overview":
                return providerOverview(arg);
            case "calculator":
                var v = Util.calculate(arg);
                return v === null ? [] : [calcItem(arg, v)];
            case "emoji":
                return emojiResults(arg);
            case "session":
                return Session.actions.map(a => ({
                            kind: "session",
                            title: Session.label(a),
                            subtitle: "",
                            glyph: Session.glyph(a),
                            score: Util.fuzzyScore(arg, Session.label(a)),
                            run: function () {
                                Session.run(a);
                            }
                        })).filter(r => arg === "" || r.score >= 0);
            case "wallpaper":
                return Wallpaper.files.map(f => ({
                            kind: "wallpaper",
                            title: Util.basename(f),
                            subtitle: f,
                            image: "file://" + f,
                            glyph: "photo",
                            score: Util.fuzzyScore(arg, f),
                            run: function () {
                                Wallpaper.set("*", f);
                            }
                        })).filter(r => arg === "" || r.score >= 0).sort((a, b) => b.score - a.score).slice(0, 200);
            case "windows":
                return X11.windows.map(w => ({
                            kind: "window",
                            title: w.title || w.appId,
                            subtitle: w.appId + "  ·  " + I18n.tr("launcher.workspace", "Workspace") + " " + (w.desktop < 0 ? "*" : w.desktop + 1),
                            icon: Apps.iconForClass(w.appId, w.instance),
                            glyph: "app-window",
                            score: Math.max(Util.fuzzyScore(arg, w.title), Util.fuzzyScore(arg, w.appId)),
                            run: function () {
                                X11.activate(w.id);
                            }
                        })).filter(r => arg === "" || r.score >= 0).sort((a, b) => b.score - a.score);
            case "panels":
                var panels = [["launcher", "Launcher", "search"], ["control-center", "Control Center", "noctalia"], ["session", "Session", "power"], ["wallpaper", "Wallpaper", "wallpaper-selector"], ["clipboard", "Clipboard", "clipboard"]];
                var tabs = ["media", "audio", "monitor", "system", "network", "bluetooth", "weather", "calendar", "notifications", "power"];
                var items = panels.filter(p => p[0] !== "launcher").map(p => ({
                            kind: "panel",
                            title: p[1],
                            subtitle: "panel-toggle " + p[0],
                            glyph: p[2],
                            score: Util.fuzzyScore(arg, p[1]),
                            run: function () {
                                Qt.callLater(() => Panels.open(p[0], root.screenRef, "", null, null, null));
                            }
                        }));
                tabs.forEach(t => items.push({
                        kind: "panel",
                        title: "Control Center › " + t.charAt(0).toUpperCase() + t.slice(1),
                        subtitle: "panel-toggle control-center " + t,
                        glyph: "noctalia",
                        score: Util.fuzzyScore(arg, t),
                        run: function () {
                            Qt.callLater(() => Panels.open("control-center", root.screenRef, t, null, null, null));
                        }
                    }));
                return items.filter(r => arg === "" || r.score >= 0).sort((a, b) => b.score - a.score);
            }
            return [];
        }

        if (q.trim() === "") {
            var list;
            if (view === "recent")
                list = Apps.recent.map(id => Apps.byId(id)).filter(a => a && !a.noDisplay);
            else if (view === "pinned")
                list = pinnedIds.map(id => Apps.byId(id)).filter(a => a);
            else if (view === "providers")
                return providerOverview("");
            else {
                list = Apps.all.filter(a => view !== "categories" || inCategory(a, category));
                if (sortByUsage && trackUsage)
                    list = list.slice().sort((a, b) => Apps.usageCount(b) - Apps.usageCount(a) || String(a.name).localeCompare(String(b.name)));
            }
            if (simple && category !== "") {
                list = category === "__recent" ? Apps.recent.map(id => Apps.byId(id)).filter(a => a) : Apps.all.filter(a => inCategory(a, category));
            }
            return list.map(a => appItem(a, 0));
        }

        // global search: apps (+ calculator)
        Apps.all.forEach(a => {
            var s = Math.max(Util.fuzzyScore(q, a.name), Util.fuzzyScore(q, a.genericName) - 50, Util.fuzzyScore(q, (a.keywords || []).join(" ")) - 80, Util.fuzzyScore(q, a.id) - 100);
            if (s >= 0) {
                if (trackUsage && sortByUsage)
                    s += Math.min(200, Apps.usageCount(a) * 15);
                out.push(appItem(a, s));
            }
        });
        out.sort((a, b) => b.score - a.score);
        var calcGlobal = (providers.calculator || {}).global !== false;
        if (calcGlobal && Util.looksLikeMath(q)) {
            var cv = Util.calculate(q);
            if (cv !== null)
                out.unshift(calcItem(q, cv));
        }
        return out.slice(0, 120);
    }

    function calcItem(expr, value) {
        var text = Util.formatNumber(value);
        return {
            kind: "calc",
            title: "= " + text,
            subtitle: expr + "  ·  " + I18n.tr("launcher.calculator.copy", "Enter to copy"),
            glyph: "calculator",
            score: 10000,
            run: function () {
                Clipboard.copy(text);
            }
        };
    }

    function emojiResults(arg) {
        var a = arg.toLowerCase();
        var list = emojis.filter(e => a === "" || e.name.indexOf(a) >= 0 || (e.keywords || []).some(k => k.indexOf(a) >= 0) || e.category.indexOf(a) >= 0);
        if (a === "" && trackUsage)
            list = list.slice().sort((x, y) => (emojiUsage[y.emoji] || 0) - (emojiUsage[x.emoji] || 0));
        return list.slice(0, 300).map(e => ({
                    kind: "emoji",
                    title: e.name,
                    subtitle: e.category,
                    emoji: e.emoji,
                    score: 0,
                    run: function () {
                        var u = Object.assign({}, root.emojiUsage);
                        u[e.emoji] = (u[e.emoji] || 0) + 1;
                        ShellState.set("emoji_usage", u);
                        Clipboard.copy(e.emoji);
                        if (String(Config.get("shell.launcher.auto_paste", "auto")) !== "off")
                            Clipboard.pasteSoon();
                    }
                }));
    }

    function providerOverview(filter) {
        var defs = [["calculator", "calc", "calculator", I18n.tr("launcher.providers.calculator.title", "Calculator")], ["emoji", "emo", "mood-smile", I18n.tr("launcher.providers.emoji.title", "Emoji")], ["windows", "win", "app-window", I18n.tr("launcher.providers.window.title", "Windows")], ["session", "session", "power", I18n.tr("launcher.providers.session.title", "Session")], ["wallpaper", "wall", "wallpaper-selector", I18n.tr("launcher.providers.wallpaper.title", "Wallpaper")], ["panels", "pan", "layout-dashboard", I18n.tr("launcher.providers.panel.title", "Panels")]];
        return defs.map(d => {
            var pre = String((providers[d[0]] || {}).prefix || d[1]);
            return {
                kind: "provider",
                title: d[3],
                subtitle: root.prefix + pre,
                glyph: d[2],
                score: Util.fuzzyScore(filter, pre + " " + d[3]),
                run: function () {
                    search.text = root.prefix + pre + " ";
                    search.focusInput();
                },
                keepOpen: true
            };
        }).filter(r => filter === "" || r.score >= 0);
    }

    onResultsChanged: selected = 0
    onQueryChanged: selected = 0

    function activate(index) {
        var r = results[index];
        if (!r)
            return;
        r.run();
        if (!r.keepOpen)
            Panels.close();
    }

    function togglePin(entry) {
        var p = pinnedIds.slice();
        var i = p.indexOf(entry.id);
        if (i >= 0)
            p.splice(i, 1);
        else
            p.push(entry.id);
        ShellState.set("launcher_pinned", p);
    }

    readonly property bool gridMode: grid && results.length > 0 && results[0].kind === "app"
    readonly property int columns: gridMode ? Math.max(3, Math.floor(gridView.width / (112 * Style.uiScale))) : 1

    function move(delta) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
        if (gridMode)
            gridView.positionViewAtIndex(selected, GridView.Contain);
        else
            listView.positionViewAtIndex(selected, ListView.Contain);
    }

    // ---------------------------------------------------------------- layout
    Column {
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spaceMd

        // toolbar (search position "top")
        Loader {
            width: parent.width
            active: !root.searchBottom
            visible: active
            sourceComponent: toolbarComp
        }

        // view tabs (full layout) / category chips (simple layout)
        Item {
            id: tabsRow
            width: parent.width
            height: Style.controlHeightSm
            visible: root.query.trim() === "" || root.simple

            Row {
                spacing: Style.spaceXs
                visible: !root.simple
                Repeater {
                    model: [
                        { id: "recent", glyph: "history", label: I18n.tr("launcher.browser.navigation.recent", "Recent"), show: Apps.recent.length > 0 },
                        { id: "pinned", glyph: "pin", label: I18n.tr("launcher.browser.navigation.pinned", "Pinned"), show: root.pinnedIds.length > 0 },
                        { id: "all", glyph: "apps", label: I18n.tr("launcher.browser.navigation.all", "All"), show: true },
                        { id: "categories", glyph: "category", label: I18n.tr("launcher.browser.navigation.categories", "Categories"), show: root.categories.length > 0 },
                        { id: "providers", glyph: "layout-dashboard", label: I18n.tr("launcher.browser.navigation.providers", "Providers"), show: true }
                    ].filter(t => t.show)
                    delegate: NButton {
                        required property var modelData
                        height: Style.controlHeightSm
                        icon: modelData.glyph
                        text: root.width >= 680 * Style.uiScale ? modelData.label : ""
                        fontSize: Style.fontSizeCaption
                        variant: root.view === modelData.id && root.query === "" ? "tabActive" : "tab"
                        onClicked: {
                            root.view = modelData.id;
                            if (modelData.id === "categories" && root.category === "" && root.categories.length > 0)
                                root.category = root.categories[0].key;
                            search.text = "";
                            search.focusInput();
                        }
                    }
                }
            }

            Flickable {
                visible: root.simple && Config.get("shell.launcher.categories", true) !== false
                anchors.fill: parent
                contentWidth: chips.width
                clip: true
                Row {
                    id: chips
                    spacing: Style.spaceXs
                    Repeater {
                        model: [{ key: "", glyph: "apps", label: I18n.tr("launcher.browser.navigation.all", "All") }, { key: "__recent", glyph: "history", label: I18n.tr("launcher.browser.navigation.recent", "Recent") }].concat(root.categories.map(c => ({ key: c.key, glyph: c.glyph, label: c.key })))
                        delegate: NButton {
                            required property var modelData
                            height: Style.controlHeightSm
                            icon: modelData.glyph
                            text: Config.get("shell.launcher.category_icons_only", false) === true ? "" : modelData.label
                            fontSize: Style.fontSizeCaption
                            variant: root.category === modelData.key ? "tabActive" : "tab"
                            onClicked: root.category = modelData.key
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                visible: !root.simple
                spacing: Style.spaceXs
                NIconButton {
                    visible: root.trackUsage && (root.view === "all" || root.view === "categories")
                    icon: root.sortByUsage ? "sort-ascending-letters" : "chart-bar"
                    variant: "ghost"
                    onClicked: {
                        root.sortByUsage = !root.sortByUsage;
                        ShellState.set("launcher_sort_usage", root.sortByUsage);
                    }
                }
                NIconButton {
                    icon: root.grid ? "list" : "layout-grid"
                    variant: "ghost"
                    onClicked: {
                        root.grid = !root.grid;
                        ShellState.set("launcher_grid", root.grid);
                    }
                }
            }
        }

        // category row for the Categories view
        Flickable {
            id: catRow
            width: parent.width
            height: Style.controlHeightSm
            visible: !root.simple && root.view === "categories" && root.query.trim() === ""
            contentWidth: catRowInner.width
            clip: true
            Row {
                id: catRowInner
                spacing: Style.spaceXs
                Repeater {
                    model: root.categories
                    delegate: NButton {
                        required property var modelData
                        height: Style.controlHeightSm
                        icon: modelData.glyph
                        text: Config.get("shell.launcher.category_icons_only", false) === true ? "" : modelData.key
                        fontSize: Style.fontSizeCaption
                        variant: root.category === modelData.key ? "secondary" : "ghost"
                        onClicked: root.category = modelData.key
                    }
                }
            }
        }

        // results
        Item {
            width: parent.width
            height: parent.height - y - (root.searchBottom ? Style.controlHeightLg + parent.spacing : 0)

            ListView {
                id: listView
                anchors.fill: parent
                visible: !root.gridMode
                clip: true
                spacing: 2
                model: root.gridMode ? [] : root.results
                currentIndex: root.selected
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: listView.width - Style.spaceMd
                    height: Style.controlHeightLg + (modelData.kind === "wallpaper" ? 16 : 4)
                    radius: Style.radiusLg
                    color: index === root.selected ? Theme.alpha(Theme.primary, 0.16) : (rowMouse.containsMouse ? Theme.alpha(Theme.hover, 0.12) : "transparent")
                    border.color: index === root.selected ? Theme.alpha(Theme.primary, 0.6) : "transparent"
                    border.width: 1

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.spaceMd
                        anchors.right: parent.right
                        anchors.rightMargin: Style.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.spaceMd

                        Item {
                            width: row.modelData.kind === "wallpaper" ? 64 * Style.uiScale : 28 * Style.uiScale
                            height: row.modelData.kind === "wallpaper" ? 40 * Style.uiScale : 28 * Style.uiScale
                            anchors.verticalCenter: parent.verticalCenter
                            NAppIcon {
                                anchors.fill: parent
                                visible: row.modelData.icon !== undefined && row.modelData.icon !== ""
                                source: row.modelData.icon || ""
                                fallbackGlyph: row.modelData.glyph || "app-window"
                            }
                            NIcon {
                                anchors.centerIn: parent
                                visible: (row.modelData.icon === undefined || row.modelData.icon === "") && row.modelData.emoji === undefined && row.modelData.image === undefined
                                icon: row.modelData.glyph || "point"
                                size: parent.height * 0.8
                                color: row.modelData.kind === "calc" ? Theme.primary : Theme.fgSurface
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: row.modelData.emoji !== undefined
                                text: row.modelData.emoji || ""
                                font.pixelSize: parent.height * 0.85
                            }
                            NRoundedImage {
                                anchors.fill: parent
                                visible: row.modelData.image !== undefined
                                source: row.modelData.image || ""
                                radius: Style.radiusMd
                            }
                        }

                        Column {
                            width: parent.width - 64 * Style.uiScale - Style.spaceMd * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            NText {
                                width: parent.width
                                text: row.modelData.title
                                weight: row.index === root.selected ? Font.Bold : Font.Medium
                                size: row.modelData.kind === "calc" ? Style.fontSizeTitle : Style.fontSizeBody
                            }
                            NText {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.subtitle || ""
                                size: Style.fontSizeCaption
                                muted: true
                            }
                        }
                    }

                    NIcon {
                        visible: row.modelData.pinned === true
                        icon: "pinned"
                        size: Style.fontSizeCaption
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.rightMargin: Style.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && row.modelData.kind === "app")
                                root.togglePin(row.modelData.entry);
                            else
                                root.activate(row.index);
                        }
                        onPositionChanged: mouse => root.hoverAt(rowMouse, mouse.x, mouse.y, row.index)
                    }
                }
            }

            GridView {
                id: gridView
                anchors.fill: parent
                visible: root.gridMode
                clip: true
                model: root.gridMode ? root.results : []
                cellWidth: width / root.columns
                cellHeight: 104 * Style.uiScale
                currentIndex: root.selected
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    width: gridView.cellWidth
                    height: gridView.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: Style.radiusLg
                        color: tile.index === root.selected ? Theme.alpha(Theme.primary, 0.16) : (tileMouse.containsMouse ? Theme.alpha(Theme.hover, 0.12) : "transparent")
                        border.color: tile.index === root.selected ? Theme.alpha(Theme.primary, 0.6) : "transparent"
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Style.spaceSm * 2
                        spacing: Style.spaceSm
                        NAppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 44 * Style.uiScale
                            source: tile.modelData.icon || ""
                        }
                        NText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.title
                            size: Style.fontSizeCaption
                        }
                    }
                    NIcon {
                        visible: tile.modelData.pinned === true
                        icon: "pinned"
                        size: Style.fontSizeMini
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.spaceSm
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && tile.modelData.kind === "app")
                                root.togglePin(tile.modelData.entry);
                            else
                                root.activate(tile.index);
                        }
                        onPositionChanged: mouse => root.hoverAt(tileMouse, mouse.x, mouse.y, tile.index)
                    }
                }
            }

            NScrollBar {
                flickable: root.gridMode ? gridView : listView
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            Column {
                anchors.centerIn: parent
                visible: root.results.length === 0
                spacing: Style.spaceSm
                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "search"
                    size: 36 * Style.uiScale
                    color: Theme.fgSurfaceVariant
                }
                NText {
                    text: I18n.tr("ui.controls.search-picker.empty", "No results")
                    muted: true
                }
            }
        }

        Loader {
            width: parent.width
            active: root.searchBottom
            visible: active
            sourceComponent: toolbarComp
        }
    }

    Component {
        id: toolbarComp
        Row {
            spacing: Style.spaceSm
            height: Style.controlHeightLg

            NRoundedImage {
                visible: !root.simple
                width: Style.controlHeightLg
                height: width
                radius: width / 2
                source: {
                    var p = String(Config.get("shell.avatar_path", ""));
                    return p !== "" ? "file://" + Config.expandPath(p) : "file://" + Config.home + "/.face";
                }
                fallbackGlyph: "person"
            }

            NTextField {
                id: field
                width: parent.width - (root.simple ? 0 : Style.controlHeightLg + parent.spacing) - (settingsBtn.visible ? settingsBtn.width + parent.spacing : 0) - (sessionBtn.visible ? sessionBtn.width + parent.spacing : 0)
                height: Style.controlHeightLg
                icon: "search"
                placeholder: I18n.tr("launcher.search-placeholder", "Search applications, or type / for providers…")
                text: root.query
                onTextChanged: root.query = text
                onAccepted: root.activate(root.selected)
                onEscapePressed: {
                    if (text !== "")
                        text = "";
                    else
                        Panels.close();
                }
                onKeyNavigation: key => {
                    if (key === Qt.Key_Down || key === Qt.Key_Tab)
                        root.move(root.gridMode ? root.columns : 1);
                    else if (key === Qt.Key_Up || key === Qt.Key_Backtab)
                        root.move(root.gridMode ? -root.columns : -1);
                    else if (key === Qt.Key_PageDown)
                        root.move(8);
                    else if (key === Qt.Key_PageUp)
                        root.move(-8);
                    else if (key === Qt.Key_Right && root.gridMode)
                        root.move(1);
                    else if (key === Qt.Key_Left && root.gridMode)
                        root.move(-1);
                }
                Component.onCompleted: search.target = field
            }

            NIconButton {
                id: settingsBtn
                visible: !root.simple && Config.get("shell.launcher.show_settings_button", true) !== false
                size: Style.controlHeightLg
                icon: "settings"
                onClicked: {
                    Panels.close();
                    Commands.openSettings();
                }
            }
            NIconButton {
                id: sessionBtn
                visible: !root.simple && Config.get("shell.launcher.show_session_button", true) !== false
                size: Style.controlHeightLg
                icon: "power"
                onClicked: Panels.open("session", root.screenRef, "", Panels.anchor, Panels.sourceBar, null)
            }
        }
    }

    QtObject {
        id: search
        property var target: null
        property string text: target ? target.text : ""
        onTextChanged: if (target && target.text !== text)
            target.text = text
        function focusInput() {
            if (target)
                target.focusInput();
        }
    }
}
