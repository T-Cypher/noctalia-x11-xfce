pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

// Home: user card, media summary, date/time + weather, shortcut grid.
Item {
    id: root

    required property var screenRef
    signal openTab(string id)

    readonly property real gap: Style.spaceSm + 2
    readonly property string user: Quickshell.env("USER") || "user"
    property string realName: ""
    property string hostName: ""
    property date now: new Date()

    readonly property string avatar: {
        var p = String(Config.get("shell.avatar_path", ""));
        if (p !== "")
            return "file://" + Config.expandPath(p);
        return avatarProbe.found;
    }

    Component.onCompleted: SystemMonitor.consumers++
    Component.onDestruction: SystemMonitor.consumers--

    QtObject {
        id: avatarProbe
        property string found: ""
    }

    Process {
        running: true
        command: ["sh", "-c", "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -r \"$f\" ] && { echo \"$f\"; break; }; done; echo \"#$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1)\"; echo \"@$(hostname 2>/dev/null || cat /etc/hostname)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(l => {
                    if (l.indexOf("#") === 0)
                        root.realName = l.slice(1).trim();
                    else if (l.indexOf("@") === 0)
                        root.hostName = l.slice(1).trim();
                    else if (l.trim().length > 0 && avatarProbe.found === "")
                        avatarProbe.found = "file://" + l.trim();
                });
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ---------------------------------------------------------------- profile card
    NCard {
        id: profile
        width: parent.width
        height: Math.round(parent.height * 0.36)
        clip: true

        NRoundedImage {
            anchors.fill: parent
            anchors.margins: 1
            radius: Style.radiusXl - 1
            source: "file://" + Wallpaper.current(root.screenRef.name)
            fallbackGlyph: ""
            opacity: 0.9
        }
        Rectangle {
            anchors.fill: parent
            radius: Style.radiusXl
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Theme.alpha(Theme.surface, 0.82)
                }
                GradientStop {
                    position: 0.65
                    color: Theme.alpha(Theme.surface, 0.45)
                }
                GradientStop {
                    position: 1.0
                    color: Theme.alpha(Theme.surface, 0.15)
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.cardPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spaceLg

            Rectangle {
                width: Math.min(profile.height - Style.cardPadding * 2, 96 * Style.uiScale)
                height: width
                radius: width / 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                NRoundedImage {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    source: root.avatar
                    fallbackGlyph: "person"
                    color: Theme.surfaceVariant
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                NText {
                    text: root.realName !== "" ? root.realName : root.user
                    size: Style.fontSizeHeader
                    weight: Font.Bold
                }
                NText {
                    text: root.user + "@" + (root.hostName || "localhost")
                    size: Style.fontSizeCaption
                }
                NText {
                    text: I18n.tr("control-center.home.uptime", "Uptime – {uptime}", {
                        uptime: Util.formatDuration(SystemMonitor.uptimeSeconds)
                    })
                    size: Style.fontSizeCaption
                }
                NText {
                    text: "Noctalia X11 · based on v5.3.0"
                    size: Style.fontSizeCaption
                    muted: true
                }
            }
        }

        NIconButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.spaceSm
            size: Style.controlHeightSm * 0.85
            icon: "wallpaper-selector"
            variant: "ghost"
            onClicked: Panels.open("wallpaper", root.screenRef, "", Panels.anchor, Panels.sourceBar, null)
        }
    }

    // ---------------------------------------------------------------- lower area
    Row {
        id: lower
        anchors.top: profile.bottom
        anchors.topMargin: root.gap
        width: parent.width
        height: parent.height - profile.height - root.gap
        spacing: root.gap

        readonly property real leftWidth: Math.round((width - spacing) * 1.66 / 2.66)

        Column {
            width: lower.leftWidth
            height: parent.height
            spacing: root.gap

            // media summary
            NCard {
                id: mediaCard
                width: parent.width
                height: Math.round((parent.height - root.gap) * 1.4 / 2.4)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTab("media")
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.cardPadding * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Style.cardPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spaceLg

                    Rectangle {
                        id: art
                        width: Math.min(mediaCard.height - Style.cardPadding * 2, 64 * Style.uiScale)
                        height: width
                        radius: width / 2
                        color: Theme.fgSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                        NRoundedImage {
                            anchors.fill: parent
                            radius: width / 2
                            visible: Media.artUrl !== ""
                            source: Media.artUrl
                            fallbackGlyph: ""
                        }
                        NIcon {
                            anchors.centerIn: parent
                            visible: Media.artUrl === ""
                            icon: "disc"
                            size: parent.width * 0.62
                            color: Theme.surfaceVariant
                        }
                    }

                    Column {
                        width: parent.width - art.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        NText {
                            width: parent.width
                            text: Media.hasPlayer ? Media.title : I18n.tr("control-center.media.nothing-playing", "Nothing playing")
                            weight: Font.Medium
                        }
                        NText {
                            width: parent.width
                            text: Media.hasPlayer ? (Media.artist || (Media.player ? Media.player.identity : "")) : I18n.tr("control-center.home.media.idle", "Idle")
                            size: Style.fontSizeCaption
                            muted: true
                        }
                        Row {
                            visible: Media.hasPlayer
                            spacing: Style.spaceXs
                            topPadding: Style.spaceXs
                            NIconButton {
                                icon: "media-prev"
                                variant: "ghost"
                                size: Style.controlHeightSm * 0.9
                                onClicked: Media.previous()
                            }
                            NIconButton {
                                icon: Media.isPlaying ? "media-pause" : "media-play"
                                variant: "primary"
                                size: Style.controlHeightSm * 0.9
                                onClicked: Media.togglePlaying()
                            }
                            NIconButton {
                                icon: "media-next"
                                variant: "ghost"
                                size: Style.controlHeightSm * 0.9
                                onClicked: Media.next()
                            }
                        }
                    }
                }

                NIcon {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.spaceMd
                    icon: "disc"
                    size: Style.fontSizeBody
                    color: Theme.fgSurfaceVariant
                }
            }

            // date / time / weather
            NCard {
                width: parent.width
                height: parent.height - mediaCard.height - root.gap

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTab("calendar")
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.cardPadding * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spaceLg

                    NText {
                        text: Util.formatTime(Config.get("shell.time_format", "{:%H:%M}"), root.now, Qt.locale())
                        size: 28 * Style.uiScale
                        weight: Font.Bold
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        NText {
                            text: Util.formatTime(Config.get("shell.date_format", "%A, %x"), root.now, Qt.locale())
                            size: Style.fontSizeCaption
                        }
                        Row {
                            visible: Weather.enabled && Weather.current !== null
                            spacing: Style.spaceXs
                            NIcon {
                                icon: Weather.current ? Weather.glyphFor(Weather.current.code, Weather.current.isDay) : "weather-cloud"
                                size: Style.fontSizeCaption + 2
                                color: Theme.primary
                            }
                            NText {
                                text: Weather.current ? Weather.temp(Weather.current.temp) + Weather.unitSymbol.slice(1) + " · " + Weather.describe(Weather.current.code) : ""
                                size: Style.fontSizeCaption
                            }
                        }
                    }
                }

                NIcon {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.spaceMd
                    icon: Weather.enabled && Weather.current ? Weather.glyphFor(Weather.current.code, Weather.current.isDay) : "calendar"
                    size: Style.fontSizeBody
                    color: Theme.fgSurfaceVariant
                }
            }
        }

        // shortcut grid
        Grid {
            id: grid
            width: parent.width - lower.leftWidth - parent.spacing
            height: parent.height
            columns: 2
            spacing: root.gap
            readonly property var items: {
                var s = Config.get("control_center.shortcuts", []);
                return (Array.isArray(s) ? s : []).slice(0, 6);
            }
            readonly property int rowCount: Math.max(1, Math.ceil(items.length / 2))

            Repeater {
                model: grid.items
                delegate: ShortcutTile {
                    required property var modelData
                    shortcut: modelData
                    width: (grid.width - grid.spacing) / 2
                    height: (grid.height - grid.spacing * (grid.rowCount - 1)) / grid.rowCount
                    onRequestTab: id => root.openTab(id)
                }
            }
        }
    }
}
