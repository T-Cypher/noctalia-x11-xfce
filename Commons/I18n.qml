pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations reuse noctalia's own translation catalogs (assets/translations/*.json).
// tr("session.actions.lock") -> "Lock"; placeholders like {device} are substituted from vars.
Singleton {
    id: root

    readonly property string langSetting: String(Config.get("shell.lang", ""))
    // $LC_ALL / $LC_MESSAGES / $LANG, first non-empty (like noctalia's detectSystemLanguage).
    readonly property string systemLang: Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || ""
    readonly property var available: ["ar", "be", "be-Latn", "ca", "cs", "de", "en", "es", "fr", "gl-ES", "he", "hu", "it", "ja", "ko", "ku", "nl", "nn", "pl", "pt-BR", "ru", "sv", "tr", "uk-UA", "vi", "zh-Hans", "zh-Hant"]

    // noctalia's normalizeLanguageTag: strip .charset and @modifier, '_' -> '-', C/POSIX -> "".
    function normalizeTag(raw) {
        var s = String(raw || "");
        var dot = s.indexOf(".");
        if (dot >= 0)
            s = s.slice(0, dot);
        var at = s.indexOf("@");
        if (at >= 0)
            s = s.slice(0, at);
        s = s.replace(/_/g, "-");
        if (s === "" || s === "C" || s === "POSIX")
            return "";
        var parts = s.split("-");
        if (parts[0] === "")
            return "";
        var out = [parts[0].toLowerCase()];
        for (var i = 1; i < parts.length; i++) {
            var p = parts[i];
            if (p === "")
                return "";
            if (/^[A-Za-z]{4}$/.test(p))
                out.push(p.charAt(0).toUpperCase() + p.slice(1).toLowerCase());
            else if (/^([A-Za-z]{2}|[0-9]{3})$/.test(p))
                out.push(p.toUpperCase());
            else
                out.push(p.toLowerCase());
        }
        return out.join("-");
    }

    // noctalia's catalogLanguageCandidates (no cross-region fallback: pt_PT does not pick pt-BR).
    function candidates(tag) {
        var out = [];
        function add(c) {
            if (c && out.indexOf(c) < 0)
                out.push(c);
        }
        if (tag === "")
            return out;
        var parts = tag.split("-");
        var language = parts[0], script = "", region = "", scriptIndex = 0;
        for (var i = 1; i < parts.length; i++) {
            if (/^[A-Z][a-z]{3}$/.test(parts[i]) && script === "") {
                script = parts[i];
                scriptIndex = i;
            } else if (/^([A-Z]{2}|[0-9]{3})$/.test(parts[i]) && region === "") {
                region = parts[i];
            }
        }
        var inferred = script;
        if (script === "" && region !== "") {
            if (language === "zh" && ["CN", "SG", "MY"].indexOf(region) >= 0)
                inferred = "Hans";
            else if (language === "zh" && ["TW", "HK", "MO"].indexOf(region) >= 0)
                inferred = "Hant";
            if (inferred !== "") {
                var withScript = parts.slice();
                withScript.splice(1, 0, inferred);
                add(withScript.join("-"));
            }
        }
        add(tag);
        if (script !== "" && region !== "") {
            var noScript = parts.slice();
            noScript.splice(scriptIndex, 1);
            add(noScript.join("-"));
        }
        if (inferred !== "")
            add(language + "-" + inferred);
        add(language);
        return out;
    }

    readonly property string lang: {
        var tag = normalizeTag(langSetting !== "" ? langSetting : systemLang);
        var c = candidates(tag);
        for (var i = 0; i < c.length; i++)
            if (available.indexOf(c[i]) >= 0)
                return c[i];
        return "en";
    }

    property var english: ({})
    property var current: ({})

    function lookup(obj, key) {
        var parts = key.split(".");
        var o = obj;
        for (var i = 0; i < parts.length; i++) {
            if (o === null || o === undefined || typeof o !== "object")
                return undefined;
            o = o[parts[i]];
        }
        return typeof o === "string" ? o : undefined;
    }

    function tr(key, fallback, vars) {
        var s = lookup(current, key);
        if (s === undefined)
            s = lookup(english, key);
        if (s === undefined)
            s = fallback !== undefined ? fallback : key;
        if (vars) {
            for (var k in vars)
                s = s.split("{" + k + "}").join(String(vars[k]));
        }
        return s;
    }

    function base(path) {
        return Qt.resolvedUrl(path).toString().replace("file://", "");
    }

    FileView {
        path: root.base("../assets/translations/en.json")
        blockLoading: true
        onLoaded: {
            try {
                root.english = JSON.parse(text());
            } catch (e) {
                console.warn("[noctalia-x11] bad en.json", e);
            }
        }
    }

    FileView {
        path: root.lang === "en" ? "" : root.base("../assets/translations/" + root.lang + ".json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.current = JSON.parse(text());
            } catch (e) {
                root.current = {};
            }
        }
    }
}
