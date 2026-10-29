import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Toasts in the top-right corner, newest on top. They slide in from the right,
// pause while hovered and drop back into the center when they time out.
PanelWindow {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.gap; right: Theme.gap }
    implicitWidth: 384
    implicitHeight: (screen?.height ?? 1080) * 0.8
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    // Only the cards take clicks; the rest of the window lets them through.
    mask: Region { item: stack }

    NotifStack {
        id: stack
        width: parent.width
        notifications: Notifs.popups
        timeoutFor: n => Notifs.timeout(n)
        onTimedOut: n => Notifs.hidePopup(n)
    }
}
