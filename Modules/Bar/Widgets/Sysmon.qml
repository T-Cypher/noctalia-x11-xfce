import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."
import "../../../Commons/Util.js" as Util

// One system statistic with a gauge or graph (noctalia sysmon widget).
BarWidget {
    id: root

    readonly property string stat: settings.stat || "cpu_usage"
    readonly property string visualization: settings.visualization || "gauge"
    readonly property bool compactSpeed: settings.network_speed_compact === true
    readonly property var info: {
        switch (stat) {
        case "cpu_temp":
            return {
                glyph: "cpu-temperature",
                norm: Util.clamp((SystemMonitor.cpuTemp - 30) / 50, 0, 1),
                text: Math.round(SystemMonitor.cpuTemp) + "°C",
                hist: []
            };
        case "ram_used":
            return {
                glyph: "memory",
                norm: SystemMonitor.memPercent / 100,
                text: Util.formatBytes(SystemMonitor.memUsed, 1),
                hist: SystemMonitor.memHistory
            };
        case "ram_pct":
            return {
                glyph: "memory",
                norm: SystemMonitor.memPercent / 100,
                text: Math.round(SystemMonitor.memPercent) + "%",
                hist: SystemMonitor.memHistory
            };
        case "swap_pct":
            var sp = SystemMonitor.swapTotal > 0 ? SystemMonitor.swapUsed / SystemMonitor.swapTotal : 0;
            return {
                glyph: "memory",
                norm: sp,
                text: Math.round(sp * 100) + "%",
                hist: []
            };
        case "disk_used_pct":
            return {
                glyph: "storage",
                norm: SystemMonitor.diskPercent / 100,
                text: Math.round(SystemMonitor.diskPercent) + "%",
                hist: []
            };
        case "disk_used":
            return {
                glyph: "storage",
                norm: SystemMonitor.diskPercent / 100,
                text: Util.formatBytes(SystemMonitor.diskUsed, 0),
                hist: []
            };
        case "disk_free_pct":
            return {
                glyph: "storage",
                norm: 1 - SystemMonitor.diskPercent / 100,
                text: Math.round(100 - SystemMonitor.diskPercent) + "%",
                hist: []
            };
        case "disk_free":
            return {
                glyph: "storage",
                norm: 1 - SystemMonitor.diskPercent / 100,
                text: Util.formatBytes(SystemMonitor.diskTotal - SystemMonitor.diskUsed, 0),
                hist: []
            };
        case "net_rx":
            return {
                glyph: "download-speed",
                norm: Util.clamp(SystemMonitor.netRx / 12500000, 0, 1),
                text: Util.formatSpeed(SystemMonitor.netRx, root.compactSpeed),
                hist: SystemMonitor.rxHistory
            };
        case "net_tx":
            return {
                glyph: "upload-speed",
                norm: Util.clamp(SystemMonitor.netTx / 12500000, 0, 1),
                text: Util.formatSpeed(SystemMonitor.netTx, root.compactSpeed),
                hist: SystemMonitor.txHistory
            };
        default:
            return {
                glyph: "cpu-usage",
                norm: SystemMonitor.cpuUsage / 100,
                text: Math.round(SystemMonitor.cpuUsage) + "%",
                hist: SystemMonitor.cpuHistory
            };
        }
    }

    tooltipText: stat.replace(/_/g, " ") + ": " + info.text

    Component.onCompleted: SystemMonitor.consumers++
    Component.onDestruction: SystemMonitor.consumers--

    Row {
        spacing: Style.spaceXs * root.contentScale

        NIcon {
            visible: root.settings.show_glyph !== false
            icon: root.settings.glyph || root.info.glyph
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }

        // vertical gauge
        Rectangle {
            visible: root.visualization === "gauge"
            width: Math.max(3, Math.round(root.glyphSize * 0.3))
            height: Math.round(root.glyphSize * 0.95)
            radius: width / 2
            color: Theme.alpha(Theme.fgSurface, 0.2)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * Util.clamp(root.info.norm, 0, 1))
                radius: width / 2
                color: root.info.norm > 0.85 ? Theme.error : Theme.primary
                Behavior on height {
                    NumberAnimation {
                        duration: Style.animNormal
                    }
                }
            }
        }

        NGraph {
            visible: root.visualization === "graph"
            width: root.glyphSize * 2.2
            height: root.glyphSize
            values: root.info.hist
            maxValue: root.stat.indexOf("net") === 0 ? 1 : 100
            autoScale: root.stat.indexOf("net") === 0
            capacity: 30
            anchors.verticalCenter: parent.verticalCenter
        }

        NText {
            visible: root.settings.show_value !== false && !root.vertical
            text: root.info.text
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, Number(root.settings.label_min_width || 0))
        }
    }
}
