import QtQuick
import qs
import qs.services

// Basic "new event" form, shown in place of the day agenda. Three kinds:
// an event (start and end time), all day (first and last day) and a
// deadline (one time, no length). Enter saves, Esc goes back.
Item {
    id: root

    signal done()

    property string kind: "event"      // event | allday | deadline
    property string calendar: ""
    property string error: ""
    readonly property bool saving: CalendarData.adding

    // Fill in the selected day; times default to the next full hour.
    function reset() {
        const day = CalendarData.selected;
        const now = new Date();
        const hour = CalendarData.sameDay(day, now) ? Math.min(23, now.getHours() + 1) : 9;
        const pad = n => String(n).padStart(2, "0");
        title.text = "";
        date.text = CalendarData.isoDate(day);
        until.text = CalendarData.isoDate(day);
        start.text = `${pad(hour)}:00`;
        end.text = `${pad(Math.min(23, hour + 1))}:${hour === 23 ? "59" : "00"}`;
        location.text = "";
        kind = "event";
        error = "";
        const cals = CalendarData.calendars.map(c => c.name);
        if (!cals.includes(calendar)) calendar = cals.find(n => n.toLowerCase() === "personal") ?? cals[0] ?? "";
        title.forceActiveFocus();
    }

    function time(text) {
        const m = /^(\d{1,2})[:.]?(\d{2})$/.exec(text.trim());
        if (!m || +m[1] > 23 || +m[2] > 59) return null;
        return m[1].padStart(2, "0") + ":" + m[2];
    }
    function day(text) {
        const t = text.trim();
        return /^\d{4}-\d{2}-\d{2}$/.test(t) && !isNaN(new Date(t + "T00:00")) ? t : null;
    }

    function save() {
        if (saving) return;
        const fields = { calendar, title: title.text.trim(), location: location.text.trim(), allDay: kind === "allday" };
        const d = day(date.text);
        if (!fields.title) { error = "Give it a title."; return; }
        if (!calendar) { error = "No calendar to add it to."; return; }
        if (!d) { error = "Date: use YYYY-MM-DD."; return; }
        if (kind === "allday") {
            const last = day(until.text);
            if (!last) { error = "Until: use YYYY-MM-DD."; return; }
            if (last < d) { error = "It ends before it starts."; return; }
            fields.start = d;
            fields.end = last;
        } else {
            const s = time(start.text);
            if (!s) { error = "Time: use HH:MM."; return; }
            fields.start = `${d}T${s}`;
            if (kind === "event") {
                const e = time(end.text);
                if (!e) { error = "End: use HH:MM."; return; }
                if (e <= s) { error = "It ends before it starts."; return; }
                fields.end = `${d}T${e}`;
            }
        }
        error = "";
        CalendarData.add(fields);
    }

    Connections {
        target: CalendarData
        function onAdded(ok, message) {
            if (ok) root.done();
            else root.error = message;
        }
    }

    // ---- layout -------------------------------------------------------------

    Item {
        id: header
        width: parent.width
        height: 48

        Column {
            Text {
                text: "New event"
                font.family: Theme.font
                font.pixelSize: Theme.fontSize2xl
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                text: "added to your calendar right away"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSm
                color: Theme.dim
            }
        }
        IconButton {
            anchors { right: parent.right; top: parent.top; topMargin: 4 }
            glyph: ""
            onClicked: root.done()
        }
    }

    Column {
        anchors { top: header.bottom; topMargin: 18 }
        width: parent.width
        spacing: 14

        Field { id: title; label: "Title"; placeholder: "Dentist"; big: true }

        // Kind
        Row {
            spacing: 6
            Repeater {
                model: [["event", "Event"], ["allday", "All day"], ["deadline", "Deadline"]]
                Chip {
                    required property var modelData
                    text: modelData[1]
                    active: root.kind === modelData[0]
                    onClicked: root.kind = modelData[0]
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            Field { id: date; width: (parent.width - 10) / 2; label: root.kind === "allday" ? "From" : "Date"; placeholder: "YYYY-MM-DD"; mono: true }
            Field { id: until; visible: root.kind === "allday"; width: (parent.width - 10) / 2; label: "Until"; placeholder: "YYYY-MM-DD"; mono: true }
            Field { id: start; visible: root.kind !== "allday"; width: (parent.width - 10) / (root.kind === "event" ? 4 : 2) - (root.kind === "event" ? 5 : 0); label: root.kind === "deadline" ? "Due" : "Start"; placeholder: "HH:MM"; mono: true }
            Field { id: end; visible: root.kind === "event"; width: (parent.width - 10) / 4 - 5; label: "End"; placeholder: "HH:MM"; mono: true }
        }

        Field { id: location; label: "Location"; placeholder: "optional" }

        // Calendar
        Column {
            width: parent.width
            spacing: 6
            visible: CalendarData.calendars.length > 0
            Text {
                text: "CALENDAR"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeXs
                font.letterSpacing: 0.66
                color: Theme.dim
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: CalendarData.calendars
                    Chip {
                        required property var modelData
                        text: modelData.name
                        dot: modelData.color || Qt.rgba(0.937, 0.937, 0.937, 0.35)
                        active: root.calendar === modelData.name
                        onClicked: root.calendar = modelData.name
                    }
                }
            }
        }

        Text {
            visible: root.error !== ""
            width: parent.width
            text: root.error
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSm
            color: Theme.accent
        }

        Row {
            spacing: 8
            IconButton { label: root.saving ? "Saving…" : "Add event"; primary: true; enabled: !root.saving; onClicked: root.save() }
            IconButton { label: "Cancel"; onClicked: root.done() }
        }
    }

    // ---- parts ----------------------------------------------------------------

    // Labelled text field. Enter saves, Esc cancels, Tab moves on.
    component Field: Column {
        id: field
        property alias text: input.text
        property string label
        property string placeholder
        property bool mono: false
        property bool big: false
        function forceActiveFocus() { input.forceActiveFocus(); }

        width: parent.width
        spacing: 6

        Text {
            text: field.label.toUpperCase()
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeXs
            font.letterSpacing: 0.66
            color: Theme.dim
        }
        Rectangle {
            width: parent.width
            height: field.big ? 42 : 36
            radius: 11
            color: Theme.bg
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Qt.rgba(1, 1, 1, 0.1)
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }

            TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                font.family: field.mono ? Theme.fontMono : Theme.font
                font.pixelSize: field.big ? Theme.fontSizeLg : Theme.fontSize
                font.weight: field.big ? Font.DemiBold : Font.Normal
                color: Theme.text
                selectionColor: Qt.alpha(Theme.accent, 0.35)
                selectByMouse: true
                activeFocusOnTab: true
                clip: true

                Keys.onReturnPressed: root.save()
                Keys.onEnterPressed: root.save()
                Keys.onEscapePressed: root.done()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: field.placeholder
                    font: input.font
                    color: Theme.faint
                    visible: input.text === ""
                }
            }
        }
    }

    // Toggle chip, optionally with a colour dot.
    component Chip: Rectangle {
        id: chip
        property string text
        property bool active: false
        property color dot: "transparent"
        signal clicked()

        width: chipRow.implicitWidth + 22
        height: 28
        radius: 9
        color: active ? Qt.alpha(Theme.accent, 0.16) : chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: active ? Qt.alpha(Theme.accent, 0.55) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7
            Rectangle {
                visible: chip.dot.a > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: chip.dot
            }
            Text {
                text: chip.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.Medium
                color: chip.active ? Theme.text : Theme.dim
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
