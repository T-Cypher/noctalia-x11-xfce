import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."
import "../../../Commons/Util.js" as Util

BarWidget {
    id: root

    property date now: new Date()
    readonly property string format: vertical ? (settings.vertical_format || "{:%H\n%M}") : (settings.format || Config.get("shell.time_format", "{:%H:%M}"))
    readonly property string tooltipFormat: settings.tooltip_format || "{:%A, %B %d, %Y}"

    tooltipText: Util.formatTime(tooltipFormat, now, Qt.locale())
    defaultActions: ({
            left: "panel-toggle control-center calendar"
        })

    NText {
        text: Util.formatTime(root.format, root.now, Qt.locale())
        size: root.fontSize
        weight: root.fontWeight
        font.family: root.fontFamily
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.95
        color: root.iconColor(Theme.fgSurface)
    }

    Timer {
        interval: Util.formatHasSeconds(root.format) ? 1000 : Math.max(1000, (60 - root.now.getSeconds()) * 1000)
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.now = new Date()
    }
}
