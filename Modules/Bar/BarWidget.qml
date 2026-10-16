import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

// Base for bar widgets: sizing from the bar's capsule thickness, optional capsule background,
// hover highlight, tooltips, and noctalia's gesture -> action bindings
// (widget defaults < [bar.<name>.actions] < [widget.<name>.actions]).
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
    readonly property real fontSize: 13 * contentScale * fontScale
    readonly property int fontWeight: Style.fontWeight(settings && settings.font_weight !== undefined ? settings.font_weight : (barCfg.font_weight !== undefined ? barCfg.font_weight : 500))
    readonly property string fontFamily: (settings && settings.font_family) ? settings.font_family : (barCfg.font_family ? barCfg.font_family : Style.fontFamily)
    readonly property real barThickness: bar ? bar.thickness : 34
    readonly property real capsuleThickness: Math.round(barThickness * Number(barCfg.capsule_thickness !== undefined ? barCfg.capsule_thickness : 0.76))
    readonly property bool capsule: settings && settings.capsule !== undefined ? settings.capsule === true : barCfg.capsule === true
    readonly property real capsuleRadius: {
        var r = settings && settings.capsule_radius !== undefined ? settings.capsule_radius : barCfg.capsule_radius;
        return r === undefined || r === "" ? Math.min(width, height) / 2 : Style.radius(Number(r));
    }
    property real padding: Style.barCapsulePadding * contentScale
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

    function iconColor(fallback) {
        var c = settings && settings.color ? settings.color : "";
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
        if (gesture === "right")
            return "panel-toggle control-center home";
        if (gesture === "middle")
            return "settings-open";
        return undefined;
    }

    function dispatch(gesture) {
        var a = actionFor(gesture);
        if (a === undefined || a === null || a === "none")
            return;
        if (typeof a === "function") {
            a();
            return;
        }
        Commands.run(String(a), bar ? bar.origin(root) : null);
    }

    Rectangle {
        id: capsuleBg
        anchors.fill: parent
        radius: root.capsuleRadius
        visible: root.capsule
        color: Theme.alpha(Theme.resolve(root.settings && root.settings.capsule_fill ? root.settings.capsule_fill : (root.barCfg.capsule_fill || "surface_variant")), Number(root.barCfg.capsule_opacity !== undefined ? root.barCfg.capsule_opacity : 1))
        border.width: root.barCfg.capsule_border ? Number(root.barCfg.capsule_border_width || 1) : 0
        border.color: root.barCfg.capsule_border ? Theme.resolve(root.barCfg.capsule_border) : "transparent"
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
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        cursorShape: Qt.PointingHandCursor
        property real wheelAccum: 0
        onClicked: mouse => {
            if (root.bar)
                root.bar.dismissTooltip();
            if (mouse.button === Qt.LeftButton)
                root.dispatch("left");
            else if (mouse.button === Qt.RightButton)
                root.dispatch("right");
            else if (mouse.button === Qt.MiddleButton)
                root.dispatch("middle");
            else if (mouse.button === Qt.BackButton)
                root.dispatch("back");
            else if (mouse.button === Qt.ForwardButton)
                root.dispatch("forward");
        }
        onWheel: wheel => {
            var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            wheelAccum += dy;
            while (Math.abs(wheelAccum) >= 120) {
                root.dispatch(wheelAccum > 0 ? "scroll_up" : "scroll_down");
                wheelAccum -= wheelAccum > 0 ? 120 : -120;
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
