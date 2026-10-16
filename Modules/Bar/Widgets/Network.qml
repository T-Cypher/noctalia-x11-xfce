import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property string vpnStatus: settings.vpn_status || "replace"
    readonly property bool vpnShown: Network.vpnActive && vpnStatus !== "hidden"
    readonly property bool showLabel: settings.show_label !== undefined ? settings.show_label === true : true
    readonly property string label: {
        if (vpnShown && vpnStatus === "replace" && settings.show_vpn_label === true)
            return Network.vpnName;
        if (Network.primaryType === "wifi")
            return Network.primaryName;
        if (Network.primaryType === "ethernet")
            return I18n.tr("bar.widgets.network.wired", "Wired");
        return "";
    }

    tooltipText: Network.connected ? (Network.primaryName + (Network.ipAddress ? "\n" + Network.ipAddress : "") + (Network.vpnActive ? "\nVPN: " + Network.vpnName : "")) : I18n.tr("control-center.network.not-connected", "Not connected")

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            icon: root.vpnShown && root.vpnStatus === "replace" ? "shield-lock" : Network.glyph()
            size: root.glyphSize
            color: root.iconColor(Network.connected ? Theme.fgSurface : Theme.fgSurfaceVariant)
            anchors.verticalCenter: parent.verticalCenter
        }
        NIcon {
            visible: root.vpnShown && root.vpnStatus === "both"
            icon: "shield-lock"
            size: root.glyphSize * 0.85
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.showLabel && !root.vertical && root.label !== ""
            width: Math.min(implicitWidth, 120 * root.contentScale)
            text: root.label
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
