pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations reuse noctalia's own translation catalogs (assets/translations/*.json).
// tr("session.actions.lock") -> "Lock"; placeholders like {device} are substituted from vars.
Singleton {
    id: root

    readonly property string langSetting: String(Config.get("shell.lang", ""))
    readonly property string systemLang: {
        var l = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "en";
        return String(l).split(".")[0];
    }
    readonly property var available: ["ar", "be", "be-Latn", "ca", "cs", "de", "en", "es", "fr", "gl-ES", "he", "hu", "it", "ja", "ko", "ku", "nl", "nn", "pl", "pt-BR", "ru", "sv", "tr", "uk-UA", "vi", "zh-Hans", "zh-Hant"]
    readonly property string lang: {
        var want = langSetting !== "" ? langSetting : systemLang;
        var norm = want.replace("_", "-");
        var aliases = {
            "zh-CN": "zh-Hans",
            "zh-SG": "zh-Hans",
            "zh-TW": "zh-Hant",
            "zh-HK": "zh-Hant",
            "zh-MO": "zh-Hant",
            "nb": "nn",
            "nb-NO": "nn",
            "uk": "uk-UA",
            "gl": "gl-ES"
        };
        if (aliases[norm])
            norm = aliases[norm];
        if (available.indexOf(norm) >= 0)
            return norm;
        var base = norm.split("-")[0];
        if (available.indexOf(base) >= 0)
            return base;
        for (var i = 0; i < available.length; i++)
            if (available[i].split("-")[0] === base)
                return available[i];
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
