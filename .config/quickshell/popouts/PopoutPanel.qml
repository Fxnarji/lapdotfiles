import QtQuick
import QtQuick.Effects
import qs
import qs.services

// Frame for a popout: radius 18, raised background, 14px padding. The focused
// popout gets the launcher treatment (accent border at 60%, a 40px glow at 30%).
// Drops in from slightly above. Scrolls when taller than `maxHeight`.
Item {
    id: root

    property bool open: false
    property bool focused: false
    property real maxHeight: 700
    default property alias content: body.data
    signal activated()

    readonly property int padding: 14

    height: Math.min(maxHeight, body.implicitHeight + 2 * padding)
    Behavior on height { Anim {} }

    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { Anim { duration: Theme.normal } }

    property real drop: open ? 0 : -14
    Behavior on drop { Anim { duration: Theme.slow } }
    transform: Translate { y: root.drop }

    // Depth shadow, then the accent glow on the focused popout.
    RectangularShadow {
        anchors.fill: frame
        radius: frame.radius
        offset.y: 24
        blur: 60
        color: Qt.rgba(0, 0, 0, 0.5)
    }
    RectangularShadow {
        anchors.fill: frame
        radius: frame.radius
        blur: 40
        color: Qt.alpha(Theme.accent, 0.3)
        opacity: root.focused ? 1 : 0
        Behavior on opacity { Anim { duration: Theme.normal } }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 18
        color: Theme.raised
        border.width: 1
        border.color: root.focused ? Qt.alpha(Theme.accent, 0.6) : Qt.rgba(1, 1, 1, 0.1)
        Behavior on border.color { ColorAnimation { duration: Theme.normal } }
        clip: true

        // Focus follows the pointer between the two popouts.
        HoverHandler { onHoveredChanged: if (hovered) root.activated() }

        Flickable {
            anchors { fill: parent; margins: root.padding }
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            clip: true

            Column {
                id: body
                width: parent.width
                spacing: 12
            }
        }
    }
}
