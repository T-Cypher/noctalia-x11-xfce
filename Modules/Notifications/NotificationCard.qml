pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

// Notification card used by toasts and the history list (ListModel role properties).
NCard {
    id: root

    required property int nid
    required property string summary
    required property string body
    required property string appName
    required property string appIcon
    required property string image
    required property string urgency
    required property real time
    required property real timeout
    required property string actionsJson
    required property string glyph
    required property bool internal

    property bool compact: false
    property bool historyMode: false
    property bool expanded: false
    readonly property var actions: {
        try {
            return JSON.parse(actionsJson);
        } catch (e) {
            return [];
        }
    }
    readonly property bool critical: urgency === "critical"
    readonly property bool hovered: hover.hovered
    property real elapsed: 0
    property real nowTick: Date.now()

    signal expired

    color: Theme.alpha(historyMode ? Theme.surfaceVariant : Theme.surface, historyMode ? 1 : Number(Config.get("notification.background_opacity", 0.97)))
    border.color: critical ? Theme.error : Theme.resolve(Config.get("notification.border_color", "outline"))
    border.width: Config.get("notification.border", true) === false && !historyMode ? 0 : Math.max(1, Number(Config.get("notification.border_width", 1)))
    implicitHeight: content.implicitHeight + Style.cardPadding * 2
    clip: true

    HoverHandler {
        id: hover
    }

    // timeout
    Timer {
        id: tick
        interval: 50
        repeat: true
        running: !root.historyMode && root.timeout > 0 && !root.hovered
        onTriggered: {
            root.elapsed += interval;
            if (root.elapsed >= root.timeout) {
                running = false;
                root.expired();
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowTick = Date.now()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.historyMode)
                    root.expanded = !root.expanded;
                else if (Config.get("notification.show_actions", true) === false || root.actions.length === 0)
                    Notifications.invokeDefault(root.nid);
                else
                    Notifications.invokeDefault(root.nid);
            } else {
                if (root.historyMode)
                    Notifications.removeHistory(root.nid);
                else
                    Notifications.dismiss(root.nid);
            }
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.cardPadding
        spacing: Style.spaceSm

        Row {
            width: parent.width
            spacing: Style.spaceMd

            // icon / image
            Item {
                id: leading
                width: root.compact ? 32 * Style.uiScale : 40 * Style.uiScale
                height: width

                readonly property string imgSrc: {
                    var im = root.image;
                    if (im !== "")
                        return im.indexOf("/") === 0 ? "file://" + im : im;
                    return "";
                }
                readonly property string iconSrc: {
                    var ic = root.appIcon;
                    if (ic === "")
                        return "";
                    if (ic.indexOf("/") === 0)
                        return "file://" + ic;
                    if (ic.indexOf("://") > 0)
                        return ic;
                    return Quickshell.iconPath(ic, true);
                }

                NRoundedImage {
                    anchors.fill: parent
                    radius: Style.radiusLg
                    visible: leading.imgSrc !== "" && hasImage
                    source: leading.imgSrc
                    fallbackGlyph: ""
                }
                IconImage {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: leading.imgSrc === "" && leading.iconSrc !== ""
                    source: leading.iconSrc
                    asynchronous: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusLg
                    visible: leading.imgSrc === "" && leading.iconSrc === ""
                    color: root.critical ? Theme.alpha(Theme.error, 0.2) : Theme.alpha(Theme.primary, 0.15)
                    NIcon {
                        anchors.centerIn: parent
                        icon: root.glyph !== "" ? root.glyph : (root.critical ? "toast-warning" : "bell")
                        size: parent.width * 0.5
                        color: root.critical ? Theme.error : Theme.primary
                    }
                }
            }

            Column {
                width: parent.width - leading.width - parent.spacing - closeBtn.width - Style.spaceXs
                spacing: 2

                Row {
                    width: parent.width
                    spacing: Style.spaceXs
                    NText {
                        visible: Config.get("notification.show_app_name", true) !== false && root.appName !== ""
                        text: root.appName
                        size: Style.fontSizeMini
                        muted: true
                        width: Math.min(implicitWidth, parent.width - stamp.width - Style.spaceXs)
                    }
                    NText {
                        id: stamp
                        text: "· " + Util.relativeTime(root.time, root.nowTick)
                        size: Style.fontSizeMini
                        muted: true
                    }
                }
                NText {
                    width: parent.width
                    text: root.summary
                    weight: Font.Bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                Text {
                    width: parent.width
                    visible: root.body !== ""
                    text: root.body.replace(/\n/g, "<br>")
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.expanded ? 20 : (root.compact ? 2 : 4)
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeCaption
                    color: Theme.fgSurfaceVariant
                    linkColor: Theme.primary
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            NIconButton {
                id: closeBtn
                icon: "close"
                variant: "ghost"
                size: Style.controlHeightSm * 0.8
                onClicked: root.historyMode ? Notifications.removeHistory(root.nid) : Notifications.dismiss(root.nid)
            }
        }

        Row {
            visible: !root.historyMode && root.actions.length > 0 && Config.get("notification.show_actions", true) !== false
            width: parent.width
            spacing: Style.spaceSm
            Repeater {
                model: root.actions.filter(a => a.identifier !== "default" || root.actions.length === 1)
                delegate: NButton {
                    required property var modelData
                    width: (content.width - Style.spaceSm * Math.max(0, root.actions.length - 1)) / Math.max(1, root.actions.length)
                    height: Style.controlHeightSm
                    text: modelData.text || modelData.identifier
                    fontSize: Style.fontSizeCaption
                    onClicked: Notifications.invoke(root.nid, modelData.identifier)
                }
            }
        }
    }

    // timeout progress
    Rectangle {
        visible: !root.historyMode && root.timeout > 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: Style.radiusXl / 2
        height: 2
        radius: 1
        width: Math.max(0, (parent.width - Style.radiusXl) * (1 - root.elapsed / Math.max(1, root.timeout)))
        color: root.critical ? Theme.error : Theme.primary
        opacity: 0.7
    }
}
