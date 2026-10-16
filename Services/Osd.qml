pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// On-screen display state, mirroring noctalia's OsdContent:
//   kind      osd.kinds key (volume, volume_output, volume_input, brightness, wifi, ...)
//   icon      glyph name
//   value     text ("65%", "Wi-Fi On", a layout or track name)
//   progress  0..1, or -1 for text-only content
//   overLimit value above 100% (overdrive): drawn in the error color
//   inactive  muted / off state: drawn in on_surface_variant
Singleton {
    id: root

    property bool userEnabled: true
    readonly property bool enabled: userEnabled && Config.get("osd.enabled", true) !== false
    property string kind: ""
    property string icon: ""
    property string value: ""
    property real progress: -1
    property bool overLimit: false
    property bool inactive: false
    property string targetScreen: ""   // screen name used with follow_focused_output
    property int serial: 0
    property bool visible: false
    readonly property bool hasProgress: progress >= 0

    function kindEnabled(k) {
        var kinds = Config.get("osd.kinds", {});
        if (kinds[k] === false)
            return false;
        // volume_output / volume_input refine the volume kind
        if ((k === "volume_output" || k === "volume_input") && kinds.volume === false)
            return false;
        return true;
    }

    function show(k, iconName, text, progressValue, over, isInactive) {
        if (!enabled || !kindEnabled(k))
            return;
        kind = k;
        icon = iconName || "";
        value = text || "";
        progress = progressValue === undefined || progressValue === null ? -1 : progressValue;
        overLimit = over === true;
        inactive = isInactive === true;
        var aw = X11.activeWindow;
        var scr = aw ? X11.screenOf(aw) : null;
        targetScreen = scr ? scr.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        serial++;
        visible = true;
        hideTimer.restart();
    }

    function percentText(v) {
        return Math.round(Math.max(0, v) * 100) + "%";
    }

    // Level OSD (volume / brightness): value text, progress clamped to 0..1, error color > 100%.
    function showLevel(k, iconName, level, isInactive) {
        var pct = Math.round(Math.max(0, level) * 100);
        show(k, iconName, pct + "%", Math.max(0, Math.min(1, level)), pct > 100, isInactive);
    }

    function hide() {
        visible = false;
    }

    Timer {
        id: hideTimer
        interval: Math.max(300, Number(Config.get("osd.hide_delay_ms", 1400)))
        onTriggered: root.visible = false
    }
}
