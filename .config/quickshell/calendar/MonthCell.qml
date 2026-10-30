import QtQuick
import qs
import qs.services

// One day in the month grid (design 9a): the date, a flag chip for deadlines,
// chips for all-day events, then a mini timeline from 09:00 to 20:00 with a
// bar per event (height = duration, at least 12px) and a dashed line per
// deadline. Events outside 09–20 are pushed to the nearest edge.
Rectangle {
    id: root

    required property date date
    readonly property bool inMonth: date.getMonth() === CalendarData.month.getMonth()
    readonly property bool isToday: CalendarData.sameDay(date, today)
    readonly property bool isSelected: CalendarData.sameDay(date, CalendarData.selected)
    readonly property bool weekend: date.getDay() === 0 || date.getDay() === 6
    property date today: CalendarData.today()

    readonly property var info: CalendarData.day(date)

    readonly property int fromMin: 9 * 60
    readonly property int spanMin: 11 * 60

    radius: 10
    color: isToday ? Qt.alpha(Theme.accent, 0.08)
         : isSelected ? Qt.rgba(1, 1, 1, 0.05)
         : area.containsMouse ? Qt.rgba(1, 1, 1, 0.025) : "transparent"
    border.width: 1
    border.color: isToday ? Qt.alpha(Theme.accent, 0.55)
                : isSelected ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.05)
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    clip: true

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CalendarData.select(root.date)
    }

    Item {
        id: content
        anchors { fill: parent; topMargin: 7; leftMargin: 8; rightMargin: 8; bottomMargin: 6 }
        opacity: root.inMonth ? 1 : 0.4

        // Date and deadline chip
        Item {
            id: header
            width: parent.width
            height: 14

            Text {
                id: number
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.date.getDate()).padStart(2, "0")
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize
                font.weight: root.isToday ? Font.DemiBold : Font.Normal
                color: root.isToday ? Theme.accent
                     : !root.inMonth ? Qt.rgba(0.937, 0.937, 0.937, 0.45)
                     : root.weekend ? Theme.dim : Theme.text
            }

            Rectangle {
                visible: root.info.deadlines.length > 0
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: Math.min(chipRow.implicitWidth + 10, parent.width - number.width - 6)
                height: 14
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)
                clip: true

                Row {
                    id: chipRow
                    anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize4xs
                        color: Theme.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, root.width - number.width - 46)
                        elide: Text.ElideRight
                        text: {
                            const d = root.info.deadlines;
                            return d.length === 0 ? "" : d[0].event.title + (d.length > 1 ? ` +${d.length - 1}` : "");
                        }
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize2xs
                        color: Theme.accent
                    }
                }
            }
        }

        // All-day events
        Column {
            id: allDay
            anchors { top: header.bottom; topMargin: root.info.allDay.length > 0 ? 4 : 0 }
            width: parent.width
            spacing: 2

            Repeater {
                model: root.info.allDay.slice(0, root.info.allDay.length > 2 ? 1 : 2)
                Bar {
                    required property var modelData
                    width: allDay.width
                    height: 12
                    event: modelData
                }
            }
            Text {
                visible: root.info.allDay.length > 2
                text: `+${root.info.allDay.length - 1} all day`
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize3xs
                color: Theme.faint
            }
        }

        // 09:00–20:00 timeline
        Item {
            id: timeline
            anchors { top: allDay.bottom; topMargin: 4; bottom: parent.bottom }
            width: parent.width

            Repeater {
                model: root.info.timed
                Bar {
                    required property var modelData
                    readonly property real h: Math.min(timeline.height,
                        Math.max(12, (modelData.to - modelData.from) / root.spanMin * timeline.height))
                    readonly property real slot: timeline.width / modelData.cols
                    event: modelData.event
                    x: modelData.col * slot
                    width: slot - (modelData.cols > 1 ? 2 : 0)
                    height: h
                    y: Math.max(0, Math.min(timeline.height - h, (modelData.from - root.fromMin) / root.spanMin * timeline.height))
                }
            }

            Repeater {
                model: root.info.deadlines
                DashedLine {
                    required property var modelData
                    width: timeline.width
                    height: 1.5
                    y: Math.max(0, Math.min(timeline.height - 2, (modelData.at - root.fromMin) / root.spanMin * timeline.height))
                }
            }
        }
    }

    // Event bar: neutral fill, calendar colour on the left edge.
    component Bar: Rectangle {
        id: bar
        property var event
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.09)
        opacity: event.free ? 0.6 : 1
        clip: true

        Rectangle {
            width: 2
            height: parent.height
            color: CalendarData.colorOf(bar.event)
        }
        Text {
            anchors { left: parent.left; right: parent.right; leftMargin: 5; rightMargin: 3 }
            y: bar.height < 18 ? (bar.height - height) / 2 : 2
            text: (bar.event.uncertain ? "? " : "") + bar.event.title
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize2xs
            color: Theme.text
        }
    }
}
