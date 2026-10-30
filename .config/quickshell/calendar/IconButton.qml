import QtQuick
import qs

// Square 30px button with a Nerd Font glyph (‹ › + ×). `primary` is solid accent.
Rectangle {
    id: root

    property string glyph
    property string label       // text instead of a glyph, e.g. "Today"
    property bool primary: false
    signal clicked()

    implicitWidth: label ? text.implicitWidth + 24 : 30
    implicitHeight: 30
    radius: 9
    color: primary ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                   : (area.containsMouse && enabled ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label || root.glyph
        font.family: root.label ? Theme.font : Theme.fontMono
        font.pixelSize: root.label ? Theme.fontSize : Theme.fontSizeSm
        font.weight: root.label ? Font.Medium : Font.Normal
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
