import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

BarWidget {
    id: root

    readonly property bool full: settings.display === "full"
    readonly property var keys: {
        var k = [];
        if (settings.show_caps_lock !== false)
            k.push({
                on: X11.keyboard.caps,
                label: full ? "Caps" : "A"
            });
        if (settings.show_num_lock !== false)
            k.push({
                on: X11.keyboard.num,
                label: full ? "Num" : "1"
            });
        if (settings.show_scroll_lock === true)
            k.push({
                on: X11.keyboard.scroll,
                label: full ? "Scroll" : "S"
            });
        return k;
    }
    readonly property bool anyOn: keys.some(k => k.on)

    hideWidget: settings.hide_when_off === true && !anyOn
    tooltipText: "Caps Lock: " + (X11.keyboard.caps ? "on" : "off") + "\nNum Lock: " + (X11.keyboard.num ? "on" : "off")

    Row {
        spacing: Style.spaceXs * root.contentScale
        Repeater {
            model: root.keys
            delegate: Rectangle {
                required property var modelData
                visible: !(root.settings.hide_when_off === true && !modelData.on)
                height: root.glyphSize
                width: Math.max(height, t.implicitWidth + 8)
                radius: 4
                color: modelData.on ? Theme.primary : "transparent"
                border.color: modelData.on ? Theme.primary : Theme.outline
                border.width: 1
                NText {
                    id: t
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    size: 11 * root.contentScale
                    weight: Font.Bold
                    color: parent.modelData.on ? Theme.fgPrimary : Theme.fgSurfaceVariant
                }
            }
        }
    }
}
