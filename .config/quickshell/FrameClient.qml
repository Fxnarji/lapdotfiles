import QtQuick
import Quickshell
import qs.services

// Subscribes to the shared Frames clock while `active`:
//   FrameClient { active: playing; fps: 12; onTick: dt => { … } }
// `fps` is rounded to a divisor of Frames.fps (24 → 24, 12, 8, 6 …); `dt` is
// the time since this client's last tick.
Scope {
    id: root

    property bool active: false
    property int fps: Frames.fps
    signal tick(real dt)

    readonly property int every: Math.max(1, Math.round(Frames.fps / fps))
    property int count: 0
    property real elapsed: 0

    property bool registered: false
    function sync() {
        if (active === registered) return;
        Frames.listeners += active ? 1 : -1;
        registered = active;
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (registered) Frames.listeners -= 1

    Connections {
        target: Frames
        enabled: root.active
        function onTick(dt) {
            root.elapsed += dt;
            if (++root.count < root.every) return;
            root.tick(root.elapsed);
            root.count = 0;
            root.elapsed = 0;
        }
    }
}
