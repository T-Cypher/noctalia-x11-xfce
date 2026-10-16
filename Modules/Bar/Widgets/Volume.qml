import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property bool input: settings.device === "input" || settings.device === "microphone"
    readonly property real level: input ? Audio.micVolume : Audio.volume
    readonly property bool isMuted: input ? Audio.micMuted : Audio.muted
    readonly property bool showLabel: settings.show_label !== false

    hideWidget: !(input ? Audio.micReady : Audio.ready)
    tooltipText: (input ? I18n.tr("control-center.audio.input-device-prefix", "Input") + ": " + Audio.nodeName(Audio.source) : I18n.tr("control-center.audio.output-device-prefix", "Output") + ": " + Audio.nodeName(Audio.sink)) + "\n" + Math.round(level * 100) + "%"

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            icon: root.input ? (root.isMuted ? (root.settings.mute_glyph || "microphone-mute") : (root.settings.glyph || "microphone")) : (root.isMuted ? (root.settings.mute_glyph || "volume-mute") : (root.settings.glyph || Audio.volumeGlyph(root.level, false)))
            size: root.glyphSize
            color: root.isMuted ? Theme.resolve(root.settings.mute_color || "on_surface_variant") : root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.showLabel && !root.vertical
            text: Math.round(root.level * 100) + "%"
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            muted: root.isMuted
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
