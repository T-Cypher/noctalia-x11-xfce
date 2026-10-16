import QtQuick
import qs.Commons
import qs.Widgets

// Generic list row: leading glyph, title/subtitle and an optional trailing item.
Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool clickable: true
    default property alias trailing: trailingRow.data
    signal clicked

    implicitHeight: Math.max(Style.controlHeightLg, texts.implicitHeight + Style.spaceSm * 2)
    radius: Style.radiusLg
    color: mouse.containsMouse && clickable ? Theme.alpha(Theme.hover, 0.18) : (active ? Theme.alpha(Theme.primary, 0.12) : "transparent")
    border.color: active ? Theme.alpha(Theme.primary, 0.5) : "transparent"
    border.width: active ? 1 : 0

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    NIcon {
        id: lead
        visible: root.glyph !== ""
        icon: root.glyph
        size: Style.baseGlyphSize * 1.15
        color: root.active ? Theme.primary : Theme.fgSurface
        anchors.left: parent.left
        anchors.leftMargin: Style.spaceMd
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        id: texts
        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: Style.spaceMd
        anchors.right: trailingRow.left
        anchors.rightMargin: Style.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        NText {
            width: parent.width
            text: root.title
            weight: root.active ? Font.Bold : Font.Medium
        }
        NText {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            size: Style.fontSizeCaption
            muted: true
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: Style.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spaceSm
    }
}
