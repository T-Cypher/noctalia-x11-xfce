import QtQuick
import qs.Commons

// One bar section (start / center / end): widgets in a row (horizontal) or column (vertical).
Grid {
    id: root

    required property var bar
    property var names: []

    rows: bar.vertical ? -1 : 1
    columns: bar.vertical ? 1 : -1
    flow: bar.vertical ? Grid.TopToBottom : Grid.LeftToRight
    spacing: Number(bar.cfg.widget_spacing !== undefined ? bar.cfg.widget_spacing : 6) * bar.contentScale
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    Repeater {
        model: Array.isArray(root.names) ? root.names : []
        delegate: BarWidgetLoader {
            required property var modelData
            widgetName: String(modelData)
            bar: root.bar
        }
    }
}
