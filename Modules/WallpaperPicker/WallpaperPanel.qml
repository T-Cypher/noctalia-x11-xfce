pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

// Wallpaper picker: thumbnails from [wallpaper].directory (or XDG Pictures), applied through
// xfdesktop/feh/xwallpaper. Supports per-monitor selection and random/next.
Item {
    id: root

    required property var screenRef

    property string filter: ""
    property string target: Quickshell.screens.length > 1 ? screenRef.name : "*"
    readonly property var files: Wallpaper.files.filter(f => filter === "" || Util.fuzzyScore(filter, Util.basename(f)) >= 0)
    property int selected: Math.max(0, files.indexOf(Wallpaper.current(target === "*" ? screenRef.name : target)))

    implicitWidth: Math.round(760 * Style.uiScale)
    implicitHeight: Math.round(520 * Style.uiScale)

    Component.onCompleted: if (Wallpaper.files.length === 0)
        Wallpaper.scan()

    function focusFirst() {
        field.focusInput();
    }

    function apply(i) {
        var f = files[i];
        if (f)
            Wallpaper.set(target, f);
    }

    Column {
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spaceMd

        Row {
            width: parent.width
            height: Style.controlHeight
            spacing: Style.spaceSm

            NTextField {
                id: field
                width: parent.width - actions.width - parent.spacing
                icon: "search"
                placeholder: I18n.tr("wallpaper.search", "Search wallpapers…") + "  (" + Wallpaper.files.length + " in " + Wallpaper.directory + ")"
                onTextChanged: root.filter = text
                onAccepted: root.apply(root.selected)
                onEscapePressed: Panels.close()
                onKeyNavigation: key => {
                    var cols = grid.columns;
                    if (key === Qt.Key_Right)
                        root.selected = Math.min(root.files.length - 1, root.selected + 1);
                    else if (key === Qt.Key_Left)
                        root.selected = Math.max(0, root.selected - 1);
                    else if (key === Qt.Key_Down || key === Qt.Key_Tab)
                        root.selected = Math.min(root.files.length - 1, root.selected + cols);
                    else if (key === Qt.Key_Up || key === Qt.Key_Backtab)
                        root.selected = Math.max(0, root.selected - cols);
                    grid.positionViewAtIndex(root.selected, GridView.Contain);
                }
            }

            Row {
                id: actions
                spacing: Style.spaceSm
                Repeater {
                    model: Quickshell.screens.length > 1 ? ["*"].concat(Quickshell.screens.map(s => s.name)) : []
                    delegate: NButton {
                        required property var modelData
                        height: Style.controlHeight
                        text: modelData === "*" ? I18n.tr("launcher.browser.navigation.all", "All") : modelData
                        fontSize: Style.fontSizeCaption
                        variant: root.target === modelData ? "tabActive" : "tab"
                        onClicked: root.target = modelData
                    }
                }
                NIconButton {
                    size: Style.controlHeight
                    icon: "arrows-shuffle"
                    onClicked: Wallpaper.random(root.target)
                }
                NIconButton {
                    size: Style.controlHeight
                    icon: "refresh"
                    onClicked: Wallpaper.scan()
                }
                NIconButton {
                    size: Style.controlHeight
                    icon: "folder-open"
                    onClicked: Quickshell.execDetached(["xdg-open", Wallpaper.directory])
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - Style.controlHeight - parent.spacing

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                readonly property int columns: Math.max(2, Math.floor(width / (180 * Style.uiScale)))
                cellWidth: width / columns
                cellHeight: cellWidth * 0.64
                model: root.files
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCurrent: Wallpaper.current(root.target === "*" ? root.screenRef.name : root.target) === modelData

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Style.spaceXs
                        radius: Style.radiusLg + 2
                        color: "transparent"
                        border.width: cell.index === root.selected || cell.isCurrent ? 2 : 0
                        border.color: cell.isCurrent ? Theme.primary : Theme.secondary

                        NRoundedImage {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Style.radiusLg
                            source: "file://" + cell.modelData
                            fillMode: Image.PreserveAspectCrop
                            scale: thumbMouse.containsMouse ? 1.02 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Style.animFast
                                }
                            }
                        }
                        Rectangle {
                            visible: cell.isCurrent
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Style.spaceSm
                            width: 22 * Style.uiScale
                            height: width
                            radius: width / 2
                            color: Theme.primary
                            NIcon {
                                anchors.centerIn: parent
                                icon: "check"
                                size: parent.width * 0.65
                                color: Theme.fgPrimary
                            }
                        }
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selected = cell.index;
                            root.apply(cell.index);
                        }
                    }
                }
            }

            NScrollBar {
                flickable: grid
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            Column {
                anchors.centerIn: parent
                visible: root.files.length === 0
                spacing: Style.spaceSm
                NIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: "photo-off"
                    size: 40 * Style.uiScale
                    color: Theme.fgSurfaceVariant
                }
                NText {
                    text: Wallpaper.scanning ? I18n.tr("wallpaper.scanning", "Scanning…") : I18n.tr("wallpaper.empty", "No images found in") + " " + Wallpaper.directory
                    muted: true
                }
            }
        }
    }
}
