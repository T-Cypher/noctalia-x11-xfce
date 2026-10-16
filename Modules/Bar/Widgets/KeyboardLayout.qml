import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property var custom: settings.custom_labels || {}
    readonly property string label: {
        var full = X11.layoutName;
        if (custom[full] !== undefined)
            return String(custom[full]);
        if (settings.display === "full")
            return full;
        return X11.layoutCode.toUpperCase();
    }

    hideWidget: settings.hide_when_single_layout === true && (X11.keyboard.layouts || []).length <= 1
    tooltipText: X11.layoutName
    defaultActions: {
        var a = {
            scroll_up: "keyboard-layout-previous",
            scroll_down: "keyboard-layout-next"
        };
        a.left = settings.cycle_command ? "exec " + settings.cycle_command : "keyboard-layout-next";
        return a;
    }

    Row {
        spacing: Style.spaceXs * root.contentScale
        NIcon {
            visible: root.settings.show_glyph !== false && root.settings.show_icon !== false
            icon: root.settings.glyph || "keyboard"
            size: root.glyphSize
            color: root.iconColor(Theme.fgSurface)
            anchors.verticalCenter: parent.verticalCenter
        }
        NText {
            visible: root.settings.show_label !== false
            text: root.label
            size: root.fontSize
            weight: Font.Bold
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
