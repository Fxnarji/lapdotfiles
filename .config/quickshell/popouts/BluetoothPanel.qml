import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services

// Bluetooth popout (design 6a): connected devices highlighted on top, paired
// ones as a plain list, new ones below a "New" divider with a scan indicator.
// Scans and accepts pairing only while open.
PopoutPanel {
    id: root

    width: 340

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []

    readonly property var connected: devices.filter(d => d.connected)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var paired: devices.filter(d => d.paired && !d.connected)
        .sort((a, b) => a.name.localeCompare(b.name))
    // Unpaired devices: named ones first, then a few that only show an address.
    readonly property var nearby: {
        const fresh = devices.filter(d => !d.paired);
        const named = fresh.filter(d => d.name && d.name.replace(/-/g, ":") !== d.address);
        const bare = fresh.filter(d => !named.includes(d)).slice(0, 2);
        return [...named, ...bare].slice(0, 8);
    }

    readonly property bool busy: devices.some(d => d.pairing || d.state === BluetoothDeviceState.Connecting)

    // ---- BlueZ plumbing ---------------------------------------------------

    // Scan while open, but pause while anything pairs or connects: scanning at
    // the same time breaks pairing on many chips (this MediaTek one included).
    Binding {
        when: root.adapter !== null
        target: root.adapter
        property: "discovering"
        value: root.open && root.on && !root.busy
    }

    // Accept pairing (bonding) only while open. Without this BlueZ links the
    // device but refuses to save the pairing, and the device hangs up.
    Binding {
        when: root.adapter !== null
        target: root.adapter
        property: "pairable"
        value: root.open && root.on
    }

    // Pairing agent. Quickshell doesn't register one, and BlueZ can't pair
    // without it, so keep bluetoothctl's agent running. It asks "(yes/no)" to
    // confirm a passkey or approve a service; say yes only while this is open.
    Process {
        id: agent
        running: true
        command: ["bluetoothctl"]
        stdinEnabled: true
        onStarted: write("agent NoInputNoOutput\ndefault-agent\n")
        onExited: restartAgent.start()
        stdout: SplitParser {
            splitMarker: "(yes/no)"
            onRead: chunk => {
                const answer = root.open ? "yes" : "no";
                console.warn("bluetooth agent:", chunk.split("\n").pop().trim(), "->", answer);
                agent.write(answer + "\n");
            }
        }
    }
    Timer { id: restartAgent; interval: 3000; onTriggered: agent.running = true }

    // Pair → trust → connect. Trust first: headsets connect their audio the
    // moment pairing finishes, and an untrusted device would need each approved.
    property var pendingConnect: ({})
    function pair(device) {
        device.trusted = true;
        pendingConnect[device.address] = true;
        device.pair();
    }
    Instantiator {
        model: root.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (modelData.paired && root.pendingConnect[modelData.address]) {
                    delete root.pendingConnect[modelData.address];
                    modelData.connect();
                }
            }
        }
    }

    // ---- content ----------------------------------------------------------

    PanelHeader {
        title: "Bluetooth"
        Toggle {
            checked: root.on
            onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }
    }

    DeviceList { devices: root.connected; mode: "connected"; visible: root.on && root.connected.length > 0 }
    DeviceList { devices: root.paired; mode: "paired"; visible: root.on && root.paired.length > 0 }

    Divider {
        visible: root.on
        text: "New"
        showScan: true
        scanning: root.adapter?.discovering ?? false
    }

    DeviceList { devices: root.nearby; mode: "nearby"; visible: root.on }

    Text {
        visible: !root.on
        width: parent.width
        height: 48
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.faint
    }

    component DeviceList: Column {
        id: list
        property var devices: []
        property string mode
        width: parent.width
        spacing: 1
        move: Transition { Anim { property: "y" } }

        Repeater {
            model: ScriptModel { values: list.devices }
            BtDeviceRow {
                required property var modelData
                device: modelData
                mode: list.mode
                onPairRequested: root.pair(modelData)
            }
        }
    }
}
