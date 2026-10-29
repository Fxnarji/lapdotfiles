import QtQuick
import qs

// Wi-Fi fan: a dot and three arcs. Arcs light up in the accent with signal
// strength (0–100); unlit ones stay faint. `connected: false` greys it all out.
Canvas {
    id: root

    property int strength: 0
    property bool connected: true
    readonly property int bars: !connected ? 0 : strength > 70 ? 3 : strength > 45 ? 2 : strength > 20 ? 1 : 0

    anchors.verticalCenter: parent?.verticalCenter
    width: 18
    height: 14

    onBarsChanged: requestPaint()
    onConnectedChanged: requestPaint()
    Connections { target: Theme; function onAccentChanged() { root.requestPaint(); } }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height - 1.5;
        const on = Theme.accent, off = Qt.alpha(Theme.text, 0.2);

        ctx.fillStyle = connected ? on : off;
        ctx.beginPath();
        ctx.arc(cx, cy, 1.6, 0, 2 * Math.PI);
        ctx.fill();

        ctx.lineWidth = 2;
        ctx.lineCap = "round";
        for (let i = 1; i <= 3; i++) {
            ctx.strokeStyle = i <= bars ? on : off;
            ctx.beginPath();
            ctx.arc(cx, cy, 3.6 * i + 0.4, -Math.PI * 0.75, -Math.PI * 0.25);
            ctx.stroke();
        }
    }
}
