import QtQuick
import Quickshell
import qs
import qs.services

// Right column of the calendar view (design 9a): the selected day as an hour
// grid. Events are blocks (height = duration, calendar colour on the left
// edge, side by side when they overlap), deadlines a dashed line with a flag
// chip, and today gets the now line and a banner with the current or next
// event. The grid shows 08–20 and grows to fit earlier or later events.
Item {
    id: root

    signal addRequested()

    readonly property date day: CalendarData.selected
    readonly property var info: CalendarData.day(day)
    readonly property bool isToday: CalendarData.sameDay(day, clock.date)

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property real nowMin: clock.date.getHours() * 60 + clock.date.getMinutes()

    function hm(t) { return Qt.formatTime(new Date(t), "HH:mm"); }
    function span(m) {
        m = Math.max(0, Math.round(m));
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${m % 60}m` : `${m}m`;
    }
    // "09:30–09:45", or with weekdays when the event runs over midnight.
    function times(e) {
        const s = new Date(e.start), t = new Date(e.end);
        if (CalendarData.sameDay(s, t)) return `${hm(s)}–${hm(t)}`;
        return `${Qt.formatDateTime(s, "ddd HH:mm")} – ${Qt.formatDateTime(t, "ddd HH:mm")}`;
    }

    // Event in progress, else the next one today (deadlines included).
    readonly property var banner: {
        if (!isToday) return null;
        const now = nowMin;
        const current = info.timed.find(it => it.from <= now && now < it.to);
        if (current) return { title: current.event.title, text: span(current.to - now) + " left", strong: true };
        const next = [...info.timed.map(it => ({ title: it.event.title, at: it.from, due: false })),
                      ...info.deadlines.map(d => ({ title: d.event.title, at: d.at, due: true }))]
            .filter(x => x.at > now).sort((a, b) => a.at - b.at)[0];
        if (next) return { title: next.title, text: (next.due ? "due in " : "in ") + span(next.at - now), strong: false };
        return null;
    }

    // Hours shown: 08–20, widened to fit the day's events.
    readonly property int firstHour: Math.min(8, ...info.timed.map(it => Math.floor(it.from / 60)),
                                                 ...info.deadlines.map(d => Math.floor(d.at / 60)))
    readonly property int lastHour: Math.max(20, ...info.timed.map(it => Math.ceil(it.to / 60)),
                                                ...info.deadlines.map(d => Math.ceil(d.at / 60) + (d.at % 60 === 0 ? 1 : 0)))
    readonly property real hourHeight: Math.max(36, (grid.height - 14) / (lastHour - firstHour))
    function yAt(minutes) { return (minutes / 60 - firstHour) * hourHeight + 7; }

    // ---- header -------------------------------------------------------------

    Item {
        id: header
        width: parent.width
        height: 48

        Column {
            anchors.left: parent.left
            Text {
                text: Qt.formatDate(root.day, "dddd")
                font.family: Theme.font
                font.pixelSize: Theme.fontSize2xl
                font.weight: Font.DemiBold
                font.letterSpacing: -0.2
                color: Theme.text
            }
            Text {
                text: {
                    const n = root.info.timed.length + root.info.allDay.length, d = root.info.deadlines.length;
                    let s = Qt.formatDate(root.day, "dd MMM") + ` · ${n} event${n === 1 ? "" : "s"}`;
                    if (d > 0) s += ` · ${d} deadline${d === 1 ? "" : "s"}`;
                    return s;
                }
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSm
                color: Theme.dim
            }
        }

        IconButton {
            anchors { right: parent.right; top: parent.top; topMargin: 4 }
            glyph: ""
            onClicked: root.addRequested()
        }
    }

    // ---- banner and all-day events ------------------------------------------

    Column {
        id: topArea
        anchors { top: header.bottom; topMargin: 14 }
        width: parent.width
        spacing: 6

        Rectangle {
            visible: root.banner !== null
            width: parent.width
            height: 38
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)

            Text {
                id: bannerIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
                color: root.banner?.strong ? Theme.accent : Theme.dim
            }
            Text {
                anchors { left: bannerIcon.right; leftMargin: 10; right: bannerTime.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: root.banner?.title ?? ""
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                color: Theme.text
            }
            Text {
                id: bannerTime
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: root.banner?.text ?? ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSm
                color: root.banner?.strong ? Theme.accent : Theme.dim
            }
        }

        Repeater {
            model: root.info.allDay
            Rectangle {
                id: allDayRow
                required property var modelData
                width: topArea.width
                height: 28
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                Rectangle { width: 3; height: parent.height; color: CalendarData.colorOf(allDayRow.modelData) }
                Text {
                    anchors { left: parent.left; leftMargin: 12; right: allDayWhen.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: (allDayRow.modelData.uncertain ? "? " : "") + allDayRow.modelData.title
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: Theme.text
                }
                Text {
                    id: allDayWhen
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: {
                        const e = allDayRow.modelData;
                        const last = CalendarData.addDays(new Date(e.end + "T00:00"), -1);
                        return CalendarData.isoDate(last) === e.start ? "all day" : "until " + Qt.formatDate(last, "ddd dd MMM");
                    }
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.dim
                }
            }
        }
    }

    // ---- hour grid ------------------------------------------------------------

    Flickable {
        id: grid
        anchors { top: topArea.bottom; topMargin: topArea.height > 0 ? 14 : 4; bottom: parent.bottom }
        width: parent.width
        contentHeight: root.yAt(root.lastHour * 60) + 7
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: true

        // Hour lines
        Repeater {
            model: root.lastHour - root.firstHour + 1
            Item {
                required property int index
                y: root.yAt((root.firstHour + index) * 60)
                width: grid.width
                Text {
                    y: -7
                    width: 38
                    text: String((root.firstHour + parent.index) % 24).padStart(2, "0") + ":00"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.faint
                }
                Rectangle { x: 50; width: grid.width - 50; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }

        // Events
        Repeater {
            model: root.info.timed
            Rectangle {
                id: block
                required property var modelData
                readonly property var event: modelData.event
                readonly property real slot: (grid.width - 50) / modelData.cols
                readonly property bool compact: height < 38

                x: 50 + modelData.col * slot
                y: root.yAt(modelData.from) + 1
                width: slot - (modelData.cols > 1 ? 4 : 0)
                height: Math.max(20, (modelData.to - modelData.from) / 60 * root.hourHeight - 2)
                radius: compact ? 7 : 9
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                opacity: event.free ? 0.6 : 1
                clip: true

                Rectangle { width: 3; height: parent.height; color: CalendarData.colorOf(block.event) }

                readonly property string detail: [root.times(event), event.location, event.uncertain ? "uncertain" : ""]
                    .filter(s => s).join(" · ")

                // One line when short, title over details otherwise.
                Row {
                    visible: block.compact
                    anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text {
                        id: compactTitle
                        width: Math.min(implicitWidth, parent.width * 0.6)
                        text: block.event.title
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                    Text {
                        width: parent.width - compactTitle.width - parent.spacing
                        anchors.baseline: compactTitle.baseline
                        text: block.detail
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.dim
                    }
                }
                Column {
                    visible: !block.compact
                    anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 7 }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: block.event.title
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: block.detail
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.dim
                    }
                }
            }
        }

        // Deadlines
        Repeater {
            model: root.info.deadlines
            Item {
                id: deadline
                required property var modelData
                x: 44
                y: root.yAt(modelData.at)
                width: grid.width - 44

                DashedLine { width: parent.width; height: 1.5 }
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.min(dueRow.implicitWidth + 16, parent.width)
                    height: 20
                    radius: 6
                    color: Theme.raised
                    border.width: 1
                    border.color: Qt.alpha(Theme.accent, 0.55)
                    clip: true
                    Row {
                        id: dueRow
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Text { text: ""; font.family: Theme.fontMono; font.pixelSize: Theme.fontSize2xs; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: `${deadline.modelData.event.title} · due ${root.hm(deadline.modelData.event.start)}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        // Now
        Rectangle {
            visible: root.isToday && root.nowMin >= root.firstHour * 60 && root.nowMin <= root.lastHour * 60
            x: 44
            y: root.yAt(root.nowMin) - 1
            width: grid.width - 44
            height: 2
            color: Theme.accent
            Rectangle {
                x: -4; y: -3
                width: 8; height: 8; radius: 4
                color: Theme.accent
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: 8; radius: 4
                color: Qt.alpha(Theme.accent, 0.18)
                z: -1
            }
        }

        Text {
            visible: root.info.timed.length + root.info.deadlines.length === 0
            x: 50
            width: grid.width - 50
            y: root.yAt(12 * 60) - 20
            horizontalAlignment: Text.AlignHCenter
            text: root.info.allDay.length > 0 ? "No appointments" : "Nothing planned"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.faint
        }
    }

    // Start at the first event (or now) when the grid scrolls.
    function scrollToStart() {
        if (!info) return;
        const starts = info.timed.map(it => it.from).concat(info.deadlines.map(d => d.at));
        const target = isToday ? nowMin - 60 : (starts.length ? Math.min(...starts) - 30 : 8 * 60);
        grid.contentY = Math.max(0, Math.min(grid.contentHeight - grid.height, yAt(target)));
    }
    onDayChanged: scrollToStart()
}
