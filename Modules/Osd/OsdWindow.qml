import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// On-screen display card (noctalia's OsdOverlay geometry). [osd] position / position_vertical /
// orientation / offsets / monitors / follow_focused_output. Text-only content is always
// horizontal; vertical orientation (with position_vertical) applies to level OSDs.
PanelWindow {
    id: win

    required property var screenRef
    screen: screenRef

    readonly property bool vertical: Osd.hasProgress && String(Config.get("osd.orientation", "horizontal")) === "vertical"
    readonly property string position: {
        var p = String(Config.get(vertical ? "osd.position_vertical" : "osd.position", "top_center"));
        return ["top_left", "top_center", "top_right", "bottom_left", "bottom_center", "bottom_right", "center_left", "center_right"].indexOf(p) >= 0 ? p : "top_center";
    }
    readonly property real s: Math.max(0.1, Number(Config.get("osd.scale", 1))) * Style.uiScale
    // Base units (noctalia style.h tokens before scaling)
    readonly property real cardLength: (38 * 6 + 12 + 8 + 4) * s
    readonly property real cardW: vertical ? (38 + 16 + 12) * s : cardLength
    readonly property real cardH: vertical ? cardLength : (38 + 8) * s
    readonly property real pad: 12 * s
    readonly property real gap: (8 + 2) * s
    readonly property real glyphSize: (16 + 4) * s
    readonly property real progressThickness: (4 + 2) * s
    readonly property color accent: Osd.overLimit ? Theme.error : (Osd.inactive ? Theme.fgSurfaceVariant : Theme.primary)
    readonly property color valueColor: Osd.overLimit ? Theme.error : (Osd.inactive ? Theme.fgSurfaceVariant : Theme.fgSurface)
    property bool showing: false

    anchors.top: position.indexOf("top_") === 0
    anchors.bottom: position.indexOf("bottom_") === 0
    anchors.left: /_left$/.test(position)
    anchors.right: /_right$/.test(position)
    margins.top: anchors.top ? Math.max(0, Number(Config.get("osd.offset_y", 8))) : 0
    margins.bottom: anchors.bottom ? Math.max(0, Number(Config.get("osd.offset_y", 8))) : 0
    margins.left: anchors.left ? Math.max(0, Number(Config.get("osd.offset_x", 20))) : 0
    margins.right: anchors.right ? Math.max(0, Number(Config.get("osd.offset_x", 20))) : 0

    implicitWidth: Math.ceil(cardW)
    implicitHeight: Math.ceil(cardH)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"
    mask: Region {}

    readonly property bool onThisScreen: {
        if (Config.get("osd.follow_focused_output", false) === true)
            return Osd.targetScreen === screenRef.name;
        return Config.screenAllowed(Config.get("osd.monitors", []), screenRef);
    }
    visible: showing && onThisScreen

    Connections {
        target: Osd
        function onVisibleChanged() {
            if (Osd.visible) {
                hideAnim.stop();
                win.showing = true;
                showAnim.restart();
            } else {
                showAnim.stop();
                hideAnim.restart();
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: Style.animFast
        }
        NumberAnimation {
            target: card
            property: "reveal"
            to: 1
            duration: Style.animNormal
            easing.type: Easing.OutCubic
        }
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: Style.animNormal
        }
        ScriptAction {
            script: {
                card.reveal = 0.85;
                win.showing = false;
            }
        }
    }

    Rectangle {
        id: card
        property real reveal: 0.85
        anchors.fill: parent
        opacity: 0
        scale: reveal
        transformOrigin: win.anchors.top ? Item.Top : (win.anchors.bottom ? Item.Bottom : (win.anchors.left ? Item.Left : Item.Right))
        radius: Math.min(Math.min(width, height) / 2, 12 * Style.cornerScale * win.s)
        color: Theme.alpha(Theme.surface, Number(Config.get("osd.background_opacity", 0.97)))
        border.color: Theme.resolve(Config.get("osd.border_color", "outline"))
        border.width: Config.get("osd.border", true) === false ? 0 : Math.max(0, Number(Config.get("osd.border_width", 1))) * win.s

        // horizontal: icon, progress (flex), value  /  icon + value centered (text OSDs)
        Row {
            visible: !win.vertical
            anchors.verticalCenter: parent.verticalCenter
            x: Osd.hasProgress ? win.pad : Math.round((parent.width - width) / 2)
            spacing: win.gap

            NIcon {
                icon: Osd.icon
                size: win.glyphSize
                color: win.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                visible: Osd.hasProgress
                width: card.width - win.pad * 2 - win.glyphSize - valueLabel.width - win.gap * 2
                height: win.progressThickness
                radius: Math.min(height / 2, 3 * Style.cornerScale * win.s)
                color: Theme.surfaceVariant
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, Osd.progress))
                    color: win.accent
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animFast
                        }
                    }
                }
            }
            NText {
                id: valueLabel
                text: Osd.value
                size: 14 * win.s
                weight: Font.Bold
                color: win.valueColor
                horizontalAlignment: Osd.hasProgress ? Text.AlignRight : Text.AlignHCenter
                elide: Text.ElideRight
                // "100%" reserves its width beside the bar; text OSDs are capped to the card.
                width: Osd.hasProgress ? Math.max(implicitWidth, pctMetrics.width) : Math.min(implicitWidth, card.width - win.pad * 2 - win.glyphSize - win.gap)
                anchors.verticalCenter: parent.verticalCenter
                TextMetrics {
                    id: pctMetrics
                    font: valueLabel.font
                    text: "100%"
                }
            }
        }

        // vertical: icon, progress (flex), value
        Column {
            visible: win.vertical
            anchors.fill: parent
            anchors.margins: win.pad
            spacing: win.gap

            NIcon {
                id: vIcon
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Osd.icon
                size: win.glyphSize
                color: win.accent
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.progressThickness * 1.75
                height: parent.height - vIcon.height - vValue.height - win.gap * 2
                radius: Math.min(width / 2, 3 * Style.cornerScale * win.s)
                color: Theme.surfaceVariant
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: parent.radius
                    height: parent.height * Math.max(0, Math.min(1, Osd.progress))
                    color: win.accent
                    Behavior on height {
                        NumberAnimation {
                            duration: Style.animFast
                        }
                    }
                }
            }
            NText {
                id: vValue
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Osd.value
                size: 14 * win.s
                weight: Font.Bold
                color: win.valueColor
            }
        }
    }
}
