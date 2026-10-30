import QtQuick
import qs

// Horizontal dashed line (deadlines). Set width; height is the thickness.
Item {
    id: root

    property color color: Theme.accent
    property real dash: 4
    property real gap: 3

    implicitHeight: 1.5
    clip: true

    Row {
        spacing: root.gap
        Repeater {
            model: Math.ceil(root.width / (root.dash + root.gap))
            Rectangle { width: root.dash; height: root.height; color: root.color }
        }
    }
}
