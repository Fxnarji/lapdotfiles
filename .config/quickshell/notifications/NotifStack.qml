import QtQuick
import Quickshell
import qs

// Vertical stack of notification cards. New cards slide in from the right and
// the others glide to make room. (A Column, not a ListView: ListView loses track
// of card heights while its transitions run and lets cards overlap.)
Column {
    id: root

    property var notifications: []
    // Ms before a card times out and leaves on its own; 0 keeps it.
    property var timeoutFor: n => 0
    signal timedOut(var notif)

    // Hovering any card pauses every countdown, including cards that arrive meanwhile.
    readonly property bool paused: hoverWatch.hovered
    HoverHandler { id: hoverWatch }

    spacing: Theme.pillGap

    move: Transition { Anim { property: "y"; duration: Theme.slow } }

    Repeater {
        model: ScriptModel { values: root.notifications }

        NotifCard {
            id: card
            required property var modelData
            notif: modelData
            width: root.width

            property real slide: 60
            opacity: 0
            transform: Translate { x: card.slide }

            readonly property int timeout: root.timeoutFor(card.notif)
            remaining: timeout > 0 ? 1 : -1

            Component.onCompleted: {
                enter.start();
                if (timeout > 0) countdown.start();
            }
            NumberAnimation {
                id: countdown
                target: card
                property: "remaining"
                from: 1
                to: 0
                duration: card.timeout
                paused: running && root.paused
                onFinished: leave.start()
            }
            ParallelAnimation {
                id: enter
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                Anim { target: card; property: "slide"; to: 0; duration: Theme.slow }
            }
            ParallelAnimation {
                id: leave
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.normal }
                Anim { target: card; property: "slide"; to: 60 }
                onFinished: root.timedOut(card.notif)
            }
        }
    }
}
