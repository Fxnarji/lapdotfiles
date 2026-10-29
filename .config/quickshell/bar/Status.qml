import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.services

// volume · brightness · wifi · battery · layout · notifications
Pill {
    id: root

    // ---- data -------------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var network: wifi?.networks?.values?.find(n => n.connected) ?? null

    readonly property var battery: UPower.displayDevice
    readonly property real batteryPct: {
        const p = battery?.percentage ?? 0;
        return p <= 1 ? p * 100 : p;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
                                  || battery?.state === UPowerDeviceState.FullyCharged

    function pct(v) { return Math.round(v <= 1 ? v * 100 : v) + "%"; }

    function run(cmd) { Quickshell.execDetached(cmd); }

    // ---- items ------------------------------------------------------------

    spacing: 10

    StatusItem {
        reserve: ""
        VolumeRamp {
            level: root.sink?.audio?.volume ?? 0
            muted: root.sink?.audio?.muted ?? false
        }
        onClicked: Panels.toggle("audio")
        onRightClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        onScrolled: dir => {
            if (!root.sink?.audio) return;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + dir * 0.05));
        }
    }

    Separator { visible: Brightness.available }

    StatusItem {
        reserve: ""
        visible: Brightness.available
        DisplayIcon { level: Brightness.value * 100 }
        onClicked: Osd.show("brightness")
        onScrolled: dir => Brightness.set(Brightness.value + dir * 0.05)
    }

    Separator {}

    StatusItem {
        icon: ""
        reserve: ""
        WifiIcon {
            connected: root.network !== null
            strength: Math.round((root.network?.signalStrength ?? 0) * ((root.network?.signalStrength ?? 0) <= 1 ? 100 : 1))
        }
        onClicked: Panels.toggle("wifi")
    }

    Separator {}

    StatusItem {
        reserve: ""
        BatteryIcon {
            level: root.batteryPct
            charging: root.charging
            showLevel: true
        }
        visible: root.battery?.isLaptopBattery ?? false
    }

    Separator {}

    StatusItem {
        icon: ""
        value: Keyboard.layout
        reserve: "us"
        onClicked: Keyboard.next()
    }

    Separator {}

    StatusItem {
        icon: Notifs.dnd ? "\uf1f6" : "\uf0f3"
        value: Notifs.count > 0 ? Notifs.count : ""
        reserve: "99"
        tint: Notifs.dnd ? Theme.faint : Notifs.count > 0 ? Theme.accent : Theme.text
        onClicked: Notifs.centerOpen = !Notifs.centerOpen
        onRightClicked: Notifs.dnd = !Notifs.dnd
    }
}
