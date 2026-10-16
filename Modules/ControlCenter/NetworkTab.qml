pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    property string promptSsid: ""

    Component.onCompleted: if (Network.wifiEnabled)
        Network.scan()

    NText {
        anchors.centerIn: parent
        visible: !Network.available
        text: "NetworkManager (nmcli) is not available."
        muted: true
    }

    Column {
        anchors.fill: parent
        spacing: Style.spaceMd
        visible: Network.available

        NCard {
            id: status
            width: parent.width
            height: statusCol.implicitHeight + Style.cardPadding * 2
            Column {
                id: statusCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                ListRow {
                    width: parent.width
                    glyph: Network.glyph()
                    title: Network.connected ? Network.primaryName : I18n.tr("control-center.network.disconnected", "Disconnected")
                    subtitle: Network.connected ? [Network.primaryType === "wifi" ? Network.signal + "%" : "Ethernet", Network.ipAddress, Network.vpnActive ? "VPN " + Network.vpnName : ""].filter(x => x).join("  ·  ") : ""
                    clickable: false
                    NButton {
                        visible: Network.connected
                        text: I18n.tr("control-center.network.disconnect", "Disconnect")
                        height: Style.controlHeightSm
                        fontSize: Style.fontSizeCaption
                        onClicked: Network.disconnect()
                    }
                }
                ListRow {
                    width: parent.width
                    glyph: Network.wifiEnabled ? "wifi" : "wifi-off"
                    title: I18n.tr("control-center.shortcuts.wifi", "Wi-Fi")
                    subtitle: Network.wifiHardware ? "" : "Hardware switch is off"
                    clickable: false
                    NIconButton {
                        visible: Network.wifiEnabled
                        icon: "refresh"
                        variant: "ghost"
                        onClicked: Network.scan()
                        RotationAnimator on rotation {
                            running: Network.scanning
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onRunningChanged: if (!running)
                                parent.rotation = 0
                        }
                    }
                    NToggle {
                        checked: Network.wifiEnabled
                        onToggled: c => Network.setWifi(c)
                    }
                }
            }
        }

        // password prompt
        NCard {
            id: prompt
            visible: root.promptSsid !== ""
            width: parent.width
            height: visible ? promptCol.implicitHeight + Style.cardPadding * 2 : 0
            Column {
                id: promptCol
                anchors.fill: parent
                anchors.margins: Style.cardPadding
                spacing: Style.spaceSm
                NText {
                    text: I18n.tr("control-center.network.password-for", "Password for") + " " + root.promptSsid
                    weight: Font.Medium
                }
                Row {
                    width: parent.width
                    spacing: Style.spaceSm
                    NTextField {
                        id: pw
                        width: parent.width - connectBtn.width - cancelBtn.width - parent.spacing * 2
                        password: !showPw.selected
                        placeholder: I18n.tr("control-center.network.password", "Password")
                        icon: "lock"
                        onAccepted: connectBtn.clicked()
                        onEscapePressed: root.promptSsid = ""
                    }
                    NIconButton {
                        id: showPw
                        property bool shown: false
                        icon: shown ? "eye-off" : "eye"
                        visible: false
                        selected: shown
                    }
                    NButton {
                        id: connectBtn
                        text: I18n.tr("control-center.network.connect", "Connect")
                        variant: "primary"
                        onClicked: {
                            Network.connect(root.promptSsid, pw.text);
                            root.promptSsid = "";
                            pw.text = "";
                        }
                    }
                    NButton {
                        id: cancelBtn
                        text: I18n.tr("common.actions.cancel", "Cancel")
                        onClicked: root.promptSsid = ""
                    }
                }
            }
            onVisibleChanged: if (visible)
                pw.focusInput()
        }

        NCard {
            width: parent.width
            height: parent.height - status.height - (prompt.visible ? prompt.height + parent.spacing : 0) - parent.spacing
            visible: Network.wifiEnabled

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Style.spaceSm
                clip: true
                spacing: 2
                model: Network.accessPoints
                boundsBehavior: Flickable.StopAtBounds
                delegate: ListRow {
                    required property var modelData
                    width: list.width - Style.spaceMd
                    glyph: modelData.signal >= 67 ? "wifi" : modelData.signal >= 34 ? "wifi-2" : "wifi-1"
                    title: modelData.ssid
                    subtitle: [modelData.active ? I18n.tr("bar.widgets.network.connected", "Connected") : (modelData.known ? I18n.tr("control-center.network.saved", "Saved") : ""), modelData.security, modelData.signal + "%"].filter(x => x).join("  ·  ")
                    active: modelData.active
                    implicitHeight: Style.controlHeightLg
                    onClicked: {
                        if (modelData.active)
                            return;
                        if (modelData.security !== "" && !modelData.known)
                            root.promptSsid = modelData.ssid;
                        else
                            Network.connect(modelData.ssid, "");
                    }
                    NIcon {
                        visible: Network.connectingSsid === parent.modelData.ssid
                        icon: "busy"
                        color: Theme.primary
                    }
                    NIcon {
                        visible: parent.modelData.security !== ""
                        icon: "lock"
                        size: Style.fontSizeCaption
                        color: Theme.fgSurfaceVariant
                    }
                    NIconButton {
                        visible: parent.modelData.known && !parent.modelData.active
                        icon: "trash"
                        variant: "ghost"
                        size: Style.controlHeightSm * 0.85
                        onClicked: Network.forget(parent.modelData.ssid)
                    }
                }
                NText {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: Network.scanning ? I18n.tr("control-center.network.scanning", "Scanning…") : I18n.tr("control-center.network.no-networks", "No networks found")
                    muted: true
                }
            }
            NScrollBar {
                flickable: list
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Style.spaceXs
            }
        }
    }
}
