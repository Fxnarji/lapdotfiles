import QtQuick
import qs

// Small pill button. `primary` is solid accent with dark text (e.g. Connect).
Rectangle {
    id: root

    property string text
    property bool primary: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: 9
    color: primary ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                   : (area.containsMouse && enabled ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSm
        font.weight: Font.Medium
        color: root.primary ? Theme.accentText : Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
