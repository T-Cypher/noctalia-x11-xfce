pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons

// PipeWire output/input volume (works the same on X11 as on Wayland).
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    // The default source can be the sink's own monitor (same node); only accept real inputs.
    readonly property var source: {
        var s = Pipewire.defaultAudioSource;
        return s && !s.isSink && s !== sink ? s : null;
    }
    readonly property bool ready: Pipewire.ready && sink !== null && sink.audio !== null
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true
    readonly property bool micReady: source !== null && source.audio !== null
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true
    readonly property real maxVolume: Config.get("audio.enable_overdrive", false) ? 1.5 : 1.0
    readonly property real step: Math.max(0.01, Number(Config.get("audio.volume_step", 5)) / 100)

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n && n.isSink && !n.isStream && n.audio)
    readonly property var sources: nodes.filter(n => n && !n.isSink && !n.isStream && n.audio && String(n.name || "").indexOf(".monitor") < 0)
    readonly property var streams: nodes.filter(n => n && n.isStream && n.isSink && n.audio)

    signal volumeAdjusted(bool input)

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.streams)
    }

    function nodeName(n) {
        if (!n)
            return "";
        return n.nickname || n.description || n.name || "";
    }

    function streamName(n) {
        if (!n)
            return "";
        var p = n.properties || {};
        return p["application.name"] || n.description || n.name || "";
    }

    function streamIcon(n) {
        var p = (n && n.properties) || {};
        return p["application.icon-name"] || p["application.process.binary"] || "";
    }

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.muted = false;
        sink.audio.volume = clampValue(v, 0, maxVolume);
        volumeAdjusted(false);
    }
    function changeVolume(delta) {
        setVolume(volume + delta);
    }
    function toggleMute() {
        if (!ready)
            return;
        sink.audio.muted = !sink.audio.muted;
        volumeAdjusted(false);
    }
    function setMicVolume(v) {
        if (!micReady)
            return;
        source.audio.muted = false;
        source.audio.volume = clampValue(v, 0, 1.0);
        volumeAdjusted(true);
    }
    function changeMicVolume(delta) {
        setMicVolume(micVolume + delta);
    }
    function toggleMicMute() {
        if (!micReady)
            return;
        source.audio.muted = !source.audio.muted;
        volumeAdjusted(true);
    }
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function clampValue(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    // Parse IPC volume arguments: "65", "65%", "0.65"
    function parseLevel(arg, fallback) {
        if (arg === undefined || arg === null || String(arg).trim() === "")
            return fallback;
        var s = String(arg).trim();
        var pct = s.endsWith("%");
        var n = parseFloat(pct ? s.slice(0, -1) : s);
        if (isNaN(n))
            return fallback;
        if (pct || n > 1.5)
            return n / 100;
        return n;
    }

    function volumeGlyph(v, m) {
        if (m || v <= 0.001)
            return "volume-mute";
        if (v < 0.34)
            return "volume-zero";
        if (v < 0.67)
            return "volume-low";
        return "volume-high";
    }
}
