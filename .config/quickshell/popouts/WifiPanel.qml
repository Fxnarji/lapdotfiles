import QtQuick
import Quickshell
import qs
import qs.services

// Wi-Fi popout (design 6a): the connected network as a card with IP and live
// speed, known networks as a plain list, and new ones below a "New" divider.
PopoutPanel {
    id: root

    width: 360

    // Network whose password field is open, by name.
    property string expanded: ""
    onOpenChanged: if (!open) expanded = ""

    // Scan and poll details only while open.
    Binding { target: Wifi; property: "watch"; value: root.open }

    readonly property var current: Wifi.current
    readonly property var known: Wifi.networks.filter(n => n.known && !n.connected)
        .sort((a, b) => b.signalStrength - a.signalStrength)
    readonly property var fresh: Wifi.networks.filter(n => !n.known && !n.connected)
        .sort((a, b) => b.signalStrength - a.signalStrength)
        .slice(0, 8)

    PanelHeader {
        title: "Wi-Fi"
        Toggle {
            checked: Wifi.enabled
            onToggled: Wifi.setEnabled(!Wifi.enabled)
        }
    }

    // Connected network
    Rectangle {
        visible: Wifi.enabled && root.current !== null
        width: parent.width
        height: card.implicitHeight + 24
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)

        HoverHandler { id: cardHover }

        Column {
            id: card
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Item {
                width: parent.width
                height: 24
                SignalBars {
                    id: bars
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    height: 12
                    level: Wifi.signalLevel(root.current?.signalStrength ?? 0)
                    litColor: Theme.accent
                }
                Text {
                    anchors { left: bars.right; leftMargin: 12; right: end.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: root.current?.name ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                // Check mark; Disconnect while hovered.
                Item {
                    id: end
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: cardHover.hovered ? disconnect.width : check.width
                    height: 24
                    Text {
                        id: check
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: !cardHover.hovered
                        text: ""
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.accent
                    }
                    PanelButton {
                        id: disconnect
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        visible: cardHover.hovered
                        implicitHeight: 24
                        text: "Disconnect"
                        onClicked: root.current?.disconnect()
                    }
                }
            }

            Row {
                spacing: 16
                Detail { text: Wifi.ip || "…" }
                Detail { glyph: ""; text: Wifi.speed(Wifi.down) }
                Detail { glyph: ""; text: Wifi.speed(Wifi.up) }
            }
        }
    }

    NetworkList { networks: root.known; visible: Wifi.enabled && root.known.length > 0 }

    Divider {
        visible: Wifi.enabled
        text: "New"
        showScan: true
        scanning: root.open
    }

    NetworkList { networks: root.fresh; visible: Wifi.enabled }

    Text {
        visible: !Wifi.enabled
        width: parent.width
        height: 48
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "Wi-Fi is off"
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.faint
    }

    component Detail: Row {
        property string glyph
        property alias text: value.text
        spacing: 5
        Text {
            visible: parent.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.accent
        }
        Text {
            id: value
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.text
        }
    }

    component NetworkList: Column {
        id: list
        property var networks: []
        width: parent.width
        spacing: 1
        move: Transition { Anim { property: "y" } }

        Repeater {
            model: ScriptModel { values: list.networks; objectProp: "name" }
            NetworkRow {
                required property var modelData
                network: modelData
                expanded: root.expanded === modelData.name
                onExpandRequested: root.expanded = modelData.name
                onCollapseRequested: if (root.expanded === modelData.name) root.expanded = ""
            }
        }
    }
}
