pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    component VolumeRow: Row {
        id: vr
        property string glyph: ""
        property real value: 0
        property real maxValue: 1
        property bool muted: false
        signal moved(real v)
        signal toggleMute
        spacing: Style.spaceSm
        NIconButton {
            icon: vr.glyph
            variant: vr.muted ? "secondary" : "ghost"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: vr.toggleMute()
        }
        NSlider {
            width: vr.width - Style.controlHeightSm - pct.width - vr.spacing * 2
            to: vr.maxValue
            value: vr.value
            anchors.verticalCenter: parent.verticalCenter
            onMoved: v => vr.moved(v)
            fillColor: vr.muted ? Theme.fgSurfaceVariant : Theme.primary
        }
        NText {
            id: pct
            width: 44 * Style.uiScale
            horizontalAlignment: Text.AlignRight
            text: Math.round(vr.value * 100) + "%"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    NText {
        anchors.centerIn: parent
        visible: !Audio.ready
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: I18n.tr("control-center.audio.unavailable-title", "Audio unavailable") + "\n" + I18n.tr("control-center.audio.unavailable-body", "PipeWire is not active.")
        muted: true
        wrapMode: Text.Wrap
    }

    Flickable {
        id: flick
        anchors.fill: parent
        visible: Audio.ready
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width - Style.spaceMd
            spacing: Style.spaceMd

            NCard {
                width: parent.width
                height: outCol.implicitHeight + Style.cardPadding * 2
                Column {
                    id: outCol
                    anchors.fill: parent
                    anchors.margins: Style.cardPadding
                    spacing: Style.spaceSm
                    SectionLabel {
                        text: I18n.tr("control-center.audio.output-device-prefix", "Output") + " · " + Audio.nodeName(Audio.sink)
                        width: parent.width
                    }
                    VolumeRow {
                        width: parent.width
                        glyph: Audio.volumeGlyph(Audio.volume, Audio.muted)
                        value: Audio.volume
                        maxValue: Audio.maxVolume
                        muted: Audio.muted
                        onMoved: v => Audio.setVolume(v)
                        onToggleMute: Audio.toggleMute()
                    }
                    Repeater {
                        model: Audio.sinks
                        delegate: ListRow {
                            required property var modelData
                            width: parent.width
                            glyph: "device-speaker"
                            title: Audio.nodeName(modelData)
                            active: Audio.sink === modelData
                            implicitHeight: Style.controlHeight
                            onClicked: Audio.setDefaultSink(modelData)
                        }
                    }
                }
            }

            NCard {
                width: parent.width
                visible: Audio.micReady
                height: inCol.implicitHeight + Style.cardPadding * 2
                Column {
                    id: inCol
                    anchors.fill: parent
                    anchors.margins: Style.cardPadding
                    spacing: Style.spaceSm
                    SectionLabel {
                        text: I18n.tr("control-center.audio.input-device-prefix", "Input") + " · " + Audio.nodeName(Audio.source)
                        width: parent.width
                    }
                    VolumeRow {
                        width: parent.width
                        glyph: Audio.micMuted ? "microphone-mute" : "microphone"
                        value: Audio.micVolume
                        muted: Audio.micMuted
                        onMoved: v => Audio.setMicVolume(v)
                        onToggleMute: Audio.toggleMicMute()
                    }
                    Repeater {
                        model: Audio.sources
                        delegate: ListRow {
                            required property var modelData
                            width: parent.width
                            glyph: "microphone"
                            title: Audio.nodeName(modelData)
                            active: Audio.source === modelData
                            implicitHeight: Style.controlHeight
                            onClicked: Audio.setDefaultSource(modelData)
                        }
                    }
                }
            }

            NCard {
                width: parent.width
                height: appCol.implicitHeight + Style.cardPadding * 2
                Column {
                    id: appCol
                    anchors.fill: parent
                    anchors.margins: Style.cardPadding
                    spacing: Style.spaceSm
                    SectionLabel {
                        text: I18n.tr("control-center.audio.application-volumes", "Application Volumes")
                        width: parent.width
                    }
                    NText {
                        visible: Audio.streams.length === 0
                        text: I18n.tr("control-center.audio.no-application-audio-body", "No application playback streams are currently available.")
                        muted: true
                        size: Style.fontSizeCaption
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: Audio.streams
                        delegate: Column {
                            id: streamRow
                            required property var modelData
                            width: appCol.width
                            spacing: 2
                            Row {
                                spacing: Style.spaceSm
                                IconImage {
                                    width: Style.fontSizeBody + 2
                                    height: width
                                    source: Quickshell.iconPath(Audio.streamIcon(streamRow.modelData), "audio-x-generic")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                NText {
                                    text: Audio.streamName(streamRow.modelData)
                                    size: Style.fontSizeCaption
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            VolumeRow {
                                width: parent.width
                                glyph: streamRow.modelData.audio.muted ? "volume-mute" : "volume-high"
                                value: streamRow.modelData.audio.volume
                                muted: streamRow.modelData.audio.muted
                                onMoved: v => streamRow.modelData.audio.volume = v
                                onToggleMute: streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                            }
                        }
                    }
                }
            }
        }
    }

    NScrollBar {
        flickable: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
