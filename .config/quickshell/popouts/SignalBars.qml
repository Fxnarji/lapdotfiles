import QtQuick
import qs

// Four rising bars; the first `level` (0–4) are lit.
Row {
    id: root

    property int level: 0
    property color litColor: Theme.text

    spacing: 2
    height: 13

    Repeater {
        model: 4
        Rectangle {
            anchors.bottom: parent.bottom
            width: 3
            height: 4 + index * 3
            radius: 1
            color: index < root.level ? root.litColor : Qt.rgba(1, 1, 1, 0.15)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }
}
