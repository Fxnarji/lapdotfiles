pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// On-screen slider for volume or brightness. Shows on any change (keys, bar
// scroll, the slider itself) and hides 1.5 s later, or once the pointer
// leaves it. Stays out of the way while a popout is open, which already
// shows the same controls.
Singleton {
    id: root

    property string kind: ""        // "volume" | "brightness"
    property bool shown: false
    property bool hovered: false

    // Ignore the burst of changes when Pipewire binds a (new) default sink.
    property real quietUntil: Date.now() + 2000

    function show(k) {
        if (Panels.anyPopout || Notifs.centerOpen) return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: if (root.hovered) restart(); else root.shown = false
    }

    onHoveredChanged: if (!hovered && shown) hide.restart()

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    onSinkChanged: quietUntil = Date.now() + 1000

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (Date.now() > root.quietUntil) root.show("volume"); }
        function onMutedChanged() { if (Date.now() > root.quietUntil) root.show("volume"); }
    }

    Connections {
        target: Brightness
        function onAdjusted() { root.show("brightness"); }
    }

    Connections {
        target: Panels
        function onAnyPopoutChanged() { if (Panels.anyPopout) root.shown = false; }
    }
}
