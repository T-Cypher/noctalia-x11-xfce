pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Palettes.js" as Palettes

// Resolved color palette (noctalia ColorRole set) with smooth cross-fades on change.
// Sources: builtin palettes (generated from noctalia v5.3.0) or colors quantized from the
// current wallpaper ([theme] source = "wallpaper").
Singleton {
    id: root

    // App-facing mode ([theme] mode, or a theme-mode-set/toggle override persisted in state).
    readonly property string configuredMode: String(Config.get("theme.mode", "dark"))
    readonly property string modeOverride: ShellState.data.theme_mode || ""
    readonly property string requestedMode: modeOverride !== "" ? modeOverride : configuredMode
    property bool autoIsNight: true
    function resolveMode(m) {
        return m === "auto" ? (autoIsNight ? "dark" : "light") : (m === "light" ? "light" : "dark");
    }
    readonly property string appMode: resolveMode(requestedMode)
    readonly property bool appIsDark: appMode === "dark"
    // Mode of the shell's own surfaces: [theme] shell_mode (follow | dark | light | auto).
    readonly property string shellModeSetting: String(Config.get("theme.shell_mode", "follow"))
    readonly property string mode: ["dark", "light", "auto"].indexOf(shellModeSetting) >= 0 ? resolveMode(shellModeSetting) : appMode
    readonly property bool isDark: mode === "dark"

    readonly property string source: String(ShellState.data.theme_source || Config.get("theme.source", "builtin"))
    readonly property string builtinName: {
        var n = String(ShellState.data.theme_builtin || Config.get("theme.builtin", "Noctalia"));
        return Palettes.palettes[n] ? n : "Noctalia";
    }
    readonly property string wallpaperScheme: String(ShellState.data.theme_wallpaper_scheme || Config.get("theme.wallpaper_scheme", "m3-content"))
    readonly property bool pureBlack: Config.get("theme.pure_black_dark", false) === true
    readonly property bool highContrast: Config.get("accessibility.high_contrast", false) === true
    readonly property var paletteNames: Palettes.names

    // Dominant wallpaper colors (set by the Wallpaper service through ColorQuantizer).
    property var wallpaperColors: []
    readonly property var wallpaperPalette: wallpaperColors.length > 0 ? paletteFromColors(wallpaperColors, wallpaperScheme) : null

    readonly property var basePalette: {
        var p;
        if (source === "wallpaper" && wallpaperPalette && wallpaperPalette[mode])
            p = wallpaperPalette[mode];
        else
            p = Palettes.palettes[builtinName][mode];
        if (pureBlack && mode === "dark")
            p = pureBlackTransform(p);
        if (highContrast)
            p = highContrastTransform(p, mode === "dark");
        return p;
    }

    // ---------------------------------------------------------------- tone transforms
    // noctalia shifts HCT tones; CIELAB L* is the same lightness scale (tone == L*), and keeping
    // a*/b* preserves hue and chroma closely enough for these transforms.
    function labOf(hex) {
        var c = Qt.color(hex);
        function lin(v) {
            return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        }
        var r = lin(c.r), g = lin(c.g), b = lin(c.b);
        var x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
        var y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        var z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
        function f(t) {
            return t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116;
        }
        var fx = f(x), fy = f(y), fz = f(z);
        return {
            l: 116 * fy - 16,
            a: 500 * (fx - fy),
            b: 200 * (fy - fz)
        };
    }
    function hexFromLab(l, a, b) {
        if (l <= 0.5)
            return "#000000";
        var fy = (l + 16) / 116, fx = fy + a / 500, fz = fy - b / 200;
        function finv(t) {
            return t > 0.206893 ? t * t * t : (t - 16 / 116) / 7.787;
        }
        var x = finv(fx) * 0.95047, y = finv(fy), z = finv(fz) * 1.08883;
        var r = 3.2406 * x - 1.5372 * y - 0.4986 * z;
        var g = -0.9689 * x + 1.8758 * y + 0.0415 * z;
        var bb = 0.0557 * x - 0.2040 * y + 1.0570 * z;
        function gam(v) {
            v = Math.max(0, Math.min(1, v));
            return v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        }
        return hexOf(Qt.rgba(gam(r), gam(g), gam(bb), 1));
    }
    function withTone(hex, tone) {
        var lab = labOf(hex);
        return hexFromLab(Math.max(0, Math.min(100, tone)), lab.a, lab.b);
    }
    // pure_black_dark: shift the surface ramp down by the surface tone (surface becomes black).
    function pureBlackTransform(p) {
        var shift = labOf(p.surface).l;
        if (shift <= 0)
            return p;
        var c = Object.assign({}, p);
        c.surface = withTone(p.surface, 0);
        c.surfaceVariant = withTone(p.surfaceVariant, labOf(p.surfaceVariant).l - shift);
        return c;
    }
    // accessibility.high_contrast: stretch tones apart; outlines become strongly visible.
    function highContrastTransform(p, dark) {
        var c = {};
        for (var k in p) {
            var t = labOf(p[k]).l;
            if (k === "outline")
                t = dark ? Math.max(t, 80) : Math.min(t, 20);
            else
                t = t < 50 ? Math.max(0, t - 20) : Math.min(100, t + 20);
            c[k] = withTone(p[k], t);
        }
        return c;
    }

    readonly property int fadeMs: Style.animSlow

    property color primary: basePalette.primary
    property color fgPrimary: basePalette.onPrimary
    property color secondary: basePalette.secondary
    property color fgSecondary: basePalette.onSecondary
    property color tertiary: basePalette.tertiary
    property color fgTertiary: basePalette.onTertiary
    property color error: basePalette.error
    property color fgError: basePalette.onError
    property color surface: basePalette.surface
    property color fgSurface: basePalette.onSurface
    property color surfaceVariant: basePalette.surfaceVariant
    property color fgSurfaceVariant: basePalette.onSurfaceVariant
    property color outline: basePalette.outline
    property color shadow: basePalette.shadow
    property color hover: basePalette.hover
    property color fgHover: basePalette.onHover


    readonly property var roleTokens: ["primary", "on_primary", "secondary", "on_secondary", "tertiary", "on_tertiary", "error", "on_error", "surface", "on_surface", "surface_variant", "on_surface_variant", "outline", "shadow", "hover", "on_hover"]

    function role(token) {
        switch (String(token)) {
        case "primary": return primary;
        case "on_primary": return fgPrimary;
        case "secondary": return secondary;
        case "on_secondary": return fgSecondary;
        case "tertiary": return tertiary;
        case "on_tertiary": return fgTertiary;
        case "error": return error;
        case "on_error": return fgError;
        case "surface": return surface;
        case "on_surface": return fgSurface;
        case "surface_variant": return surfaceVariant;
        case "on_surface_variant": return fgSurfaceVariant;
        case "outline": return outline;
        case "shadow": return shadow;
        case "hover": return hover;
        case "on_hover": return fgHover;
        }
        return undefined;
    }

    // Parse a hex color like noctalia: '#' optional; #RGB, #RGBA, #RRGGBB or #RRGGBBAA (alpha last).
    function parseHex(str) {
        var m = /^#?([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(String(str).trim());
        if (!m)
            return null;
        var h = m[1];
        if (h.length <= 4)
            h = h.split("").map(function (ch) {
                return ch + ch;
            }).join("");
        return Qt.rgba(parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255, h.length === 8 ? parseInt(h.substr(6, 2), 16) / 255 : 1);
    }

    // Resolve a noctalia ColorSpec string: hex color (tried first, like noctalia) or a role token
    // ("primary", "on_surface"). Port extension: optional alpha suffix "primary/0.5".
    function resolve(spec, fallback) {
        if (spec === undefined || spec === null || spec === "")
            return fallback !== undefined ? fallback : fgSurface;
        var s = String(spec).trim();
        var alpha = 1.0;
        var slash = s.lastIndexOf("/");
        if (slash > 0) {
            alpha = Number(s.slice(slash + 1));
            s = s.slice(0, slash).trim();
            if (isNaN(alpha))
                alpha = 1.0;
        }
        var c = parseHex(s);
        if (c === null)
            c = role(s.toLowerCase().replace(/-/g, "_"));
        if (c === undefined || c === null)
            return fallback !== undefined ? fallback : fgSurface;
        return alpha < 1.0 ? Qt.rgba(c.r, c.g, c.b, c.a * alpha) : c;
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    function mixHex(a, b, t) {
        var ca = Qt.color(a), cb = Qt.color(b);
        var m = mix(ca, cb, t);
        return "#" + [m.r, m.g, m.b].map(function (v) {
            var h = Math.round(v * 255).toString(16);
            return h.length < 2 ? "0" + h : h;
        }).join("");
    }

    // ------------------------------------------------------------------ wallpaper palettes
    // A light-weight approximation of noctalia's Material-derived wallpaper schemes: pick the
    // most chromatic dominant color as seed and derive the role set from it in HSL space.
    function hexOf(c) {
        return "#" + [c.r, c.g, c.b].map(function (v) {
            var h = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return h.length < 2 ? "0" + h : h;
        }).join("");
    }
    function hsl(h, s, l) {
        return hexOf(Qt.hsla(((h % 1) + 1) % 1, Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l)), 1));
    }

    function paletteFromColors(colors, scheme) {
        if (!colors || colors.length === 0)
            return null;
        var best = null, bestScore = -1, second = null;
        for (var i = 0; i < colors.length; i++) {
            var c = colors[i];
            var s = c.hslSaturation, l = c.hslLightness;
            var score = s * (1 - Math.abs(l - 0.5) * 1.4);
            if (score > bestScore) {
                second = best;
                bestScore = score;
                best = c;
            }
        }
        if (!best)
            best = colors[0];
        var h = best.hslHue < 0 ? 0.6 : best.hslHue;
        var sat = scheme === "faithful" ? Math.max(0.05, Math.min(1, best.hslSaturation)) : Math.max(0.35, Math.min(0.9, best.hslSaturation));
        if (scheme === "m3-monochrome" || scheme === "muted")
            sat = scheme === "muted" ? 0.25 : 0.0;
        if (scheme === "soft")
            sat = sat * 0.6;
        if (scheme === "vibrant" || scheme === "m3-fruit-salad" || scheme === "m3-rainbow")
            sat = Math.min(1, sat + 0.2);
        var h2 = second && second.hslHue >= 0 ? second.hslHue : h + 0.08;
        if (scheme === "dysfunctional")
            h2 = h + 0.5;
        var dark = {
            primary: hsl(h, sat, 0.78),
            onPrimary: hsl(h, sat * 0.6, 0.12),
            secondary: hsl(h2, sat * 0.55, 0.74),
            onSecondary: hsl(h2, sat * 0.4, 0.12),
            tertiary: hsl(h + 0.16, sat * 0.65, 0.76),
            onTertiary: hsl(h + 0.16, sat * 0.4, 0.12),
            error: "#fd4663",
            onError: hsl(h, 0.3, 0.1),
            surface: hsl(h, Math.min(0.35, sat * 0.5), 0.07),
            onSurface: hsl(h, 0.15, 0.93),
            surfaceVariant: hsl(h, Math.min(0.3, sat * 0.45), 0.12),
            onSurfaceVariant: hsl(h, 0.25, 0.68),
            outline: hsl(h, Math.min(0.4, sat * 0.5), 0.24),
            shadow: "#000000",
            hover: hsl(h + 0.16, sat * 0.65, 0.76),
            onHover: hsl(h + 0.16, sat * 0.4, 0.12)
        };
        var light = {
            primary: hsl(h, sat, 0.38),
            onPrimary: hsl(h, 0.3, 0.97),
            secondary: hsl(h2, sat * 0.5, 0.42),
            onSecondary: hsl(h2, 0.3, 0.97),
            tertiary: hsl(h + 0.16, sat * 0.6, 0.36),
            onTertiary: hsl(h + 0.16, 0.3, 0.97),
            error: "#c62f47",
            onError: "#ffffff",
            surface: hsl(h, Math.min(0.4, sat * 0.5), 0.95),
            onSurface: hsl(h, 0.35, 0.12),
            surfaceVariant: hsl(h, Math.min(0.4, sat * 0.5), 0.90),
            onSurfaceVariant: hsl(h, 0.3, 0.35),
            outline: hsl(h, Math.min(0.4, sat * 0.5), 0.72),
            shadow: "#a0a0a0",
            hover: hsl(h + 0.16, sat * 0.6, 0.36),
            onHover: hsl(h + 0.16, 0.3, 0.97)
        };
        return {
            dark: dark,
            light: light
        };
    }
}
