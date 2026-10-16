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
    // noctalia's kVolumeStepDefault (IPC/gesture commands accept an explicit [step]).
    readonly property real step: 0.05

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
        source.audio.volume = clampValue(v, 0, maxVolume);
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

    // noctalia's audioVolumeGlyph
    function volumeGlyph(v, m) {
        if (m || Math.round(Math.max(0, v) * 100) === 0)
            return "volume-mute";
        return v < 0.4 ? "volume-low" : "volume-high";
    }
    function micGlyph(v, m) {
        return m || Math.round(Math.max(0, v) * 100) === 0 ? "microphone-mute" : "microphone";
    }
}
