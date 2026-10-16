import QtQuick
import qs.Commons

// noctalia ButtonVariant styles: default | primary | secondary | destructive | outline | ghost | tab | tabActive
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "default"
    property bool selected: false
    property bool enabled_: true
    property real iconSize: Style.baseGlyphSize
    property real fontSize: Style.fontSizeBody
    property real paddingH: Style.spaceMd
    property bool vertical: false   // icon above label (shortcut tiles)
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked
    signal rightClicked

    implicitHeight: vertical ? Math.max(Style.controlHeightLg, column.implicitHeight + Style.spaceSm * 2) : Style.controlHeight
    implicitWidth: vertical ? Math.max(implicitHeight, column.implicitWidth + paddingH * 2) : row.implicitWidth + paddingH * 2
    radius: Style.radiusLg

    readonly property var colors: {
        var st = !enabled_ ? "disabled" : pressed ? "pressed" : hovered ? "hover" : "normal";
        var hoverSet = [Theme.hover, "transparent", Theme.fgHover];
        var pressedSet = [Theme.primary, Theme.primary, Theme.fgPrimary];
        if (selected && st === "normal")
            return [Theme.secondary, "transparent", Theme.fgSecondary];
        switch (variant) {
        case "primary":
            return st === "hover" ? hoverSet : st === "disabled" ? [Theme.alpha(Theme.primary, 0.5), "transparent", Theme.fgPrimary] : [Theme.primary, "transparent", Theme.fgPrimary];
        case "secondary":
            return st === "hover" ? hoverSet : st === "pressed" ? pressedSet : [Theme.secondary, Theme.outline, Theme.fgSecondary];
        case "destructive":
            return st === "hover" ? hoverSet : st === "pressed" ? [Theme.error, Theme.error, Theme.fgError] : [Theme.error, Theme.outline, Theme.fgError];
        case "outline":
            return st === "hover" ? hoverSet : st === "pressed" ? pressedSet : [Theme.surface, Theme.outline, Theme.fgSurface];
        case "ghost":
        case "tab":
            return st === "hover" ? hoverSet : st === "pressed" ? [Theme.surfaceVariant, "transparent", Theme.fgSurface] : st === "disabled" ? ["transparent", "transparent", Theme.alpha(Theme.fgSurface, 0.5)] : ["transparent", "transparent", Theme.fgSurface];
        case "tabActive":
            return [Theme.primary, "transparent", Theme.fgPrimary];
        default:
            return st === "hover" ? hoverSet : st === "pressed" ? pressedSet : st === "disabled" ? [Theme.alpha(Theme.surfaceVariant, 0.5), Theme.alpha(Theme.outline, 0.5), Theme.alpha(Theme.fgSurface, 0.5)] : [Theme.surfaceVariant, Theme.outline, Theme.fgSurface];
        }
    }
    readonly property color foreground: colors[2]

    color: colors[0]
    border.color: colors[1]
    border.width: Qt.colorEqual(colors[1], "transparent") ? 0 : Style.borderWidth
    opacity: enabled_ ? 1 : 0.85

    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: Style.spaceSm
        NIcon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.iconSize
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.text !== ""
            text: root.text
            size: root.fontSize
            weight: Font.Medium
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: Style.spaceXs
        NIcon {
            visible: root.icon !== ""
            icon: root.icon
            size: root.iconSize
            color: root.foreground
            anchors.horizontalCenter: parent.horizontalCenter
        }
        NText {
            visible: root.text !== ""
            text: root.text
            size: root.fontSize
            color: root.foreground
            width: Math.min(implicitWidth, root.width - Style.spaceSm * 2)
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled_
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
