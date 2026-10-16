import QtQuick
import qs.Commons

Rectangle {
    property bool vertical: false
    implicitWidth: vertical ? Style.borderWidth : 1
    implicitHeight: vertical ? 1 : Style.borderWidth
    color: Theme.alpha(Theme.outline, 0.8)
}
