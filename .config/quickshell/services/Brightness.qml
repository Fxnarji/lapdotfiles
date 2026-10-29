pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness (0–1) of the first backlight, on the same perceptual scale
// as the brightness keys (`brightnessctl -e4`): value = (raw / max)^(1/4).
//
// sysfs doesn't report brightness changes to inotify, so the level is polled.
// `adjusted()` fires on every change after the first read (keys, scroll, slider).
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property real value: 0
    readonly property bool available: device !== "" && max > 0
    property bool ready: false
    signal adjusted()

    // While the slider is dragged, show the requested value rather than
    // (stale) reads, and send at most one brightnessctl every 40 ms.
    property real pending: -1
    property real holdUntil: 0

    function set(v) {
        v = Math.max(0, Math.min(1, v));
        value = v;
        pending = v;
        holdUntil = Date.now() + 400;
        root.adjusted();
        if (!send.running) send.start();
    }

    Timer {
        id: send
        interval: 40
        onTriggered: {
            if (root.pending < 0) return;
            Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", Math.round(root.pending * 100) + "%"]);
            root.pending = -1;
        }
    }

    // "amdgpu_bl2,backlight,45875,70%,65535"
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length < 5) return;
                root.max = parseInt(f[4]);
                root.device = f[0];
            }
        }
    }

    FileView {
        id: file
        path: root.device ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        onLoaded: {
            if (Date.now() < root.holdUntil) return;
            const v = Math.pow(Math.max(0, parseInt(text())) / root.max, 0.25);
            const moved = Math.round(v * 100) !== Math.round(root.value * 100);
            root.value = v;
            if (moved && root.ready) root.adjusted();
            root.ready = true;
        }
    }

    Timer {
        running: root.available
        repeat: true
        interval: 200
        onTriggered: file.reload()
    }
}
