pragma Singleton

import QtQuick
import Quickshell

// Which popouts are open. Audio, Wi-Fi and Bluetooth can be open together; the
// notification center is exclusive with both. `focused` is the popout that
// gets the accent border and glow.
Singleton {
    id: root

    property bool wifi: false
    property bool bluetooth: false
    property bool audio: false
    property string focused: ""
    readonly property bool anyPopout: wifi || bluetooth || audio

    // A click on a bar icon first closes the popouts (focus loss), then toggles.
    // Ignore toggles right after such a close so the click doesn't reopen them.
    property real closedAt: 0

    function toggle(name) {
        if (Date.now() - closedAt < 300) return;
        root[name] = !root[name];
    }

    function closeAll() {
        wifi = false;
        bluetooth = false;
        audio = false;
        closedAt = Date.now();
    }

    onWifiChanged: opened(wifi, "wifi")
    onBluetoothChanged: opened(bluetooth, "bluetooth")
    onAudioChanged: opened(audio, "audio")

    function opened(isOpen, name) {
        if (isOpen) {
            focused = name;
            Notifs.centerOpen = false;
        } else if (focused === name) {
            focused = wifi ? "wifi" : bluetooth ? "bluetooth" : audio ? "audio" : "";
        }
    }

    Connections {
        target: Notifs
        function onCenterOpenChanged() {
            if (Notifs.centerOpen) { root.wifi = false; root.bluetooth = false; root.audio = false; }
        }
    }
}
