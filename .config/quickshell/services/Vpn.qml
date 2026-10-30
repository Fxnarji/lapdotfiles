pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// VPN state: any tunnel interface (tun, WireGuard, Tailscale, PPP…) that's up
// with an IPv4 address. Re-read whenever `ip monitor` reports a link or
// address change, so it works for nmcli, wg-quick and tailscale alike.
// Tailscale is told apart from the rest, since it can run alongside another VPN.
Singleton {
    id: root

    // [{ iface, ip, tailscale }], Tailscale first.
    property var tunnels: []
    readonly property bool active: tunnels.length > 0
    readonly property bool tailscale: tunnels.some(t => t.tailscale)
    readonly property bool other: tunnels.some(t => !t.tailscale)

    Process {
        id: query
        command: ["ip", "-j", "-4", "addr", "show", "up"]
        stdout: StdioCollector {
            onStreamFinished: {
                let links = [];
                try { links = JSON.parse(text); } catch (e) {}
                root.tunnels = links
                    .filter(l => (l.link_type === "none" || /^(tun|tap|wg|tailscale|ppp|proton|mullvad|nordlynx)/.test(l.ifname))
                                 && (l.addr_info ?? []).length > 0)
                    .map(l => ({ iface: l.ifname, ip: l.addr_info[0].local, tailscale: l.ifname.startsWith("tailscale") }))
                    .sort((a, b) => b.tailscale - a.tailscale);
            }
        }
    }

    // Changes come in bursts; settle before re-reading.
    Timer {
        id: settle
        interval: 300
        onTriggered: query.running = true
    }

    Process {
        id: monitor
        running: true
        command: ["ip", "monitor", "link", "address"]
        stdout: SplitParser { onRead: settle.restart() }
        onStarted: query.running = true
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: monitor.running = true
    }
}
