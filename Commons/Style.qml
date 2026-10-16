pragma Singleton

import QtQuick
import Quickshell

// Design tokens from noctalia v5.3.0 src/ui/style.h, scaled by [accessibility].ui_scale and
// [shell].corner_radius_scale.
Singleton {
    id: root

    readonly property real uiScale: Math.max(0.1, Number(Config.get("accessibility.ui_scale", 1.0)))
    // Set by the X11 service: false when no compositing manager runs (no transparency).
    property bool composited: true
    readonly property real cornerScale: composited ? Math.max(0, Number(Config.get("shell.corner_radius_scale", 1.0))) : 0
    readonly property bool animationsEnabled: Config.get("shell.animation.enabled", true) !== false
    readonly property real animationSpeed: Math.max(0.1, Number(Config.get("shell.animation.speed", 1.0)))
    readonly property string fontFamily: {
        var f = String(Config.get("shell.font_family", "sans-serif"));
        return f.length > 0 ? f : "sans-serif";
    }

    readonly property int barThicknessDefault: 34

    // Animation durations (ms), honoring [shell.animation]
    function anim(ms) {
        return animationsEnabled ? Math.round(ms / animationSpeed) : 0;
    }
    readonly property int animFast: anim(100)
    readonly property int animNormal: anim(200)
    readonly property int animSlow: anim(400)

    // Radii
    readonly property real radiusSm: 3 * cornerScale * uiScale
    readonly property real radiusMd: 6 * cornerScale * uiScale
    readonly property real radiusLg: 9 * cornerScale * uiScale
    readonly property real radiusXl: 12 * cornerScale * uiScale
    function radius(r) {
        return r * cornerScale * uiScale;
    }

    readonly property real borderWidth: 1
    readonly property real emphasizedBorderWidth: 3
    readonly property real focusRingWidth: 2
    readonly property real disabledOutlineAlpha: 0.5
    readonly property real disabledAlpha: 0.5

    // Spacing
    readonly property real spaceXs: 4 * uiScale
    readonly property real spaceSm: 8 * uiScale
    readonly property real spaceMd: 12 * uiScale
    readonly property real spaceLg: 16 * uiScale

    readonly property real cardPadding: 14 * uiScale
    readonly property real panelPadding: 14 * uiScale
    readonly property real barCapsulePadding: 6
    readonly property real baseGlyphSize: 16 * uiScale

    // Typography
    readonly property real fontSizeMini: 11 * uiScale
    readonly property real fontSizeCaption: 13 * uiScale
    readonly property real fontSizeBody: 14 * uiScale
    readonly property real fontSizeTitle: 16 * uiScale
    readonly property real fontSizeHeader: 20 * uiScale

    // Controls
    readonly property real controlHeightSm: 32 * uiScale
    readonly property real controlHeight: 38 * uiScale
    readonly property real controlHeightLg: 44 * uiScale
    readonly property real scrollWheelStep: 56

    readonly property real scrollbarWidth: 6
    readonly property real scrollbarHoverWidth: 12

    // Toggle (medium preset)
    readonly property real toggleThumbSize: 18 * uiScale
    readonly property real toggleInset: 3 * uiScale
    readonly property real toggleTravel: 16 * uiScale

    // Slider
    readonly property real sliderTrackHeight: 8 * uiScale
    readonly property real sliderThumbSize: 18 * uiScale

    // Map a CSS-style weight (100..1000) to Qt font weight
    function fontWeight(w) {
        var n = Number(w);
        if (isNaN(n))
            return Font.Medium;
        return Math.max(1, Math.min(1000, Math.round(n)));
    }
}
