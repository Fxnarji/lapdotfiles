import QtQuick
import qs

// Popout header: title on the left, a control (switch, mute button) on the right.
Item {
    id: root

    property string title
    default property alias trailing: slot.data

    width: parent?.width ?? 0
    height: 34

    Text {
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        text: root.title
        font.family: Theme.font
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Item {
        id: slot
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
}
