import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import "../../Commons/GestureDefaults.js" as GestureDefaults

// Base for bar widgets: sizing from the bar's capsule thickness, optional capsule background,
// hover highlight, tooltips, and noctalia's gesture -> action bindings
// (builtin < type defaults < [bar.<name>.actions] < [widget.<name>.actions]; unbound gestures
// fall through to the bar dead zone).
Item {
    id: root

    property var bar: null
    property var settings: ({})
    property string widgetName: ""
    readonly property string widgetType: String(settings && settings.type ? settings.type : widgetName)

    readonly property var barCfg: bar ? bar.cfg : ({})
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property real widgetScale: Number(settings && settings.scale !== undefined ? settings.scale : 1)
    readonly property real contentScale: (bar ? bar.contentScale : Style.uiScale) * widgetScale
    readonly property real fontScale: Number(barCfg.font_scale !== undefined ? barCfg.font_scale : 1) * Number(settings && settings.font_scale !== undefined ? settings.font_scale : 1)
    readonly property real glyphSize: 16 * contentScale
    // noctalia: Style::fontSizeBody x content scale x font scale
    readonly property real fontSize: 14 * contentScale * fontScale
    readonly property int fontWeight: Style.fontWeight(settings && settings.font_weight !== undefined ? settings.font_weight : (barCfg.font_weight !== undefined ? barCfg.font_weight : 500))
    readonly property string fontFamily: (settings && settings.font_family) ? settings.font_family : (barCfg.font_family ? barCfg.font_family : Style.fontFamily)
    readonly property real barThickness: bar ? bar.thickness : 34
    readonly property real capsuleThickness: Math.round(barThickness * Number(barCfg.capsule_thickness !== undefined ? barCfg.capsule_thickness : 0.76))
    readonly property bool capsule: settings && settings.capsule !== undefined ? settings.capsule === true : barCfg.capsule === true
    readonly property real capsuleRadius: {
        var r = settings && settings.capsule_radius !== undefined ? settings.capsule_radius : barCfg.capsule_radius;
        return r === undefined || r === "" ? Math.min(width, height) / 2 : Style.radius(Number(r));
    }
    function widgetOr(key, fallback) {
        if (settings && settings[key] !== undefined)
            return settings[key];
        return barCfg[key] !== undefined ? barCfg[key] : fallback;
    }
    property real padding: Number(widgetOr("capsule_padding", Style.barCapsulePadding)) * contentScale
    readonly property bool interactive: !(settings && settings.interactive === false)
    readonly property bool showTooltip: settings && settings.show_tooltip !== undefined ? settings.show_tooltip !== false : barCfg.show_tooltip !== false

    property string tooltipText: ""
    property var defaultActions: ({})
    property color foreground: Theme.fgSurface
    property bool hideWidget: false
    property bool highlighted: false
    property real minLength: capsuleThickness
    default property alias content: contentItem.data
    readonly property alias contentItem: contentItem
    readonly property bool hovered: hoverHandler.hovered

    implicitWidth: vertical ? capsuleThickness : Math.max(minLength, contentItem.width + padding * 2)
    implicitHeight: vertical ? Math.max(minLength, contentItem.height + padding * 2) : capsuleThickness

    // Widget color: per-widget `color`, else the bar's `icon_color` / `color`, else the capsule
    // foreground when drawn in a capsule, else the widget's own state color.
    function iconColor(fallback) {
        var c = settings && settings.color ? settings.color : (barCfg.icon_color || barCfg.color || "");
        if (c === "" && capsule)
            c = widgetOr("capsule_foreground", "");
        return c !== "" ? Theme.resolve(c, fallback) : (fallback !== undefined ? fallback : Theme.fgSurface);
    }

    function actionFor(gesture) {
        var w = settings && settings.actions ? settings.actions : {};
        if (w[gesture] !== undefined)
            return w[gesture];
        var b = barCfg.actions || {};
        if (b[gesture] !== undefined)
            return b[gesture];
        if (defaultActions[gesture] !== undefined)
            return defaultActions[gesture];
        var t = GestureDefaults.forType(widgetType, settings);
        if (t[gesture] !== undefined)
            return t[gesture];
        return GestureDefaults.builtin[gesture];
    }

    function dispatch(gesture, mouse) {
        if (GestureDefaults.isReserved(widgetType, gesture))
            return;
        var a = interactive ? actionFor(gesture) : undefined;
        if (typeof a === "function") {
            a();
            return;
        }
        if (a === undefined || a === null || String(a) === "" || String(a) === "none") {
            // Unbound gestures behave like the bar's dead zone.
            if (bar)
                bar.deadZoneGesture(gesture, root, mouse);
            return;
        }
        var origin = bar ? bar.origin(root) : null;
        if (origin) {
            origin.widgetName = widgetName;
            origin.widget = root;
        }
        Commands.run(String(a), origin);
    }

    Rectangle {
        id: capsuleBg
        anchors.fill: parent
        radius: root.capsuleRadius
        visible: root.capsule
        readonly property color fill: Theme.resolve(root.widgetOr("capsule_fill", "surface_variant"), Theme.surfaceVariant)
        color: Qt.rgba(fill.r, fill.g, fill.b, fill.a * Math.max(0, Math.min(1, Number(root.widgetOr("capsule_opacity", 1)))))
        readonly property string borderSpec: String(root.widgetOr("capsule_border", ""))
        border.width: borderSpec !== "" ? Number(root.widgetOr("capsule_border_width", 1)) * root.contentScale : 0
        border.color: borderSpec !== "" ? Theme.resolve(borderSpec) : "transparent"
    }

    Rectangle {
        id: hoverBg
        anchors.fill: parent
        radius: root.capsuleRadius
        color: root.foreground
        opacity: (root.hovered && root.interactive && root.barCfg.hover_highlight !== false) || root.highlighted ? 0.12 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }
        }
    }

    // Passive hover tracking (works even when child items have their own MouseAreas)
    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        onHoveredChanged: {
            if (!root.bar)
                return;
            if (hovered && root.showTooltip && root.tooltipText !== "")
                root.bar.showTooltip(root, root.tooltipText);
            else
                root.bar.hideTooltip(root);
        }
    }

    // Widget-level gestures sit *below* the content so per-item MouseAreas (workspace pills,
    // tray icons, taskbar buttons) receive their clicks first.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        property real wheelAccumY: 0
        property real wheelAccumX: 0
        onClicked: mouse => {
            if (root.bar)
                root.bar.dismissTooltip();
            var g = mouse.button === Qt.LeftButton ? "left" : mouse.button === Qt.RightButton ? "right" : mouse.button === Qt.MiddleButton ? "middle" : mouse.button === Qt.BackButton ? "back" : mouse.button === Qt.ForwardButton ? "forward" : "";
            if (g !== "")
                root.dispatch(g, mouse);
        }
        onWheel: wheel => {
            wheelAccumY += wheel.angleDelta.y;
            wheelAccumX += wheel.angleDelta.x;
            while (Math.abs(wheelAccumY) >= 120) {
                root.dispatch(wheelAccumY > 0 ? "scroll_up" : "scroll_down", wheel);
                wheelAccumY -= wheelAccumY > 0 ? 120 : -120;
            }
            while (Math.abs(wheelAccumX) >= 120) {
                root.dispatch(wheelAccumX > 0 ? "scroll_left" : "scroll_right", wheel);
                wheelAccumX -= wheelAccumX > 0 ? 120 : -120;
            }
        }
    }

    Item {
        id: contentItem
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: childrenRect.width
        height: childrenRect.height
    }

    onTooltipTextChanged: {
        if (bar && hoverHandler.hovered && showTooltip)
            bar.showTooltip(root, tooltipText);
    }
}
