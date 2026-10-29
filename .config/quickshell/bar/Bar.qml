import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Floating pill bar: clock + media | workspaces | bluetooth + status.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: Theme.gap; left: Theme.gap; right: Theme.gap }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    Row {
        anchors.left: parent.left
        height: parent.height
        spacing: Theme.pillGap
        Clock {}
        Media {}
    }

    Workspaces {
        anchors.centerIn: parent
    }

    Row {
        anchors.right: parent.right
        height: parent.height
        spacing: Theme.pillGap
        BluetoothPill {}
        Status {}
    }
}
