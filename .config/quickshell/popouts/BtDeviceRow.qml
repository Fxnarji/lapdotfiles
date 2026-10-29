import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs

// One Bluetooth device row (design 6a):
//   connected  highlighted, accent icon, battery %; Disconnect on hover
//   paired     grey; click to connect, Forget on hover
//   nearby     Pair button (accent for named devices, plain for bare addresses)
PanelRow {
    id: root

    required property var device
    property string mode: "paired"
    signal pairRequested()

    readonly property string icon: device.icon ?? ""
    // Devices that only announce their address get "AA-BB-…" as their name.
    readonly property bool named: !!device.name && device.name.replace(/-/g, ":") !== device.address
    // Some headsets (like the Arctis) don't report a device type to BlueZ;
    // spot them by the PipeWire sink they create (bluez_output.AA_BB_…).
    readonly property bool hasSink: Pipewire.nodes.values.some(n =>
        n.isSink && n.name.includes(device.address.replace(/:/g, "_")))
    readonly property bool busy: device.pairing
        || device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting
    readonly property real battery: device.batteryAvailable ? device.battery * 100 : -1

    glyph: {
        if (icon.includes("headset") || icon.includes("headphone") || hasSink) return "";
        if (icon.includes("keyboard")) return "";
        if (icon.includes("mouse")) return "";
        if (icon.includes("phone")) return "";
        if (icon.includes("computer")) return "";
        if (icon.includes("gaming")) return "";
        if (icon.includes("audio")) return "";
        return named ? "" : "";
    }
    glyphColor: mode === "connected" ? Theme.accent : named ? Theme.dim : Theme.faint
    text: named ? device.name : device.address
    mono: !named
    textColor: mode === "paired" || !named ? Theme.dim : Theme.text
    highlighted: mode === "connected"

    onClicked: if (mode === "paired" && !busy) device.connect()

    // Status while something is happening.
    Text {
        visible: root.busy
        anchors.verticalCenter: parent.verticalCenter
        text: root.device.pairing ? "pairing…"
            : root.device.state === BluetoothDeviceState.Disconnecting ? "disconnecting…" : "connecting…"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.dim
    }

    // Connected: battery, or Disconnect while hovered.
    Text {
        visible: root.mode === "connected" && root.battery >= 0 && !root.hovered && !root.busy
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.battery) + "%"
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: root.battery < 30 ? Theme.accent : Theme.dim
    }
    PanelButton {
        visible: root.mode === "connected" && root.hovered && !root.busy
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 24
        text: "Disconnect"
        onClicked: root.device.disconnect()
    }

    PanelButton {
        visible: root.mode === "paired" && root.hovered && !root.busy
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 24
        text: "Forget"
        onClicked: root.device.forget()
    }

    PanelButton {
        visible: root.mode === "nearby" && !root.busy
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 24
        primary: root.named
        text: "Pair"
        onClicked: root.pairRequested()
    }
}
