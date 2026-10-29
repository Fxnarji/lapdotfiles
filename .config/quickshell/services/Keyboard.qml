pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout ("de" / "us"), kept in sync with Hyprland.
//
// Hyprland keeps a layout per input device, and this laptop has several
// "keyboards" (power button, hotkeys, the headset's media keys …). So switch
// all of them to the same layout explicitly, rather than "next" (which flips
// each one and lets them drift apart), and only follow the main keyboard's
// layout events for the indicator.
Singleton {
    id: root

    property string layout: ""
    property string mainKeyboard: ""

    // Order of kb_layout in hypr/modules/input.lua.
    readonly property var layouts: ["de", "us"]

    function shortName(name) {
        const n = name.toLowerCase();
        if (n.startsWith("german")) return "de";
        if (n.startsWith("english")) return "us";
        return n.slice(0, 2);
    }

    function next() {
        const i = (layouts.indexOf(layout) + 1) % layouts.length;
        switcher.command = ["hyprctl", "switchxkblayout", "all", String(i)];
        switcher.running = true;
    }

    Process { id: switcher }

    GlobalShortcut {
        name: "keyboard"
        description: "Switch keyboard layout"
        onPressed: root.next()
    }

    // Initial value and the main keyboard's name.
    Process {
        id: query
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kbs = JSON.parse(text).keyboards;
                const kb = kbs.find(k => k.main) || kbs[0];
                if (!kb) return;
                root.mainKeyboard = kb.name;
                root.layout = root.shortName(kb.active_keymap);
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // activelayout>>KEYBOARD,LAYOUT NAME
            if (event.name !== "activelayout") return;
            const comma = event.data.indexOf(",");
            const kb = event.data.slice(0, comma);
            if (root.mainKeyboard === "" || kb === root.mainKeyboard)
                root.layout = root.shortName(event.data.slice(comma + 1));
        }
    }
}
