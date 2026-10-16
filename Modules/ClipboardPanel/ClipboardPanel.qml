pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

// Clipboard history (text entries; pinned entries survive "clear").
Item {
    id: root

    required property var screenRef

    property string filter: ""
    readonly property var entries: {
        var list = Clipboard.entries.filter(e => filter === "" || e.text.toLowerCase().indexOf(filter.toLowerCase()) >= 0);
        return list.filter(e => e.pinned).concat(list.filter(e => !e.pinned));
    }
    property int selected: 0
    readonly property string autoPaste: String(Config.get("shell.clipboard_auto_paste", "auto"))

    implicitWidth: Math.round(560 * Style.uiScale)
    implicitHeight: Math.round(520 * Style.uiScale)

    onEntriesChanged: selected = Math.min(selected, Math.max(0, entries.length - 1))

    function focusFirst() {
        field.focusInput();
    }

    function pick(i) {
        var e = entries[i];
        if (!e)
            return;
        Clipboard.copy(e.text);
        Panels.close();
        if (autoPaste !== "off")
            Clipboard.pasteSoon();
    }

    Column {
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spaceMd

        Row {
            width: parent.width
            spacing: Style.spaceSm
            NTextField {
                id: field
                width: parent.width - clearBtn.width - parent.spacing
                icon: "search"
                placeholder: I18n.tr("clipboard.filter-placeholder", "Filter clipboard…")
                onTextChanged: root.filter = text
                onAccepted: root.pick(root.selected)
                onEscapePressed: Panels.close()
                onKeyNavigation: key => {
                    if (key === Qt.Key_Down || key === Qt.Key_Tab)
                        root.selected = Math.min(root.entries.length - 1, root.selected + 1);
                    else if (key === Qt.Key_Up || key === Qt.Key_Backtab)
                        root.selected = Math.max(0, root.selected - 1);
                    list.positionViewAtIndex(root.selected, ListView.Contain);
                }
                Keys.onDeletePressed: if (root.entries[root.selected])
                    Clipboard.remove(root.entries[root.selected].text)
            }
            NIconButton {
                id: clearBtn
                size: Style.controlHeight
                icon: "trash"
                onClicked: Clipboard.clear()
            }
        }

        Item {
            width: parent.width
            height: parent.height - Style.controlHeight - parent.spacing

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: Style.spaceXs
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    width: list.width - Style.spaceMd
                    height: Math.min(96 * Style.uiScale, txt.implicitHeight + Style.spaceMd * 2)
                    radius: Style.radiusLg
                    color: index === root.selected ? Theme.alpha(Theme.primary, 0.16) : Theme.surfaceVariant
                    border.color: index === root.selected ? Theme.alpha(Theme.primary, 0.6) : Theme.outline
                    border.width: 1

                    NText {
                        id: txt
                        anchors.left: parent.left
                        anchors.right: actions.left
                        anchors.top: parent.top
                        anchors.margins: Style.spaceMd
                        text: item.modelData.text.length > 600 ? item.modelData.text.slice(0, 600) + "…" : item.modelData.text
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        size: Style.fontSizeCaption
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(item.index)
                        onPositionChanged: root.selected = item.index
                    }

                    Row {
                        id: actions
                        anchors.right: parent.right
                        anchors.rightMargin: Style.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        NText {
                            text: Util.relativeTime(item.modelData.time)
                            size: Style.fontSizeMini
                            muted: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        NIconButton {
                            icon: item.modelData.pinned ? "pinned" : "pin"
                            variant: item.modelData.pinned ? "secondary" : "ghost"
                            size: Style.controlHeightSm * 0.85
                            onClicked: Clipboard.togglePin(item.modelData.text)
                        }
                        NIconButton {
                            icon: "close"
                            variant: "ghost"
                            size: Style.controlHeightSm * 0.85
                            onClicked: Clipboard.remove(item.modelData.text)
                        }
                    }
                }
            }
            NScrollBar {
                flickable: list
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }
            Column {
                anchors.centerIn: parent
                visible: root.entries.length === 0
                spacing: Style.spaceSm
                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "clipboard-off"
                    size: 40 * Style.uiScale
                    color: Theme.fgSurfaceVariant
                }
                NText {
                    text: Clipboard.enabled ? I18n.tr("clipboard.empty.history-title", "Clipboard history is empty") : "Clipboard history is disabled ([shell] clipboard_enabled)"
                    muted: true
                }
            }
        }
    }
}
