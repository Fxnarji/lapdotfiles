import QtQuick
import qs

// A rounded bar segment that smoothly resizes to fit its contents.
Rectangle {
    id: root

    default property alias content: row.data
    property int padding: Theme.pillPadding
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.pillRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.line
    clip: true

    Behavior on implicitWidth { Anim {} }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14
    }
}
