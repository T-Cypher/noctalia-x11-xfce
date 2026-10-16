import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property real artSize: Number(settings.art_size !== undefined ? settings.art_size : 16) * contentScale
    readonly property real maxWidth: Number(settings.max_length !== undefined ? settings.max_length : 220) * contentScale
    readonly property real minWidth: Number(settings.min_length !== undefined ? settings.min_length : 80) * contentScale
    readonly property bool artOnly: settings.album_art_only === true
    readonly property bool hideArt: settings.hide_album_art === true
    readonly property string text: {
        if (!Media.hasPlayer)
            return I18n.tr("bar.widgets.media.nothing-playing", "Nothing playing");
        var t = Media.title;
        var a = settings.hide_artist === true ? "" : Media.artist;
        if (a === "")
            return t;
        return settings.artist_first === true ? a + " - " + t : t + " - " + a;
    }

    hideWidget: (settings.hide_when_no_media === true && !Media.hasPlayer) || (settings.hide_when_idle === true && !Media.isPlaying)
    tooltipText: Media.hasPlayer ? (Media.title + (Media.artist ? "\n" + Media.artist : "") + (Media.player && Media.player.identity ? "\n" + Media.player.identity : "")) : ""
    minLength: vertical || artOnly ? capsuleThickness : minWidth
    defaultActions: ({
            left: "panel-toggle control-center media",
            right: "media toggle",
            back: "media previous",
            forward: "media next",
            scroll_up: "media next",
            scroll_down: "media previous"
        })

    Row {
        spacing: Style.spaceSm * root.contentScale

        Item {
            width: root.artSize
            height: root.artSize
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.hideArt

            NRoundedImage {
                anchors.fill: parent
                radius: width / 2
                source: Media.artUrl
                visible: Media.artUrl !== "" && hasImage
                fallbackGlyph: ""
                RotationAnimator on rotation {
                    running: root.settings.rotate_album_art === true && Media.isPlaying
                    from: 0
                    to: 360
                    duration: 8000
                    loops: Animation.Infinite
                }
            }
            NIcon {
                anchors.centerIn: parent
                visible: Media.artUrl === ""
                icon: Media.hasPlayer ? (Media.isPlaying ? "music" : "media-pause") : "disc"
                size: root.glyphSize
                color: root.iconColor(Media.hasPlayer ? Theme.fgSurface : Theme.fgSurfaceVariant)
            }
        }

        Item {
            visible: !root.artOnly && !root.vertical
            width: Math.min(label.implicitWidth, root.maxWidth)
            height: label.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            NText {
                id: label
                text: root.text
                size: root.fontSize
                weight: root.fontWeight
                font.family: root.fontFamily
                elide: root.settings.title_scroll === "always" || (root.settings.title_scroll === "on_hover" && root.hovered) ? Text.ElideNone : Text.ElideRight
                width: elide === Text.ElideNone ? implicitWidth : parent.width
                muted: !Media.hasPlayer
                x: 0
                SequentialAnimation on x {
                    running: label.elide === Text.ElideNone && label.implicitWidth > root.maxWidth
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        label.x = 0
                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        to: root.maxWidth - label.implicitWidth
                        duration: Math.max(1000, (label.implicitWidth - root.maxWidth) * 25)
                    }
                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        to: 0
                        duration: 600
                    }
                }
            }
        }
    }

    Rectangle {
        parent: root
        visible: root.settings.show_progress === true && Media.length > 0
        x: root.padding
        y: root.height - 3
        height: 2
        radius: 1
        width: (root.width - root.padding * 2) * Math.min(1, Media.position / Math.max(1, Media.length))
        color: Theme.primary
    }
}
