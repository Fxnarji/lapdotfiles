import QtQuick
import Quickshell.Networking
import qs
import qs.services

// One Wi-Fi network. Click: connect (known or open networks) or open the
// password field for a new secured one. Known networks show Forget on hover.
Rectangle {
    id: root

    required property var network
    property bool expanded: false
    signal expandRequested()
    signal collapseRequested()

    readonly property bool secured: network.security !== WifiSecurityType.Open
                                    && network.security !== WifiSecurityType.Owe
    readonly property bool busy: network.stateChanging
    property string error: ""

    width: parent?.width ?? 0
    height: content.implicitHeight
    Behavior on height { Anim {} }
    clip: true
    radius: 10
    color: expanded ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

    function activate() {
        if (busy || network.connected) return;
        if (network.known || !secured) { error = ""; network.connect(); }
        else root.expanded ? root.collapseRequested() : root.expandRequested();
    }

    function submit() {
        if (password.text === "") return;
        error = "";
        network.connectWithPsk(password.text);
    }

    onExpandedChanged: if (expanded) { password.text = ""; error = ""; password.forceActiveFocus(); }

    Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.error = reason === ConnectionFailReason.NoSecrets ? "wrong password" : "failed";
        }
        function onConnectedChanged() { if (root.network.connected) root.collapseRequested(); }
    }

    Column {
        id: content
        width: parent.width
        bottomPadding: root.expanded ? 10 : 0

        PanelRow {
            id: row
            text: root.network.name
            leading: SignalBars {
                anchors.centerIn: parent
                level: Wifi.signalLevel(root.network.signalStrength)
            }
            onClicked: root.activate()

            Text {
                visible: root.busy || root.error !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.busy ? "connecting…" : root.error
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeXs
                color: root.error ? Theme.accent : Theme.dim
            }
            PanelButton {
                visible: root.network.known && row.hovered && !root.busy
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 24
                text: "Forget"
                onClicked: root.network.forget()
            }
            Text {
                visible: root.secured
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeXs
                color: Theme.faint
            }
        }

        // Password: red-outlined field and a solid Connect button.
        Row {
            visible: root.expanded
            x: 10
            width: parent.width - 20
            spacing: 8

            Rectangle {
                width: parent.width - connect.width - parent.spacing
                height: 34
                radius: 9
                color: Theme.bg
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.7)

                TextInput {
                    id: password
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSize
                    font.letterSpacing: 2
                    color: Theme.text
                    selectionColor: Qt.alpha(Theme.accent, 0.35)
                    cursorDelegate: Rectangle { width: 1.5; color: Theme.accent }
                    clip: true
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                }
            }

            PanelButton {
                id: connect
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                text: root.busy ? "…" : "Connect"
                enabled: !root.busy
                onClicked: root.submit()
            }
        }
    }
}
