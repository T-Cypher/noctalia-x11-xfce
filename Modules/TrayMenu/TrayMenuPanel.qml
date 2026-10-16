pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets

// noctalia-styled DBusMenu for a tray item (with submenu navigation).
Item {
    id: root

    required property var screenRef
    readonly property var item: Panels.payload
    property var stack: []          // submenu handles
    readonly property var currentMenu: stack.length > 0 ? stack[stack.length - 1] : (item ? item.menu : null)

    implicitWidth: Math.round(260 * Style.uiScale)
    implicitHeight: Math.min(Math.round(560 * Style.uiScale), column.implicitHeight + Style.spaceSm * 2)

    function focusFirst() {
        keys.forceActiveFocus();
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (root.stack.length > 0)
                root.stack = root.stack.slice(0, -1);
            else
                Panels.close();
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Style.spaceSm
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width

            NButton {
                visible: root.stack.length > 0
                width: parent.width
                height: Style.controlHeightSm
                variant: "ghost"
                icon: "chevron-left"
                text: I18n.tr("control-center.screen-time.back", "Back")
                onClicked: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children
                delegate: Item {
                    id: entry
                    required property var modelData
                    width: column.width
                    height: modelData.isSeparator ? 9 : Style.controlHeightSm

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - Style.spaceMd * 2
                        height: 1
                        color: Theme.outline
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: Style.radiusMd
                        color: m.containsMouse && entry.modelData.enabled ? Theme.hover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Style.spaceSm
                            anchors.right: parent.right
                            anchors.rightMargin: Style.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.spaceSm

                            Item {
                                width: Style.baseGlyphSize
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                IconImage {
                                    anchors.fill: parent
                                    visible: entry.modelData.icon !== ""
                                    source: entry.modelData.icon
                                }
                                NIcon {
                                    anchors.centerIn: parent
                                    visible: entry.modelData.icon === "" && entry.modelData.checkState !== Qt.Unchecked
                                    icon: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "point-filled" : "check"
                                    size: Style.baseGlyphSize
                                    color: m.containsMouse ? Theme.fgHover : Theme.primary
                                }
                            }
                            NText {
                                width: parent.width - Style.baseGlyphSize * 2 - Style.spaceSm * 2
                                text: entry.modelData.text.replace(/_([^_])/g, "$1")
                                color: !entry.modelData.enabled ? Theme.alpha(Theme.fgSurface, 0.45) : (m.containsMouse ? Theme.fgHover : Theme.fgSurface)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            NIcon {
                                visible: entry.modelData.hasChildren
                                icon: "chevron-right"
                                size: Style.baseGlyphSize
                                color: m.containsMouse ? Theme.fgHover : Theme.fgSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: m
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    root.stack = root.stack.concat([entry.modelData]);
                                } else {
                                    entry.modelData.triggered();
                                    Panels.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
