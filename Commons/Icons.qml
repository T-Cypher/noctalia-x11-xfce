pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "GlyphAliases.js" as GlyphAliases

// Glyph registry: noctalia's curated alias table + the full Tabler name -> codepoint map that
// ships with noctalia (assets/fonts/tabler.json), rendered with the bundled icon font.
Singleton {
    id: root

    readonly property string fontFamily: iconFont.status === FontLoader.Ready ? iconFont.name : "noctalia-tabler-icons"
    readonly property string missing: String.fromCodePoint(0xF292) // skull, like upstream
    property var codepoints: ({})
    property bool ready: false

    function glyph(name) {
        if (name === undefined || name === null || name === "")
            return "";
        var n = String(name);
        // literal codepoints: "U+F292", "0xF292", "\uF292"
        var m = /^(?:U\+|0x)([0-9A-Fa-f]{4,6})$/.exec(n);
        if (m)
            return String.fromCodePoint(parseInt(m[1], 16));
        if (n.length <= 2 && n.codePointAt(0) > 0xE000)
            return n;
        var target = GlyphAliases.aliases[n] || n;
        var cp = codepoints[target];
        if (cp === undefined && target !== n)
            cp = codepoints[n];
        return cp !== undefined ? String.fromCodePoint(cp) : (ready ? missing : "");
    }

    function has(name) {
        var target = GlyphAliases.aliases[name] || name;
        return codepoints[target] !== undefined;
    }

    FontLoader {
        id: iconFont
        source: Qt.resolvedUrl("../assets/fonts/noctalia-tabler.ttf")
    }

    FileView {
        path: Qt.resolvedUrl("../assets/fonts/tabler.json").toString().replace("file://", "")
        blockLoading: true
        onLoaded: {
            try {
                var raw = JSON.parse(text());
                var map = {};
                for (var k in raw) {
                    var cp = raw[k].codepoint;
                    if (cp)
                        map[k] = parseInt(String(cp).replace("U+", ""), 16);
                }
                root.codepoints = map;
                root.ready = true;
            } catch (e) {
                console.warn("[noctalia-x11] failed to parse tabler.json:", e);
            }
        }
    }
}
