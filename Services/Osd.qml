pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// On-screen display state (volume, brightness, toggles, keyboard layout, lock keys).
Singleton {
    id: root

    property bool userEnabled: true
    readonly property bool enabled: userEnabled && Config.get("osd.enabled", true) !== false
    property string kind: ""
    property string glyph: ""
    property string label: ""
    property real value: -1          // 0..1 (or up to 1.5 with overdrive), -1 = no bar
    property real maxValue: 1
    property bool muted: false
    property int serial: 0
    property bool visible: false

    function kindEnabled(k) {
        var kinds = Config.get("osd.kinds", {});
        return kinds[k] !== false;
    }

    function show(k, g, text, v, maxV, mutedState) {
        if (!enabled || !kindEnabled(k))
            return;
        kind = k;
        glyph = g || "";
        label = text || "";
        value = v === undefined ? -1 : v;
        maxValue = maxV || 1;
        muted = mutedState === true;
        serial++;
        visible = true;
        hideTimer.restart();
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
