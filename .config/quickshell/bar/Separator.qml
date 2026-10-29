import QtQuick
import qs

// Thin, faint divider between status items.
Rectangle {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: 1
    height: 12
    color: Qt.alpha(Theme.text, 0.15)
}
