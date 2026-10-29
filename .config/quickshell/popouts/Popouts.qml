import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Window holding the audio, Wi-Fi and Bluetooth popouts in the top-right corner.
// Open ones line up from the right edge: Bluetooth, then Wi-Fi, then audio,
// sliding over as others open and close, so any combination fits.
// Clicking outside them (focus loss) or Esc closes them. The window is larger
// than the panels so their glow isn't clipped; only the panels take input.
Scope {
    id: root

    GlobalShortcut {
        name: "wifi"
        description: "Toggle the Wi-Fi popout"
        onPressed: Panels.toggle("wifi")
    }
    GlobalShortcut {
        name: "bluetooth"
        description: "Toggle the Bluetooth popout"
        onPressed: Panels.toggle("bluetooth")
    }
    GlobalShortcut {
        name: "audio"
        description: "Toggle the audio popout"
        onPressed: Panels.toggle("audio")
    }
    IpcHandler {
        target: "audio"
        function toggle(): void { Panels.toggle("audio"); }
    }
    IpcHandler {
        target: "wifi"
        function toggle(): void { Panels.toggle("wifi"); }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle(): void { Panels.toggle("bluetooth"); }
    }

    PanelWindow {
        id: win

        // Below the bar: bar margin + bar height + gap.
        readonly property int top: Theme.gap + Theme.barHeight + Theme.gap

        visible: wifi.visible || bluetooth.visible || audio.visible
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        anchors { top: true; right: true; bottom: true }
        implicitWidth: 40 + audio.width + wifi.width + bluetooth.width + 3 * Theme.gap
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-popouts"
        WlrLayershell.keyboardFocus: Panels.anyPopout ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            Region { item: wifi.visible ? wifi : null }
            Region { item: bluetooth.visible ? bluetooth : null }
            Region { item: audio.visible ? audio : null }
        }

        HyprlandFocusGrab {
            windows: [win]
            active: Panels.anyPopout
            onCleared: Panels.closeAll()
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (Panels.focused) Panels[Panels.focused] = false;
                else Panels.closeAll();
            }

            BluetoothPanel {
                id: bluetooth
                x: parent.width - Theme.gap - width
                y: win.top
                maxHeight: win.height - win.top - Theme.gap
                open: Panels.bluetooth
                focused: Panels.focused === "bluetooth"
                onActivated: Panels.focused = "bluetooth"
            }

            WifiPanel {
                id: wifi
                // Left of Bluetooth when it's open, otherwise at the edge.
                x: (Panels.bluetooth ? bluetooth.x : parent.width) - Theme.gap - width
                Behavior on x { Anim { duration: Theme.slow } }
                y: win.top
                maxHeight: win.height - win.top - Theme.gap
                open: Panels.wifi
                focused: Panels.focused === "wifi"
                onActivated: Panels.focused = "wifi"
            }

            AudioPanel {
                id: audio
                // Left of whichever of Wi-Fi / Bluetooth is open.
                x: (Panels.wifi ? wifi.x : Panels.bluetooth ? bluetooth.x : parent.width) - Theme.gap - width
                Behavior on x { Anim { duration: Theme.slow } }
                y: win.top
                maxHeight: win.height - win.top - Theme.gap
                open: Panels.audio
                focused: Panels.focused === "audio"
                onActivated: Panels.focused = "audio"
            }
        }
    }
}
