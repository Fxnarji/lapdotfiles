import QtQuick
import qs

// Small rounded text button for the notification center header.
Rectangle {
    id: root

    property string text
    property bool mono: false
    property bool active: false
    signal clicked()

    width: label.implicitWidth + 22
    height: 28
    radius: 9
    color: active ? Theme.accent : area.containsMouse && enabled ? Theme.hover : Theme.raised
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on opacity { Anim { duration: Theme.fast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: root.mono ? Theme.fontMono : Theme.font
        font.pixelSize: Theme.fontSizeSm
        font.weight: Font.Medium
        color: root.active ? Theme.accentText : Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
