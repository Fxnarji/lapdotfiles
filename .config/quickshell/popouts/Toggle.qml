import QtQuick
import qs

// On/off switch. The knob slides with the shell's fluid curve.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    width: 34
    height: 20
    radius: height / 2
    color: checked ? Theme.accent : Theme.hover
    Behavior on color { ColorAnimation { duration: Theme.normal } }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        Behavior on x { Anim {} }
        color: root.checked ? Theme.accentText : Theme.text
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
