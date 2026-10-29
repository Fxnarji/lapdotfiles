pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Focused workspace number. Quickshell 0.3.2 can't read workspace ids from
// Hyprland's Lua build (they come back as -1), so track it from events instead.
Singleton {
    id: root

    property int activeWorkspace: 1
    // A fullscreen window on the focused workspace (covers the bar).
    property bool fullscreen: false

    // Workspace number for a HyprlandWorkspace, using its name when the id is missing.
    function wsNumber(ws) {
        return ws.id > 0 ? ws.id : parseInt(ws.name);
    }

    function focus(target) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(String(target))} })`);
    }

    Process {
        id: query
        running: true
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ws = JSON.parse(text);
                root.activeWorkspace = ws.id;
                root.fullscreen = ws.hasfullscreen;
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // workspacev2>>ID,NAME   focusedmonv2>>MONITOR,WORKSPACEID
            if (event.name === "workspacev2" || event.name === "focusedmonv2") {
                const id = parseInt(event.data.split(",")[event.name === "workspacev2" ? 0 : 1]);
                if (id > 0) root.activeWorkspace = id;
            }
            // Re-check fullscreen when it toggles, the workspace changes or a window closes.
            if (["fullscreen", "workspacev2", "focusedmonv2", "closewindow"].includes(event.name))
                query.running = true;
        }
    }
}
