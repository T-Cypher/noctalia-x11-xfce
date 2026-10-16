import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/Util.js" as Util

Item {
    id: root

    property string distro: ""
    property string kernel: ""
    property string cpuModel: ""
    property string wm: ""

    Component.onCompleted: SystemMonitor.consumers++
    Component.onDestruction: SystemMonitor.consumers--

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\"; uname -sr; grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; wmctrl -m 2>/dev/null | head -n1 | cut -d: -f2 || echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                root.distro = (l[0] || "").trim();
                root.kernel = (l[1] || "").trim();
                root.cpuModel = (l[2] || "").trim();
                root.wm = (l[3] || "").trim();
            }
        }
    }

    component StatCard: NCard {
        id: sc
        property string glyph: ""
        property string title: ""
        property string value: ""
        property var history: []
        property real maxValue: 100
        property bool autoScale: false
        property color lineColor: Theme.primary
        Column {
            anchors.fill: parent
            anchors.margins: Style.cardPadding
            spacing: Style.spaceXs
            Row {
                width: parent.width
                spacing: Style.spaceSm
                NIcon {
                    icon: sc.glyph
                    color: sc.lineColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                NText {
                    text: sc.title
                    size: Style.fontSizeCaption
                    muted: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            NText {
                text: sc.value
                size: Style.fontSizeTitle
                weight: Font.Bold
            }
            NGraph {
                width: parent.width
                height: parent.height - y
                values: sc.history
                maxValue: sc.maxValue
                autoScale: sc.autoScale
                lineColor: sc.lineColor
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd

        NCard {
            id: info
            width: parent.width
            height: infoCol.implicitHeight + Style.cardPadding * 2
            Column {
                id: infoCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: 2
                NText {
                    text: root.distro || "Linux"
                    weight: Font.Bold
                }
                NText {
                    text: [root.kernel, root.wm ? "WM: " + root.wm : "X11"].filter(x => x).join("  ·  ")
                    size: Style.fontSizeCaption
                    muted: true
                }
                NText {
                    text: root.cpuModel
                    size: Style.fontSizeCaption
                    muted: true
                    width: parent.width
                }
                NText {
                    text: I18n.tr("control-center.home.uptime", "Uptime – {uptime}", {
                        uptime: Util.formatDuration(SystemMonitor.uptimeSeconds)
                    }) + "  ·  load " + SystemMonitor.loadAvg + (SystemMonitor.cpuTemp > 0 ? "  ·  " + Math.round(SystemMonitor.cpuTemp) + "°C" : "")
                    size: Style.fontSizeCaption
                    muted: true
                }
            }
        }

        Grid {
            width: parent.width
            height: parent.height - info.height - parent.spacing
            columns: 2
            spacing: Style.spaceMd
            readonly property real cw: (width - spacing) / 2
            readonly property real ch: (height - spacing) / 2

            StatCard {
                width: parent.cw
                height: parent.ch
                glyph: "cpu-usage"
                title: "CPU"
                value: Math.round(SystemMonitor.cpuUsage) + "%"
                history: SystemMonitor.cpuHistory
            }
            StatCard {
                width: parent.cw
                height: parent.ch
                glyph: "memory"
                title: "RAM"
                value: Util.formatBytes(SystemMonitor.memUsed, 1) + " / " + Util.formatBytes(SystemMonitor.memTotal, 0)
                history: SystemMonitor.memHistory
                lineColor: Theme.secondary
            }
            StatCard {
                width: parent.cw
                height: parent.ch
                glyph: "download-speed"
                title: I18n.tr("control-center.system.titles.network", "Network")
                value: "↓ " + Util.formatSpeed(SystemMonitor.netRx) + "   ↑ " + Util.formatSpeed(SystemMonitor.netTx)
                history: SystemMonitor.rxHistory
                autoScale: true
                lineColor: Theme.tertiary
            }
            StatCard {
                width: parent.cw
                height: parent.ch
                glyph: "storage"
                title: I18n.tr("bar.widgets.sysmon.disk", "Disk") + " /"
                value: Math.round(SystemMonitor.diskPercent) + "%  ·  " + Util.formatBytes(SystemMonitor.diskTotal - SystemMonitor.diskUsed, 0) + " free"
                history: []
                lineColor: Theme.error
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Style.cardPadding
                    height: Style.sliderTrackHeight
                    radius: height / 2
                    color: Theme.alpha(Theme.fgSurface, 0.12)
                    Rectangle {
                        height: parent.height
                        radius: height / 2
                        width: parent.width * SystemMonitor.diskPercent / 100
                        color: SystemMonitor.diskPercent > 90 ? Theme.error : Theme.primary
                    }
                }
            }
        }
    }
}
