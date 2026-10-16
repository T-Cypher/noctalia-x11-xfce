import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

// launcher | control-center | session | wallpaper | clipboard | screenshot | settings | custom_button
BarWidget {
    id: root

    readonly property string kind: widgetType === "control_center" ? "control-center" : widgetType
    readonly property var meta: ({
            "launcher": {
                glyph: "search",
                left: "panel-toggle launcher",
                tip: I18n.tr("launcher.providers.panel.builtin.launcher", "Launcher"),
                panel: "launcher"
            },
            "control-center": {
                glyph: "noctalia",
                left: "panel-toggle control-center home",
                tip: I18n.tr("launcher.providers.panel.builtin.control-center", "Control Center"),
                panel: "control-center"
            },
            "session": {
                glyph: "shutdown",
                left: "panel-toggle session",
                tip: I18n.tr("control-center.shortcuts.session", "Session"),
                panel: "session"
            },
            "wallpaper": {
                glyph: "wallpaper-selector",
                left: "panel-toggle wallpaper",
                tip: I18n.tr("control-center.shortcuts.wallpaper", "Wallpaper"),
                panel: "wallpaper"
            },
            "clipboard": {
                glyph: "clipboard",
                left: "panel-toggle clipboard",
                tip: I18n.tr("clipboard.title", "Clipboard"),
                panel: "clipboard"
            },
            "screenshot": {
                glyph: "screenshot",
                left: "screenshot-region",
                right: "screenshot-fullscreen",
                tip: I18n.tr("settings.widgets.types.screenshot", "Screenshot"),
                panel: ""
            },
            "settings": {
                glyph: "settings",
                left: "settings-open",
                tip: I18n.tr("settings.widgets.types.settings", "Settings"),
                panel: ""
            },
            "custom_button": {
                glyph: "heart",
                left: undefined,
                tip: "",
                panel: ""
            }
        })[kind] || {
        glyph: "help",
        tip: ""
    }

    readonly property string glyph: settings.glyph || meta.glyph
    readonly property string customImage: settings.custom_image ? Config.expandPath(settings.custom_image) : ""
    readonly property string label: settings.label || ""

    highlighted: meta.panel !== "" && meta.panel !== undefined && Panels.activePanel === meta.panel && Panels.activeScreen !== null && bar !== null && Panels.activeScreen.name === bar.screenRef.name
    tooltipText: settings.tooltip !== undefined ? String(settings.tooltip) : (meta.tip || "")

    // Port extras: custom_button `command` keys (noctalia binds them through [widget.<name>.actions]);
    // the screenshot widget's right click stands in for noctalia's capture menu.
    defaultActions: {
        var a = {};
        if (kind === "custom_button") {
            if (settings.command)
                a.left = "exec " + settings.command;
            if (settings.right_command)
                a.right = "exec " + settings.right_command;
            if (settings.middle_command)
                a.middle = "exec " + settings.middle_command;
            if (settings.scroll_up_command)
                a.scroll_up = "exec " + settings.scroll_up_command;
            if (settings.scroll_down_command)
                a.scroll_down = "exec " + settings.scroll_down_command;
        }
        return a;
    }

    Row {
        spacing: Style.spaceXs * root.contentScale

        Item {
            width: root.glyphSize
            height: root.glyphSize
            anchors.verticalCenter: parent.verticalCenter

            NIcon {
                anchors.centerIn: parent
                visible: root.customImage === ""
                icon: root.glyph
                size: root.glyphSize
                color: root.iconColor(Theme.fgSurface)
            }
            NRoundedImage {
                anchors.fill: parent
                visible: root.customImage !== ""
                source: root.customImage !== "" ? "file://" + root.customImage : ""
                radius: width / 2
                fallbackGlyph: ""
                color: "transparent"
            }
        }

        NText {
            visible: root.label !== "" && !root.vertical
            text: root.label
            size: root.fontSize
            weight: root.fontWeight
            font.family: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
