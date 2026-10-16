pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

// noctalia Control Center: sidebar tab rail + header + tab body.
Item {
    id: root

    required property var screenRef

    readonly property var allTabs: [
        { id: "home", glyph: "home", label: I18n.tr("control-center.tabs.home", "Home") },
        { id: "media", glyph: "disc", label: I18n.tr("control-center.tabs.media", "Media") },
        { id: "audio", glyph: "volume", label: I18n.tr("control-center.tabs.audio", "Audio") },
        { id: "monitor", glyph: "device-desktop", label: I18n.tr("control-center.tabs.monitor", "Monitor") },
        { id: "system", glyph: "activity", label: I18n.tr("control-center.tabs.system", "System") },
        { id: "network", glyph: "wifi", label: I18n.tr("control-center.tabs.network", "Network") },
        { id: "bluetooth", glyph: "bluetooth", label: I18n.tr("control-center.tabs.bluetooth", "Bluetooth") },
        { id: "weather", glyph: "weather-cloud-sun", label: I18n.tr("control-center.tabs.weather", "Weather") },
        { id: "calendar", glyph: "calendar", label: I18n.tr("control-center.tabs.calendar", "Calendar") },
        { id: "notifications", glyph: "bell", label: I18n.tr("control-center.tabs.notifications", "Notifications") },
        { id: "power", glyph: "battery-charging-2", label: I18n.tr("control-center.tabs.power", "Power") }
    ]
    readonly property var hidden: Config.get("control_center.hidden_tabs", [])
    readonly property var tabs: allTabs.filter(t => {
        if (t.id !== "home" && Array.isArray(hidden) && hidden.indexOf(t.id) >= 0)
            return false;
        if (t.id === "weather" && !Weather.enabled)
            return false;
        if (t.id === "system" && Config.get("system.monitor.enabled", true) === false)
            return false;
        if (t.id === "power" && !Power.hasBattery && !Power.profilesAvailable)
            return false;
        return true;
    })

    readonly property string requested: Panels.context
    property string current: tabs.some(t => t.id === requested) ? requested : "home"
    readonly property bool openedOnTab: requested !== "" && requested !== "home"
    readonly property string sidebarMode: String(Config.get(openedOnTab ? "control_center.sidebar_section" : "control_center.sidebar", "compact"))
    readonly property real baseWidth: Math.max(600, Math.min(1200, Number(Config.get("control_center.width", 700))))

    implicitWidth: Math.round(baseWidth * (sidebarMode === "full" ? 1 : sidebarMode === "none" ? 0.75 : 0.85) * Style.uiScale)
    implicitHeight: Math.round(520 * Style.uiScale)

    Connections {
        target: Panels
        function onContextChanged() {
            if (root.tabs.some(t => t.id === Panels.context))
                root.current = Panels.context;
        }
    }

    function focusFirst() {
        keys.forceActiveFocus();
    }

    function currentLabel() {
        for (var i = 0; i < tabs.length; i++)
            if (tabs[i].id === current)
                return tabs[i].label;
        return "";
    }

    function step(delta) {
        var idx = tabs.findIndex(t => t.id === current);
        current = tabs[(idx + delta + tabs.length) % tabs.length].id;
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Panels.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab || (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier))) {
                root.step(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier))) {
                root.step(-1);
                event.accepted = true;
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spaceMd

        // ---------------------------------------------------------------- sidebar
        Rectangle {
            id: rail
            visible: root.sidebarMode !== "none"
            width: root.sidebarMode === "full" ? railColumn.implicitWidth + Style.spaceSm * 2 : Style.controlHeightSm + Style.spaceSm * 2
            height: parent.height
            radius: Style.radiusXl
            color: Theme.surfaceVariant
            border.color: Theme.outline
            border.width: Style.borderWidth

            Column {
                id: railColumn
                anchors.top: parent.top
                anchors.topMargin: Style.spaceSm
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spaceXs

                Repeater {
                    model: root.tabs
                    delegate: NButton {
                        required property var modelData
                        width: root.sidebarMode === "full" ? Math.max(implicitWidth, 150 * Style.uiScale) : Style.controlHeightSm
                        height: Style.controlHeightSm
                        paddingH: root.sidebarMode === "full" ? Style.spaceSm : 0
                        variant: root.current === modelData.id ? "tabActive" : "tab"
                        icon: modelData.glyph
                        text: root.sidebarMode === "full" ? modelData.label : ""
                        radius: Style.radiusLg
                        onClicked: root.current = modelData.id
                    }
                }
            }
        }

        // ---------------------------------------------------------------- content
        Column {
            id: content
            width: parent.width - (rail.visible ? rail.width + parent.spacing : 0)
            height: parent.height
            spacing: Style.spaceMd

            Item {
                id: header
                width: parent.width
                height: Style.controlHeightSm

                NText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentLabel()
                    size: Style.fontSizeTitle
                    weight: Font.Bold
                    color: Theme.primary
                    width: parent.width - actions.width - Style.spaceMd
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spaceSm

                    NIconButton {
                        icon: "settings"
                        size: Style.controlHeightSm
                        onClicked: {
                            Panels.close();
                            Commands.openSettings();
                        }
                    }
                    NIconButton {
                        visible: Config.get("control_center.show_session_button", true) !== false
                        icon: "power"
                        size: Style.controlHeightSm
                        onClicked: Panels.open("session", root.screenRef, "", Panels.anchor, Panels.sourceBar, null)
                    }
                    NIconButton {
                        icon: "close"
                        size: Style.controlHeightSm
                        onClicked: Panels.close()
                    }
                }
            }

            Loader {
                id: body
                width: parent.width
                height: parent.height - header.height - parent.spacing
                sourceComponent: {
                    switch (root.current) {
                    case "media": return mediaTab;
                    case "audio": return audioTab;
                    case "monitor": return monitorTab;
                    case "system": return systemTab;
                    case "network": return networkTab;
                    case "bluetooth": return bluetoothTab;
                    case "weather": return weatherTab;
                    case "calendar": return calendarTab;
                    case "notifications": return notificationsTab;
                    case "power": return powerTab;
                    }
                    return homeTab;
                }
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.animFast
                    }
                }
            }
        }
    }

    Component {
        id: homeTab
        HomeTab {
            screenRef: root.screenRef
            onOpenTab: id => root.current = id
        }
    }
    Component {
        id: mediaTab
        MediaTab {}
    }
    Component {
        id: audioTab
        AudioTab {}
    }
    Component {
        id: monitorTab
        MonitorTab {}
    }
    Component {
        id: systemTab
        SystemTab {}
    }
    Component {
        id: networkTab
        NetworkTab {}
    }
    Component {
        id: bluetoothTab
        BluetoothTab {}
    }
    Component {
        id: weatherTab
        WeatherTab {}
    }
    Component {
        id: calendarTab
        CalendarTab {}
    }
    Component {
        id: notificationsTab
        NotificationsTab {}
    }
    Component {
        id: powerTab
        PowerTab {}
    }
}
