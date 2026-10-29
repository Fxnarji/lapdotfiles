pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every color, font, size and animation the shell uses lives here.
// The accent comes from the wallpaper: matugen writes colors.json, this file
// watches it and fades to the new accent.
Singleton {
    id: root

    // Colors (mono palette from the handoff)
    readonly property color bg:      "#111111"
    readonly property color surface: "#171717"
    readonly property color raised:  "#1c1c1c"
    readonly property color hover:   "#2a2a2a"
    readonly property color stripe:  "#202020"   // alternating list rows
    readonly property color selected: "#333333"  // current list row
    readonly property color line:    Qt.rgba(1, 1, 1, 0.08)
    readonly property color text:    "#efefef"
    readonly property color dim:     Qt.rgba(0.937, 0.937, 0.937, 0.55)
    readonly property color faint:   Qt.rgba(0.937, 0.937, 0.937, 0.30)
    readonly property color accentText: "#111111"

    property color accent: "#f2545b"
    Behavior on accent { ColorAnimation { duration: root.slow; easing.type: Easing.InOutQuad } }

    // Fonts
    readonly property string font:     "Geist"
    readonly property string fontMono: "GeistMono Nerd Font"
    readonly property int fontSize:     13
    readonly property int fontSizeMono: 12

    // Sizes
    readonly property int barHeight: 40
    readonly property int gap:       12
    readonly property int pillGap:   8
    readonly property int pillRadius: 12
    readonly property int pillPadding: 14

    // Motion: the same curve as Hyprland's "fluid" (fast start, slight overshoot).
    readonly property var curve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    readonly property int fast:   180
    readonly property int normal: 320
    readonly property int slow:   600

    FileView {
        path: Quickshell.shellDir + "/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.accent) root.accent = c.accent;
            } catch (e) {
                console.warn("Theme: could not read colors.json:", e);
            }
        }
    }
}
