import QtQuick
import qs.Commons

// Square icon-only button (ghost by default), used in headers and cards.
NButton {
    id: root
    property real size: Style.controlHeightSm
    variant: "default"
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    paddingH: 0
    iconSize: Math.round(size * 0.5)
    radius: Style.radiusMd
}
