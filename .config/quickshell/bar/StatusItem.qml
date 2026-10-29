import QtQuick
import qs

// Icon + value inside the status pill. Click / right-click / scroll handlers optional.
// The value sits in a fixed-width slot sized for `reserve` (its widest text), so
// icons stay put when numbers change.
Item {
    id: root

    property string icon: ""
    property string value: ""
    property string reserve: "100%"
    property color tint: Theme.text
    // Extra children (a graph, a custom icon) go after the icon and value.
    default property alias extra: row.data
    signal clicked()
    signal rightClicked()
    signal scrolled(int direction)

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    TextMetrics {
        id: slot
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeMono
        text: root.reserve
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Label {
            text: root.icon
            visible: root.icon !== ""
            color: root.tint
            width: 16
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            text: root.value
            color: root.tint
            width: root.reserve === "" ? implicitWidth : Math.ceil(slot.advanceWidth)
            visible: root.reserve !== "" || root.value !== ""
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
