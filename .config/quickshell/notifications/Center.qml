import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Notification center: slides in on the right below the bar. Toggled from the
// bar bell, Super+N (quickshell:notifications) or `qs ipc call notifications toggle`.
Scope {
    id: root

    function toggle() { Notifs.centerOpen = !Notifs.centerOpen; }

    GlobalShortcut {
        name: "notifications"
        description: "Toggle the notification center"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggle(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
        function clear(): void { Notifs.clearAll(); }
    }

    Connections {
        target: Notifs
        // Toasts would only duplicate what the center shows.
        function onCenterOpenChanged() { if (Notifs.centerOpen) Notifs.popups = []; }
    }

    PanelWindow {
        id: win

        visible: Notifs.centerOpen || panel.opacity > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-notification-center"
        WlrLayershell.keyboardFocus: Notifs.centerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Click anywhere else to close.
        MouseArea {
            anchors.fill: parent
            onClicked: Notifs.centerOpen = false
        }

        Rectangle {
            id: panel

            readonly property int padding: 12
            readonly property int maxHeight: parent.height - 2 * Theme.gap

            anchors { top: parent.top; right: parent.right; margins: Theme.gap }
            width: 400
            height: Math.min(maxHeight, header.height + 2 * padding
                + (Notifs.count > 0 ? stack.height + padding : empty.height))
            Behavior on height { Anim {} }

            color: Theme.surface
            radius: 20
            border.width: 1
            border.color: Theme.line
            clip: true
            focus: Notifs.centerOpen

            Keys.onEscapePressed: Notifs.centerOpen = false

            opacity: Notifs.centerOpen ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.normal } }
            transform: Translate {
                x: Notifs.centerOpen ? 0 : 40
                Behavior on x { Anim { duration: Theme.slow } }
            }

            MouseArea { anchors.fill: parent }

            // Notifications  3                         [dnd]  Clear
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: panel.padding }
                height: 36

                Row {
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text {
                        text: "Notifications"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Font.Bold
                        color: Theme.text
                    }
                    Text {
                        anchors.baseline: parent.children[0].baseline
                        text: Notifs.count
                        visible: Notifs.count > 0
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.faint
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    HeaderButton {
                        text: Notifs.dnd ? "\uf1f6" : "\uf0f3"
                        mono: true
                        active: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                    HeaderButton {
                        text: "Clear"
                        enabled: Notifs.count > 0
                        onClicked: Notifs.clearAll()
                    }
                }
            }

            Flickable {
                id: list
                anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: panel.padding }
                contentHeight: stack.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                NotifStack {
                    id: stack
                    width: list.width
                    notifications: Notifs.list
                }
            }

            Column {
                id: empty
                anchors { top: header.bottom; horizontalCenter: parent.horizontalCenter }
                height: 120
                topPadding: 28
                spacing: 8
                opacity: Notifs.count === 0 ? 1 : 0
                Behavior on opacity { Anim { duration: Theme.normal } }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Notifs.dnd ? "\uf1f6" : "\uf0f3"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSize3xl
                    color: Theme.faint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Notifs.dnd ? "Do not disturb is on" : "All caught up"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    color: Theme.faint
                }
            }
        }
    }
}
