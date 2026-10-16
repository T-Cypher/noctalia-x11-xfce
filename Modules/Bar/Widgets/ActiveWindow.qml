import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property var win: {
        var w = X11.activeWindow;
        if (w && bar && Quickshell.screens.length > 1 && !X11.onScreen(w, bar.screenRef))
            return null;
        return w;
    }
    readonly property string display: settings.display || "icon_and_text"
    readonly property real maxWidth: Number(settings.max_length !== undefined ? settings.max_length : 260) * contentScale
    readonly property real minWidth: Number(settings.min_length !== undefined ? settings.min_length : 80) * contentScale
    readonly property string title: win ? (win.title || win.appId) : ""

    hideWidget: !win && settings.show_empty_label !== true
    tooltipText: win ? win.title : ""
    minLength: vertical ? capsuleThickness : minWidth

    Row {
        spacing: Style.spaceSm * root.contentScale

        NAppIcon {
            visible: root.display !== "text_only" && root.win !== null
            size: Number(root.settings.icon_size !== undefined ? root.settings.icon_size : 16) * root.contentScale
            anchors.verticalCenter: parent.verticalCenter
            source: root.win ? Apps.iconForClass(root.win.appId, root.win.instance) : ""
        }

        NText {
            visible: root.display !== "icon_only" && !root.vertical
            width: Math.min(implicitWidth, root.maxWidth)
            text: root.win ? root.title : I18n.tr("bar.widgets.active-window.no-active-window", "No active window")
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            muted: root.win === null
        }
    }
}
