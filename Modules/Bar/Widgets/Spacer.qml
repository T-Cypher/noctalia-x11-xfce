import QtQuick
import qs.Commons
import ".."

BarWidget {
    id: root
    readonly property real length: Number(settings.length !== undefined ? settings.length : 20) * contentScale
    minLength: length
    padding: 0
    implicitWidth: vertical ? capsuleThickness : length
    implicitHeight: vertical ? length : capsuleThickness
}
