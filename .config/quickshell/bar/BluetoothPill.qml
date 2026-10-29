import QtQuick
import Quickshell.Bluetooth
import qs
import qs.services

// Bluetooth in its own pill: icon, the connected device and its battery.
// Just the icon when nothing is connected; dimmed when Bluetooth is off.
// Click: Bluetooth panel. Right-click: power on/off.
Pill {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var device: on ? (adapter.devices.values.find(d => d.connected) ?? null) : null

    spacing: 8

    Label {
        text: ""
        color: root.device ? Theme.accent : root.on ? Theme.text : Theme.faint
        width: 12
        horizontalAlignment: Text.AlignHCenter
    }
    Label {
        visible: root.device !== null
        mono: false
        text: root.device?.name ?? ""
        width: Math.min(implicitWidth, 180)
        elide: Text.ElideRight
    }
    BatteryIcon {
        visible: root.device?.batteryAvailable ?? false
        level: (root.device?.battery ?? 0) * 100
    }

    // Lives on the pill itself, not in its content row.
    MouseArea {
        parent: root
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) { if (root.adapter) root.adapter.enabled = !root.adapter.enabled; }
            else Panels.toggle("bluetooth");
        }
    }
}
