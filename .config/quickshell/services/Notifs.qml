pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon. Every notification stays in `list` (the center) until
// dismissed; `popups` holds the ones currently shown as toasts.
Singleton {
    id: root

    property bool dnd: false
    property bool centerOpen: false

    // Newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length

    property var popups: []

    // Arrival times by notification id, for "5m" labels.
    property var times: ({})

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }

    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
    }

    // Short relative time: now, 4m, 2h, 3d.
    function ago(n) {
        const t = times[n.id];
        if (!t) return "";
        const s = (clock.date - t) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    // How long a toast stays up; 0 means until dismissed.
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.expireTimeout > 0) return n.expireTimeout;
        return n.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: new Date() });
            n.closed.connect(() => root.hidePopup(n));
            if (!root.centerOpen && (!root.dnd || n.urgency === NotificationUrgency.Critical))
                root.popups = [n, ...root.popups];
        }
    }
}
