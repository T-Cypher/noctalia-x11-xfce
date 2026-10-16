pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// Notification toast stack on one screen ([notification] position / offsets / monitors).
PanelWindow {
    id: win

    required property var screenRef
    screen: screenRef

    readonly property string position: String(Config.get("notification.position", "top_right"))
    readonly property real cardWidth: Number(Config.get("notification.width", 360)) * Number(Config.get("notification.scale", 1)) * Style.uiScale
    readonly property bool top: position.indexOf("bottom") < 0
    readonly property bool left: position.indexOf("left") >= 0
    readonly property bool center: position.indexOf("center") >= 0

    anchors.top: top
    anchors.bottom: !top
    anchors.left: left
    anchors.right: !left && !center
    margins.top: top ? Number(Config.get("notification.offset_y", 8)) : 0
    margins.bottom: !top ? Number(Config.get("notification.offset_y", 8)) : 0
    margins.left: left ? Number(Config.get("notification.offset_x", 20)) : 0
    margins.right: !left && !center ? Number(Config.get("notification.offset_x", 20)) : 0

    // max_visible = 0: as many toasts as fit; the rest wait (expiry paused) below the fold.
    readonly property real maxHeight: Math.max(100, screenRef.height - 2 * Number(Config.get("notification.offset_y", 8)))
    implicitWidth: cardWidth
    implicitHeight: Math.max(1, Math.min(column.implicitHeight, maxHeight))
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    aboveWindows: true
    focusable: false
    color: "transparent"
    readonly property bool onThisScreen: Config.get("notification.follow_focused_output", false) === true ? Notifications.targetScreen === screenRef.name : Config.screenAllowed(Config.get("notification.monitors", []), screenRef)
    visible: Notifications.toasts.count > 0 && onThisScreen

    Column {
        id: column
        width: parent.width
        spacing: Style.spaceSm

        Repeater {
            model: Notifications.toasts
            delegate: Item {
                id: slot
                required property int index
                required property int nid
                required property string summary
                required property string body
                required property string appName
                required property string appIcon
                required property string image
                required property string urgency
                required property real time
                required property real timeout
                required property string actionsJson
                required property string glyph
                required property bool internal

                width: column.width
                height: card.implicitHeight
                readonly property bool fits: y + height <= win.maxHeight + 0.5
                opacity: 0
                property real slide: win.left ? -40 : 40

                Component.onCompleted: appear.start()
                ParallelAnimation {
                    id: appear
                    NumberAnimation {
                        target: slot
                        property: "opacity"
                        to: 1
                        duration: Style.animNormal
                    }
                    NumberAnimation {
                        target: slot
                        property: "slide"
                        to: 0
                        duration: Style.animNormal * 1.5
                        easing.type: Easing.OutCubic
                    }
                }

                NotificationCard {
                    id: card
                    x: slot.slide
                    width: parent.width
                    height: implicitHeight
                    nid: slot.nid
                    summary: slot.summary
                    body: slot.body
                    appName: slot.appName
                    appIcon: slot.appIcon
                    image: slot.image
                    urgency: slot.urgency
                    time: slot.time
                    timeout: slot.timeout
                    actionsJson: slot.actionsJson
                    glyph: slot.glyph
                    internal: slot.internal
                    paused: !slot.fits
                    visible: slot.fits
                    onExpired: Notifications.expire(slot.nid)
                }
            }
        }
    }
}
