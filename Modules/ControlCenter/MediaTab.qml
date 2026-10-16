pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd

        NCard {
            id: nowPlaying
            width: parent.width
            height: parent.height - (players.visible ? players.height + parent.spacing : 0)

            Column {
                anchors.centerIn: parent
                width: parent.width - Style.cardPadding * 2
                spacing: Style.spaceMd

                NRoundedImage {
                    width: Math.min(parent.width * 0.5, nowPlaying.height * 0.42)
                    height: width
                    radius: Style.radiusXl
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: Media.artUrl
                    fallbackGlyph: "disc"
                }

                Column {
                    width: parent.width
                    spacing: 2
                    NText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Media.hasPlayer ? Media.title : I18n.tr("control-center.media.nothing-playing", "Nothing playing")
                        size: Style.fontSizeTitle
                        weight: Font.Bold
                    }
                    NText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: Media.hasPlayer
                        text: [Media.artist, Media.album].filter(x => x).join(" · ")
                        muted: true
                    }
                }

                Row {
                    visible: Media.length > 0
                    width: parent.width
                    spacing: Style.spaceSm
                    NText {
                        id: posLabel
                        text: Util.formatClock(Media.position)
                        size: Style.fontSizeMini
                        muted: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    NSlider {
                        width: parent.width - posLabel.width - lenLabel.width - parent.spacing * 2
                        from: 0
                        to: Math.max(1, Media.length)
                        value: Media.position
                        stepSize: 1
                        live: false
                        anchors.verticalCenter: parent.verticalCenter
                        onReleased: v => Media.seek(v)
                    }
                    NText {
                        id: lenLabel
                        text: Util.formatClock(Media.length)
                        size: Style.fontSizeMini
                        muted: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spaceMd
                    enabled: Media.hasPlayer
                    opacity: Media.hasPlayer ? 1 : 0.5

                    NIconButton {
                        icon: "shuffle"
                        variant: Media.player && Media.player.shuffle ? "secondary" : "ghost"
                        visible: Media.player !== null && Media.player.shuffleSupported
                        onClicked: Media.player.shuffle = !Media.player.shuffle
                    }
                    NIconButton {
                        icon: "media-prev"
                        size: Style.controlHeight
                        onClicked: Media.previous()
                    }
                    NIconButton {
                        icon: Media.isPlaying ? "media-pause" : "media-play"
                        variant: "primary"
                        size: Style.controlHeightLg
                        radius: width / 2
                        onClicked: Media.togglePlaying()
                    }
                    NIconButton {
                        icon: "media-next"
                        size: Style.controlHeight
                        onClicked: Media.next()
                    }
                    NIconButton {
                        icon: "repeat"
                        variant: Media.player && Media.player.loopState !== MprisLoopState.None ? "secondary" : "ghost"
                        visible: Media.player !== null && Media.player.loopSupported
                        onClicked: {
                            var s = Media.player.loopState;
                            Media.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                        }
                    }
                }
            }
        }

        Row {
            id: players
            visible: Media.players.length > 1
            spacing: Style.spaceSm
            height: Style.controlHeightSm
            Repeater {
                model: Media.players
                delegate: NButton {
                    required property var modelData
                    height: Style.controlHeightSm
                    text: modelData.identity || modelData.dbusName
                    variant: Media.player === modelData ? "tabActive" : "default"
                    fontSize: Style.fontSizeCaption
                    onClicked: Media.manualPlayer = modelData.dbusName
                }
            }
        }
    }
}
