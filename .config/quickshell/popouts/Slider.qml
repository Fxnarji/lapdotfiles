import QtQuick
import qs

// Volume slider: thin track, accent fill, white knob. Drag or click to set,
// scroll to nudge. `muted` greys it out.
Item {
    id: root

    property real value: 0          // 0–1
    property bool muted: false
    signal moved(real value)

    height: 14

    function set(v) { root.moved(Math.max(0, Math.min(1, v))); }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.12)

        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height
            radius: 2
            color: root.muted ? Qt.rgba(1, 1, 1, 0.25) : Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }

    Rectangle {
        id: knob
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(1, root.value)) * (root.width - width)
        Behavior on x { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        color: root.muted ? Theme.dim : Theme.text
        scale: drag.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
    }

    MouseArea {
        id: drag
        anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.set((mouse.x - knob.width / 2) / (root.width - knob.width))
        onPositionChanged: mouse => { if (pressed) root.set((mouse.x - knob.width / 2) / (root.width - knob.width)); }
        onWheel: wheel => root.set(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
