import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

// EWMH desktops as noctalia workspace pills (regular | minimal | focus_hint).
BarWidget {
    id: root

    readonly property string style: settings.style || "regular"
    readonly property bool showLabels: settings.show_labels !== false
    readonly property string labelSource: settings.label_source || "id"
    readonly property int maxLabelChars: Number(settings.max_label_chars !== undefined ? settings.max_label_chars : 1)
    readonly property real pillScale: Number(settings.pill_scale !== undefined ? settings.pill_scale : 1)
    readonly property real pillHeight: Math.round(16 * contentScale * pillScale)
    readonly property real activeSize: Number(settings.active_pill_size !== undefined ? settings.active_pill_size : 2.2)
    readonly property real inactiveSize: Number(settings.inactive_pill_size !== undefined ? settings.inactive_pill_size : 1.0)
    readonly property bool hideEmpty: settings.hide_when_empty === true
    readonly property bool labelsOnlyOccupied: settings.labels_only_when_occupied === true
    readonly property bool hoverColors: settings.change_color_on_hover !== false
    readonly property color focusedColor: Theme.resolve(settings.focused_color || "primary")
    readonly property color occupiedColor: Theme.resolve(settings.occupied_color || "secondary")
    readonly property color emptyColor: Theme.resolve(settings.empty_color || "secondary")
    readonly property color urgentColor: Theme.resolve(settings.urgent_color || "error")

    padding: Style.spaceXs * contentScale
    tooltipText: ""

    function label(i) {
        var name = X11.desktopNames[i] || "";
        var numeric = String(i + 1);
        var l = labelSource === "name" && name.length > 0 ? name : numeric;
        if (!/^\d+$/.test(l) && maxLabelChars > 0)
            l = l.substr(0, maxLabelChars);
        return l;
    }

    Grid {
        id: pills
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: Style.spaceXs * root.contentScale
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: X11.desktopCount

            delegate: Item {
                id: pill
                required property int index
                readonly property bool active: index === X11.currentDesktop
                readonly property bool occupied: X11.desktopOccupied(index)
                readonly property bool urgent: X11.desktopUrgent(index)
                readonly property bool hovered: pillMouse.containsMouse
                readonly property bool showLabel: root.showLabels && root.style !== "focus_hint" && (!root.labelsOnlyOccupied || occupied || active)
                readonly property real mainSize: root.style === "focus_hint" && !active ? root.pillHeight * 0.5 : Math.max(root.pillHeight * (active ? root.activeSize : root.inactiveSize), labelText.implicitWidth + root.pillHeight * 0.5)
                readonly property color fill: urgent ? root.urgentColor : active ? root.focusedColor : occupied ? root.occupiedColor : root.emptyColor

                visible: !(root.hideEmpty && !occupied && !active)
                width: root.vertical ? root.pillHeight : mainSize
                height: root.vertical ? mainSize : root.pillHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Style.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Style.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.style === "focus_hint" && !pill.active ? root.pillHeight * 0.5 : parent.width
                    height: root.style === "focus_hint" && !pill.active ? root.pillHeight * 0.5 : parent.height
                    radius: Math.min(width, height) / 2
                    visible: root.style !== "minimal"
                    color: pill.hovered && root.hoverColors ? Theme.hover : pill.fill
                    opacity: pill.active || pill.occupied || pill.urgent || pill.hovered ? 1 : 0.55
                    Behavior on color {
                        ColorAnimation {
                            duration: Style.animFast
                        }
                    }
                }

                NText {
                    id: labelText
                    anchors.centerIn: parent
                    visible: pill.showLabel || root.style === "minimal"
                    text: root.label(pill.index)
                    size: (root.style === "minimal" ? 14 : 11) * root.contentScale
                    weight: Font.Bold
                    elide: Text.ElideNone
                    color: {
                        if (root.style === "minimal")
                            return pill.hovered && root.hoverColors ? Theme.hover : pill.fill;
                        if (pill.hovered && root.hoverColors)
                            return Theme.fgHover;
                        if (pill.urgent)
                            return Theme.fgError;
                        if (pill.active)
                            return Theme.fgPrimary;
                        return Theme.fgSecondary;
                    }
                }

                NAppIcon {
                    anchors.centerIn: parent
                    visible: root.style === "focus_hint" && pill.active && root.settings.show_icons !== false && X11.activeWindow !== null
                    size: root.pillHeight * 0.8
                    source: X11.activeWindow ? Apps.iconForClass(X11.activeWindow.appId, X11.activeWindow.instance) : ""
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: X11.switchDesktop(pill.index)
                }
            }
        }
    }
}
