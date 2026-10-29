import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

// Dots for workspaces 1-5 (more if in use). The active one stretches into an
// accent pill; the stretch springs with the shared "fluid" curve.
Pill {
    id: root
    padding: 12
    spacing: 8

    readonly property int count: {
        let n = 5;
        for (const ws of Hyprland.workspaces.values)
            n = Math.max(n, HyprState.wsNumber(ws));
        return n;
    }

    Repeater {
        model: root.count

        Rectangle {
            id: dot
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => HyprState.wsNumber(w) === wsId) ?? null
            readonly property bool active: HyprState.activeWorkspace === wsId
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

            anchors.verticalCenter: parent.verticalCenter
            width: active ? 30 : 10
            height: 10
            radius: 5
            color: active ? Theme.accent
                 : ws?.urgent ? Qt.alpha(Theme.accent, 0.6)
                 : mouse.containsMouse ? Qt.alpha(Theme.text, 0.7)
                 : occupied ? Qt.alpha(Theme.text, 0.45)
                 : Qt.alpha(Theme.text, 0.18)

            Behavior on width { Anim { duration: Theme.slow } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }

            MouseArea {
                id: mouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprState.focus(dot.wsId)
            }
        }
    }

    // Scroll anywhere on the pill to move between workspaces.
    WheelHandler {
        onWheel: event => HyprState.focus(event.angleDelta.y > 0 ? "e-1" : "e+1")
    }
}
