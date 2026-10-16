import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// On-screen display ([osd] position/offsets/orientation, top_right by default).
PanelWindow {
    id: win

    required property var screenRef
    screen: screenRef

    readonly property string position: String(Config.get("osd.position", "top_center"))
    readonly property bool verticalOsd: position.indexOf("center_") === 0 && String(Config.get("osd.orientation", "horizontal")) !== "horizontal" || position.indexOf("center_left") === 0 || position.indexOf("center_right") === 0
    readonly property real s: Number(Config.get("osd.scale", 1)) * Style.uiScale
    readonly property bool hasBar: Osd.value >= 0
    property bool showing: false

    anchors.top: position.indexOf("top") === 0
    anchors.bottom: position.indexOf("bottom") === 0
    anchors.left: position.indexOf("left") >= 0
    anchors.right: position.indexOf("right") >= 0
    margins.top: anchors.top ? Number(Config.get("osd.offset_y", 8)) : 0
    margins.bottom: anchors.bottom ? Number(Config.get("osd.offset_y", 8)) : 0
    margins.left: anchors.left ? Number(Config.get("osd.offset_x", 20)) : 0
    margins.right: anchors.right ? Number(Config.get("osd.offset_x", 20)) : 0

    implicitWidth: verticalOsd ? 52 * s : (hasBar ? 300 * s : Math.max(160 * s, label.implicitWidth + 72 * s))
    implicitHeight: verticalOsd ? 240 * s : 52 * s
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"

    readonly property bool onThisScreen: {
        var mons = Config.get("osd.monitors", []);
        if (Array.isArray(mons) && mons.length > 0)
            return mons.indexOf(screenRef.name) >= 0;
        var aw = X11.activeWindow;
        var target = aw ? X11.screenOf(aw) : Quickshell.screens[0];
        return target !== null && target !== undefined && target.name === screenRef.name;
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

    NumberAnimation {
        id: showAnim
        target: body
        property: "opacity"
        to: 1
        duration: Style.animFast
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation {
            target: body
            property: "opacity"
            to: 0
            duration: Style.animNormal
        }
        ScriptAction {
            script: win.showing = false
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        opacity: 0
        radius: Style.composited ? Math.min(width, height) / 2 : 0
        color: Theme.alpha(Theme.surface, Number(Config.get("osd.background_opacity", 0.97)))
        border.color: Theme.resolve(Config.get("osd.border_color", "outline"))
        border.width: Config.get("osd.border", true) === false ? 0 : Number(Config.get("osd.border_width", 1))

        // horizontal layout
        Row {
            visible: !win.verticalOsd
            anchors.fill: parent
            anchors.leftMargin: 16 * win.s
            anchors.rightMargin: 18 * win.s
            spacing: 12 * win.s

            NIcon {
                icon: Osd.glyph
                size: 20 * win.s
                color: Osd.muted ? Theme.fgSurfaceVariant : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: win.hasBar
                width: parent.width - 20 * win.s - pct.width - parent.spacing * 2
                height: 8 * win.s
                radius: height / 2
                color: Theme.surfaceVariant
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: parent.width * Math.max(0, Math.min(1, Osd.value / Math.max(0.01, Osd.maxValue)))
                    color: Osd.muted ? Theme.fgSurfaceVariant : (Osd.value > 1.001 ? Theme.error : Theme.primary)
                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animFast
                        }
                    }
                }
            }

            NText {
                id: pct
                visible: win.hasBar
                width: 40 * win.s
                horizontalAlignment: Text.AlignRight
                text: Math.round(Osd.value * 100) + "%"
                weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            NText {
                id: label
                visible: !win.hasBar
                text: Osd.label
                weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // vertical layout
        Column {
            visible: win.verticalOsd
            anchors.fill: parent
            anchors.topMargin: 16 * win.s
            anchors.bottomMargin: 14 * win.s
            spacing: 10 * win.s
            NText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.hasBar ? Math.round(Osd.value * 100) : ""
                size: Style.fontSizeCaption
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 8 * win.s
                height: parent.height - 70 * win.s
                radius: width / 2
                color: Theme.surfaceVariant
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: width / 2
                    height: parent.height * Math.max(0, Math.min(1, Osd.value / Math.max(0.01, Osd.maxValue)))
                    color: Osd.muted ? Theme.fgSurfaceVariant : Theme.primary
                }
            }
            NIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: Osd.glyph
                size: 20 * win.s
                color: Theme.primary
            }
        }
    }
}
