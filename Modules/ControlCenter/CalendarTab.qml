pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Widgets
import "../../Commons/Util.js" as Util

// Month grid (ISO weeks optional). Calendar accounts (CalDAV/ICS) are not ported.
Item {
    id: root

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property bool weekNumbers: Config.get("control_center.calendar.show_week_numbers", false) === true
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday

    function shift(delta) {
        var m = month + delta;
        year += Math.floor(m / 12);
        month = ((m % 12) + 12) % 12;
    }

    readonly property var cells: {
        var first = new Date(year, month, 1);
        var offset = (first.getDay() - firstDay + 7) % 7;
        var start = new Date(year, month, 1 - offset);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                isToday: d.toDateString() === today.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6,
                week: Util.isoWeek(d).week
            });
        }
        return out;
    }

    NCard {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Style.cardPadding
            spacing: Style.spaceSm

            Item {
                width: parent.width
                height: Style.controlHeightSm
                NIconButton {
                    id: prev
                    icon: "chevron-left"
                    variant: "ghost"
                    anchors.left: parent.left
                    onClicked: root.shift(-1)
                }
                NText {
                    anchors.centerIn: parent
                    text: Qt.locale().standaloneMonthName(root.month, 0) + " " + root.year
                    size: Style.fontSizeTitle
                    weight: Font.Bold
                }
                Row {
                    anchors.right: parent.right
                    spacing: Style.spaceXs
                    NButton {
                        visible: root.month !== root.today.getMonth() || root.year !== root.today.getFullYear()
                        text: I18n.tr("control-center.calendar.today", "Today")
                        height: Style.controlHeightSm
                        fontSize: Style.fontSizeCaption
                        variant: "ghost"
                        onClicked: {
                            root.year = root.today.getFullYear();
                            root.month = root.today.getMonth();
                        }
                    }
                    NIconButton {
                        icon: "chevron-right"
                        variant: "ghost"
                        onClicked: root.shift(1)
                    }
                }
            }

            Grid {
                id: grid
                width: parent.width
                columns: root.weekNumbers ? 8 : 7
                readonly property real cw: width / columns
                readonly property real ch: (parent.height - Style.controlHeightSm - Style.spaceSm * 2) / 7

                // weekday header
                Repeater {
                    model: root.weekNumbers ? 8 : 7
                    delegate: NText {
                        required property int index
                        width: grid.cw
                        height: grid.ch
                        horizontalAlignment: Text.AlignHCenter
                        text: root.weekNumbers && index === 0 ? "#" : Qt.locale().dayName((root.firstDay + index - (root.weekNumbers ? 1 : 0)) % 7, 1)
                        size: Style.fontSizeCaption
                        weight: Font.Bold
                        color: Theme.fgSurfaceVariant
                    }
                }

                Repeater {
                    model: root.weekNumbers ? 48 : 42
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property bool isWeek: root.weekNumbers && index % 8 === 0
                        readonly property var info: root.cells[root.weekNumbers ? Math.min(41, index - Math.floor(index / 8) - 1) : index]
                        width: grid.cw
                        height: grid.ch

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 4
                            height: width
                            radius: width / 2
                            visible: !cell.isWeek && cell.info.isToday
                            color: Theme.primary
                        }
                        NText {
                            anchors.centerIn: parent
                            text: cell.isWeek ? root.cells[Math.min(41, (cell.index / 8) * 7)].week : cell.info.day
                            size: cell.isWeek ? Style.fontSizeMini : Style.fontSizeBody
                            weight: !cell.isWeek && cell.info.isToday ? Font.Bold : Font.Normal
                            color: cell.isWeek ? Theme.fgSurfaceVariant : cell.info.isToday ? Theme.fgPrimary : (cell.info.inMonth ? (cell.info.weekend ? Theme.secondary : Theme.fgSurface) : Theme.alpha(Theme.fgSurfaceVariant, 0.6))
                        }
                    }
                }
            }
        }
    }
}
