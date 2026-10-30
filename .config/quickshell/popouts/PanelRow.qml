import QtQuick
import qs

// A list row: a leading glyph (or custom `leading` items), a label, and
// trailing items. `highlighted` gives it the light background used for
// connected devices and the hovered row.
Rectangle {
    id: root

    property string glyph
    property color glyphColor: Theme.dim
    property string text
    property color textColor: Theme.text
    property bool mono: false
    property bool highlighted: false
    property alias leading: lead.data
    default property alias trailing: trail.data
    readonly property alias hovered: area.containsMouse
    signal clicked()
    signal rightClicked()

    width: parent?.width ?? 0
    height: 38
    radius: 10
    color: highlighted ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.08 : 0.06)
         : area.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    Item {
        id: lead
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 16
        height: 16
        Text {
            visible: root.glyph !== ""
            anchors.centerIn: parent
            text: root.glyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMd
            color: root.glyphColor
        }
    }

    Text {
        anchors { left: lead.right; leftMargin: 12; right: trail.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: root.text
        elide: Text.ElideRight
        font.family: root.mono ? Theme.fontMono : Theme.font
        font.pixelSize: root.mono ? Theme.fontSizeSm : Theme.fontSizeMd
        color: root.textColor
    }

    Row {
        id: trail
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
}
