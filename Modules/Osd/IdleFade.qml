import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// [idle] pre_action_fade_seconds: a fullscreen surface-colored overlay that fades in before an
// idle action runs. It is click-through, so any input (which resets the X11 idle timer)
// cancels the fade.
PanelWindow {
    id: win

    required property var screenRef
    screen: screenRef

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"
    mask: Region {}
    visible: Idle.fading !== null

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        opacity: Idle.fadeProgress
    }
}
