pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

// Session menu (lock, log out, lock & suspend, reboot, shut down + custom entries).
Item {
    id: root

    required property var screenRef

    readonly property var actions: Session.actions
    readonly property bool gridMode: Config.get("shell.session.grid", false) === true
    readonly property int count: Math.max(1, actions.length)
    readonly property int cols: gridMode ? Math.min(Math.max(1, Number(Config.get("shell.session.grid_columns", 3))), count) : (count <= 5 ? count : Math.min(5, Math.ceil(count / 2)))
    readonly property int rows: Math.ceil(count / cols)
    readonly property real bw: 152 * Style.uiScale
    readonly property real bh: 112 * Style.uiScale
    readonly property bool showShortcuts: Config.get("shell.session.show_shortcuts", true) !== false
    property int selected: 0
    property int armed: -1
    property real armedProgress: 0

    implicitWidth: Math.round(cols * bw + (cols - 1) * Style.spaceMd + Style.panelPadding * 2)
    implicitHeight: Math.round(rows * bh + (rows - 1) * Style.spaceMd + Style.panelPadding * 2)

    function focusFirst() {
        keys.forceActiveFocus();
    }

    function trigger(i) {
        var a = actions[i];
        if (!a)
            return;
        var cd = Number(a.countdown_seconds || 0);
        if (cd > 0 && armed !== i) {
            armed = i;
            armedProgress = 0;
            countdown.duration = cd * 1000;
            countdown.restart();
            return;
        }
        countdown.stop();
        armed = -1;
        Panels.close();
        Session.run(a);
    }

    NumberAnimation {
        id: countdown
        target: root
        property: "armedProgress"
        from: 0
        to: 1
        onFinished: if (root.armed >= 0)
            root.trigger(root.armed)
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.armed >= 0) {
                    countdown.stop();
                    root.armed = -1;
                } else {
                    Panels.close();
                }
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.selected = (root.selected + 1) % root.count;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                root.selected = (root.selected - 1 + root.count) % root.count;
            } else if (event.key === Qt.Key_Down) {
                root.selected = Math.min(root.count - 1, root.selected + root.cols);
            } else if (event.key === Qt.Key_Up) {
                root.selected = Math.max(0, root.selected - root.cols);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.trigger(root.selected);
            } else {
                var t = event.text;
                for (var i = 0; i < root.actions.length; i++) {
                    var sc = root.actions[i].shortcut !== undefined ? String(root.actions[i].shortcut) : (i < 9 ? String(i + 1) : "");
                    if (t !== "" && sc.toLowerCase() === t.toLowerCase()) {
                        root.trigger(i);
                        break;
                    }
                }
                return;
            }
            event.accepted = true;
        }
    }

    Grid {
        anchors.centerIn: parent
        columns: root.cols
        spacing: Style.spaceMd

        Repeater {
            model: root.actions
            delegate: NButton {
                id: btn
                required property var modelData
                required property int index
                width: root.bw
                height: root.bh
                vertical: true
                icon: Session.glyph(modelData)
                text: Session.label(modelData)
                iconSize: 30 * Style.uiScale
                radius: Style.radiusXl
                variant: modelData.variant === "destructive" || (modelData.variant === undefined && modelData.action === "shutdown") ? "destructive" : (modelData.variant || "default")
                selected: index === root.selected && !hovered
                onClicked: root.trigger(index)
                onHoveredChanged: if (hovered)
                    root.selected = index

                NText {
                    visible: root.showShortcuts
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Style.spaceSm
                    text: btn.modelData.shortcut !== undefined ? String(btn.modelData.shortcut) : (btn.index < 9 ? String(btn.index + 1) : "")
                    size: Style.fontSizeMini
                    color: btn.foreground
                    opacity: 0.6
                }

                // countdown overlay
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: root.armed === btn.index
                    color: Theme.alpha(Theme.shadow, 0.58)
                    Canvas {
                        id: ring
                        anchors.centerIn: parent
                        width: parent.height * 0.6
                        height: width
                        property real p: root.armedProgress
                        onPChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 4;
                            ctx.strokeStyle = Theme.alpha(Theme.fgSurface, 0.25);
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 2);
                            ctx.stroke();
                            ctx.strokeStyle = Theme.error;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 3, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - p));
                            ctx.stroke();
                        }
                    }
                    NText {
                        anchors.centerIn: parent
                        text: Math.ceil((1 - root.armedProgress) * Number(btn.modelData.countdown_seconds || 0))
                        size: Style.fontSizeHeader
                        weight: Font.Bold
                    }
                }
            }
        }
    }
}
