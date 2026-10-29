import QtQuick
import Quickshell
import qs

Pill {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Label {
        mono: false
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.bold: true
    }
    Label {
        mono: false
        text: Qt.formatDateTime(clock.date, "ddd dd MMM")
        color: Theme.dim
    }
}
