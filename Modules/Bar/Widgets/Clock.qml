import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."
import "../../../Commons/Util.js" as Util

// noctalia's clock widget: `format` (default "{:%H:%M}", independent of [shell] time_format),
// `vertical_format`, optional `tooltip_format`. A two-line horizontal format stacks its lines;
// vertical bars without vertical_format put every space/colon separated token on its own line.
BarWidget {
    id: root

    property date now: new Date()
    readonly property string format: settings.format || "{:%H:%M}"
    readonly property string text_: {
        var t = Util.formatTime(format, now, Qt.locale());
        if (!vertical)
            return t;
        if (settings.vertical_format)
            return Util.formatTime(settings.vertical_format, now, Qt.locale());
        return t.split(/[ \t:]+/).filter(x => x.length > 0).join("\n");
    }
    readonly property string primaryText: vertical ? text_ : text_.split("\n")[0]
    readonly property string secondaryText: {
        if (vertical)
            return "";
        var i = text_.indexOf("\n");
        return i < 0 ? "" : text_.slice(i + 1);
    }
    readonly property bool stacked: secondaryText !== ""

    tooltipText: settings.tooltip_format ? Util.formatTime(settings.tooltip_format, now, Qt.locale()) : ""

    Column {
        spacing: 0
        NText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.primaryText
            size: root.fontSize * (root.stacked ? (root.capsule ? 0.72 : 0.80) : 1)
            weight: root.fontWeight
            font.family: root.fontFamily
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.95
            color: root.iconColor(Theme.fgSurface)
        }
        NText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.stacked
            text: root.secondaryText
            size: root.fontSize * (root.capsule ? 0.62 : 0.72)
            weight: root.fontWeight
            font.family: root.fontFamily
            horizontalAlignment: Text.AlignHCenter
            color: root.iconColor(Theme.fgSurface)
        }
    }

    Timer {
        interval: Util.formatHasSeconds(root.format + (root.settings.vertical_format || "") + (root.settings.tooltip_format || "")) ? 1000 : Math.max(1000, (60 - root.now.getSeconds()) * 1000)
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.now = new Date()
    }
}
