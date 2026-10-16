import QtQuick
import qs.Commons

// noctalia card: surface_variant fill, outline border, radiusXl.
Rectangle {
    id: root
    property real padding: Style.cardPadding
    property real fillOpacity: 1.0
    color: Theme.alpha(Theme.surfaceVariant, fillOpacity)
    border.color: Theme.outline
    border.width: Style.borderWidth
    radius: Style.radiusXl
}
