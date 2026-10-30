import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs
import qs.services

// The volume / brightness slider, dropping in below the bar's right end like
// the other popouts. Drag or scroll it while it's up; click the icon to mute.
PanelWindow {
    id: win

    readonly property bool volume: Osd.kind === "volume"
    readonly property var audio: Osd.sink?.audio ?? null
    readonly property bool muted: volume && (audio?.muted ?? false)
    readonly property real value: volume ? (audio?.volume ?? 0) : Brightness.value

    // Osd.shown too: a hidden window never runs the fade-in that would show it.
    visible: Osd.shown || panel.visible
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]

    anchors { top: true; right: true }
    margins.top: Theme.gap + Theme.barHeight
    implicitWidth: panel.width + 2 * Theme.gap + 40
    implicitHeight: panel.height + Theme.gap + 60
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-osd"

    mask: Region { item: panel }

    HyprlandFocusGrab {
        windows: [win]
        active: Osd.shown && Osd.grab
        onCleared: Osd.shown = false
    }

    function set(v) {
        if (!volume) Brightness.set(v);
        else if (audio) { audio.muted = false; audio.volume = Math.max(0, Math.min(1, v)); }
    }

    PopoutPanel {
        id: panel
        x: parent.width - Theme.gap - width
        y: Theme.gap
        width: 300
        open: Osd.shown
        focused: true

        HoverHandler { onHoveredChanged: Osd.hovered = hovered }

        Item {
            width: parent.width
            height: 22

            Text {
                id: icon
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: 16
                horizontalAlignment: Text.AlignHCenter
                text: !win.volume ? "" : win.muted ? "" : ""
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeMd
                color: win.muted ? Theme.faint : Theme.accent
                MouseArea {
                    anchors { fill: parent; margins: -6 }
                    enabled: win.volume
                    cursorShape: win.volume ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (win.audio) win.audio.muted = !win.audio.muted
                }
            }
            Slider {
                anchors { left: icon.right; leftMargin: 14; right: pct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                value: win.value
                muted: win.muted
                onMoved: v => win.set(v)
            }
            Text {
                id: pct
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 34
                horizontalAlignment: Text.AlignRight
                text: win.muted ? "mute" : Math.round(win.value * 100) + "%"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSm
                color: Theme.dim
            }
        }
    }
}
