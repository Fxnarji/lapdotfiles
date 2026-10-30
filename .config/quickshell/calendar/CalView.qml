import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Calendar view (design 9a): the month as a grid of mini timelines on the
// left, the selected day's agenda (or the new-event form) on the right.
// Opened by clicking the bar clock, Super+C (quickshell:calview) or
// `qs ipc call calview toggle`. The bar stays visible above it.
//
// Keys: ← → ↑ ↓ move the day, PgUp/PgDn the month, T today, N new event,
// Space toggles the day pane, Esc / Q close.
Scope {
    id: root

    property bool adding: false
    property bool detail: false
    // Window mapped: from opening until the close animation has finished.
    property bool mapped: false

    GlobalShortcut {
        name: "calview"
        description: "Toggle the calendar view"
        onPressed: CalendarData.toggle()
    }
    IpcHandler {
        target: "calview"
        function toggle(): void { CalendarData.toggle(); }
    }

    Connections {
        target: CalendarData
        function onOpenChanged() {
            if (CalendarData.open) {
                outro.stop();
                box.opacity = 0;
                box.lift = box.offscreen;
                root.mapped = true;
                intro.restart();
                keys.forceActiveFocus();
            } else {
                intro.stop();
                outro.restart();
            }
        }
    }

    PanelWindow {
        id: win

        visible: root.mapped
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        // Below the bar, so the clock can close it again.
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: Theme.gap + Theme.barHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-calview"
        WlrLayershell.keyboardFocus: CalendarData.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Faint dim; Hyprland blurs everything behind it (see rules.lua).
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.03, 0.03, 0.03, 0.5)
            opacity: box.opacity
        }
        MouseArea {
            anchors.fill: parent
            onClicked: CalendarData.open = false
        }

        RectangularShadow {
            anchors.fill: box
            radius: box.radius
            offset.y: 30
            blur: 80
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: box.opacity
            transform: Translate { y: box.lift }
        }
        RectangularShadow {
            anchors.fill: box
            radius: box.radius
            blur: 40
            color: Qt.alpha(Theme.accent, 0.3)
            opacity: box.opacity
            transform: Translate { y: box.lift }
        }

        Rectangle {
            id: box

            // Centred below the bar. The month part has the screen's aspect
            // ratio; the day pane, its divider and margins widen the box.
            anchors.centerIn: parent
            // The month keeps its width; the box grows to the right and clips,
            // so the pane slides out from behind the edge.
            readonly property real ratio: win.screen ? win.screen.width / win.screen.height : 16 / 9
            readonly property real paneWidth: side.width + divider.width + 48
            readonly property real monthWidth: Math.min(Math.round(height * ratio),
                                                        parent.width - 120 - (root.detail ? paneWidth : 0))
            height: Math.round(parent.height * 0.75)
            width: monthWidth + (root.detail ? paneWidth : 0)
            Behavior on width { Anim {} }
            clip: true

            radius: 20
            color: Theme.raised
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.6)

            // Open: rises from below the screen's bottom edge while fading in.
            // Close: the same in reverse.
            property real lift: 0
            readonly property real offscreen: win.height - y + 120   // past the edge, shadow included
            transform: Translate { y: box.lift }
            ParallelAnimation {
                id: intro
                NumberAnimation { target: box; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                Anim { target: box; property: "lift"; to: 0; duration: Theme.slow }
            }
            ParallelAnimation {
                id: outro
                NumberAnimation { target: box; property: "opacity"; to: 0; duration: Theme.normal; easing.type: Easing.InCubic }
                NumberAnimation { target: box; property: "lift"; to: box.offscreen; duration: Theme.normal; easing.type: Easing.InCubic }
                // Unmap and reset once hidden, so the pane doesn't collapse on screen.
                onFinished: { root.mapped = false; root.adding = false; root.detail = false; }
            }

            // Swallow clicks so they don't reach the close area behind.
            MouseArea { anchors.fill: parent }

            // Keyboard: day and month navigation.
            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    const d = CalendarData.selected;
                    const step = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -7, [Qt.Key_Down]: 7 }[event.key];
                    if (step !== undefined) CalendarData.select(CalendarData.addDays(d, step));
                    else if (event.key === Qt.Key_PageUp) CalendarData.shiftMonth(-1);
                    else if (event.key === Qt.Key_PageDown) CalendarData.shiftMonth(1);
                    else if (event.key === Qt.Key_T) CalendarData.goToday();
                    else if (event.key === Qt.Key_N || event.key === Qt.Key_Plus) root.startAdding();
                    else if (event.key === Qt.Key_Space) root.detail = !root.detail;
                    else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) CalendarData.open = false;
                    else return;
                    event.accepted = true;
                }
            }

            // ---- month -------------------------------------------------------

            Item {
                id: monthPane

                // Month changes: the new month slides in from the side it
                // comes from (later months from the right) and fades up.
                property int shown: 0
                property real slide: 0
                Component.onCompleted: shown = CalendarData.month.getFullYear() * 12 + CalendarData.month.getMonth()
                Connections {
                    target: CalendarData
                    function onMonthChanged() {
                        const m = CalendarData.month.getFullYear() * 12 + CalendarData.month.getMonth();
                        const dir = m > monthPane.shown ? 1 : -1;
                        monthPane.shown = m;
                        if (!win.visible) return;
                        slideIn.from = dir * 40;
                        swap.restart();
                    }
                }
                ParallelAnimation {
                    id: swap
                    Anim { id: slideIn; target: monthPane; property: "slide"; to: 0 }
                    NumberAnimation { targets: [title, grid]; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                }
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom
                          leftMargin: 24; topMargin: 20; bottomMargin: 20 }
                width: box.monthWidth - 48

                Item {
                    id: monthHeader
                    width: parent.width
                    height: 34

                    Row {
                        id: title
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        transform: Translate { x: monthPane.slide * 0.5 }
                        Text {
                            text: Qt.formatDate(CalendarData.month, "MMMM")
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize4xl
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.5
                            color: Theme.text
                        }
                        Text {
                            text: CalendarData.month.getFullYear()
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSize4xl
                            color: Theme.faint
                        }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        IconButton { label: "Today"; primary: true; onClicked: CalendarData.goToday() }
                        IconButton { glyph: ""; onClicked: CalendarData.shiftMonth(-1) }
                        IconButton { glyph: ""; onClicked: CalendarData.shiftMonth(1) }
                    }
                }

                Row {
                    id: weekdays
                    anchors { top: monthHeader.bottom; topMargin: 14 }
                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        Text {
                            required property string modelData
                            width: (monthPane.width + grid.spacing) / 7
                            leftPadding: 8
                            text: modelData.toUpperCase()
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Medium
                            font.letterSpacing: 0.66
                            color: Theme.faint
                        }
                    }
                }

                Grid {
                    id: grid
                    anchors { top: weekdays.bottom; topMargin: 10; bottom: legend.top; bottomMargin: 12 }
                    width: parent.width
                    columns: 7
                    spacing: 6
                    transform: Translate { x: monthPane.slide }

                    readonly property real cellWidth: (width - 6 * spacing) / 7
                    readonly property real cellHeight: (height - (CalendarData.weeks - 1) * spacing) / CalendarData.weeks

                    Repeater {
                        model: CalendarData.weeks * 7
                        MonthCell {
                            required property int index
                            date: CalendarData.addDays(CalendarData.gridStart, index)
                            width: grid.cellWidth
                            height: grid.cellHeight
                        }
                    }
                }

                // Legend: calendars, deadline, scale; errors take its place.
                Item {
                    id: legend
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 16

                    Row {
                        visible: CalendarData.error === ""
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        spacing: 18
                        Repeater {
                            model: CalendarData.calendars
                            Row {
                                required property var modelData
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14; height: 8; radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                    Rectangle { width: 2; height: parent.height; color: parent.parent.modelData.color || Qt.rgba(0.937, 0.937, 0.937, 0.35) }
                                }
                                Text { text: parent.modelData.name; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; color: Theme.dim }
                            }
                        }
                        Row {
                            spacing: 6
                            DashedLine { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 1.5 }
                            Text { text: "deadline"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; color: Theme.dim }
                        }
                    }

                    Text {
                        visible: CalendarData.error !== ""
                        anchors { left: parent.left; leftMargin: 4; right: scale.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "  " + CalendarData.error
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.accent
                    }

                    Text {
                        id: scale
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        text: CalendarData.loading ? "updating…" : "bar height = duration · 09–20"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.faint
                    }
                }
            }

            Rectangle {
                id: divider
                anchors { left: monthPane.right; leftMargin: 24; top: parent.top; bottom: parent.bottom; topMargin: 20; bottomMargin: 20 }
                opacity: side.opacity
                visible: side.visible
                width: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            // ---- day agenda / new event -------------------------------------

            Item {
                id: side
                anchors { left: divider.right; top: parent.top; bottom: parent.bottom
                          leftMargin: 24; topMargin: 20; bottomMargin: 20 }
                width: 340
                opacity: root.detail ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                DayAgenda {
                    anchors.fill: parent
                    visible: !root.adding
                    onAddRequested: root.startAdding()
                }
                AddEvent {
                    id: form
                    anchors.fill: parent
                    visible: root.adding
                    onDone: { root.adding = false; keys.forceActiveFocus(); }
                }
            }
        }

    }

    function startAdding() {
        adding = true;
        detail = true;
        form.reset();
    }
}
