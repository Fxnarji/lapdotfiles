pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi state for the bar and the Wi-Fi popout, plus details Quickshell's
// Networking module doesn't expose (IP, band, live speed), read while `watch` is on.
Singleton {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property var networks: (device?.networks.values ?? []).filter(n => n.name)
    readonly property var current: networks.find(n => n.connected) ?? null

    // Set by the popout while it's open: scan, and poll IP / band / speed.
    property bool watch: false

    property string ip: ""
    property string band: ""
    property real down: 0   // bytes per second
    property real up: 0

    function setEnabled(on) { Networking.wifiEnabled = on; }

    // 0–4 lit bars from a 0–1 (or 0–100) strength.
    function signalLevel(s) {
        const v = s <= 1 ? s * 100 : s;
        return v > 75 ? 4 : v > 50 ? 3 : v > 25 ? 2 : v > 0 ? 1 : 0;
    }

    function securityName(sec) {
        switch (sec) {
        case WifiSecurityType.Open: return "Open";
        case WifiSecurityType.Owe: return "Enhanced open";
        case WifiSecurityType.WpaPsk: return "WPA";
        case WifiSecurityType.Wpa2Psk: return "WPA2";
        case WifiSecurityType.Sae: return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3 Enterprise";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap: return "Enterprise";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "WEP";
        default: return "Secured";
        }
    }

    // "84 Mb/s", "640 kb/s"
    function speed(bytesPerSec) {
        const bits = bytesPerSec * 8;
        if (bits >= 1e6) return (bits / 1e6).toFixed(bits >= 1e7 ? 0 : 1) + " Mb/s";
        return Math.round(bits / 1e3) + " kb/s";
    }

    Binding {
        when: root.device !== null
        target: root.device
        property: "scannerEnabled"
        value: root.watch && root.enabled
    }

    // IP and band, refreshed when the connection changes or the popout opens.
    onCurrentChanged: if (watch) details.running = true
    onWatchChanged: if (watch) details.running = true
    Process {
        id: details
        command: ["sh", "-c", `nmcli -t -g IP4.ADDRESS dev show "$1"; nmcli -t -f IN-USE,FREQ dev wifi list --rescan no | grep '^\\*'`, "sh", root.device?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.ip = (lines[0] ?? "").split("/")[0].split("|")[0];
                const mhz = parseInt((lines[1] ?? "").split(":")[1]);
                root.band = mhz >= 5900 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : mhz > 0 ? "2.4 GHz" : "";
            }
        }
    }

    // Live speed from the interface byte counters, once a second.
    property var last: null
    Timer {
        interval: 1000
        repeat: true
        running: root.watch && root.current !== null
        triggeredOnStart: true
        onRunningChanged: root.last = null
        onTriggered: counters.running = true
    }
    Process {
        id: counters
        command: ["sh", "-c", `cat /sys/class/net/"$1"/statistics/rx_bytes /sys/class/net/"$1"/statistics/tx_bytes`, "sh", root.device?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = text.trim().split("\n").map(Number);
                const now = Date.now();
                if (root.last) {
                    const dt = (now - root.last.t) / 1000;
                    root.down = (rx - root.last.rx) / dt;
                    root.up = (tx - root.last.tx) / dt;
                }
                root.last = { t: now, rx: rx, tx: tx };
            }
        }
    }
}
