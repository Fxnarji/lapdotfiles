import QtQuick
import qs

// Section divider: small uppercase label, a hairline, and an optional scan
// indicator that spins while `scanning`.
Item {
    id: root

    property string text
    property bool scanning: false
    property bool showScan: false

    width: parent?.width ?? 0
    height: 18

    Text {
        id: label
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        text: root.text
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.66
        font.capitalization: Font.AllUppercase
        color: Theme.dim
    }

    Rectangle {
        anchors { left: label.right; leftMargin: 10; right: scan.visible ? scan.left : parent.right
                  rightMargin: scan.visible ? 10 : 6; verticalCenter: label.verticalCenter }
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Text {
        id: scan
        visible: root.showScan
        anchors { right: parent.right; rightMargin: 6; verticalCenter: label.verticalCenter }
        text: ""
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: root.scanning ? Theme.dim : Theme.faint
        RotationAnimation on rotation {
            running: root.scanning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1600
            onStopped: scan.rotation = 0
        }
    }
}
