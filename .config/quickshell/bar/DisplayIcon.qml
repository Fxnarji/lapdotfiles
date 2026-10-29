import QtQuick
import qs

// Brightness sun: a disc with eight rays. Faint underneath, with the accent
// on top as opaque as the brightness level (0–100).
Item {
    id: root

    property real level: 0

    // Animated copy of `level` for the glow.
    property real shown: Math.max(0, Math.min(100, level))
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    anchors.verticalCenter: parent?.verticalCenter
    width: 16
    height: 16

    // Two copies: the faint base and the accent on top.
    Repeater {
        model: 2
        Item {
            id: sun
            required property int index
            readonly property color tint: index === 0 ? Qt.alpha(Theme.text, 0.2) : Theme.accent
            anchors.fill: parent
            opacity: index === 0 ? 1 : root.shown / 100

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                radius: 3.5
                color: sun.tint
            }

            Repeater {
                model: 8
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 45
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0.5
                        width: 2
                        height: 3
                        radius: 1
                        color: sun.tint
                    }
                }
            }
        }
    }
}
