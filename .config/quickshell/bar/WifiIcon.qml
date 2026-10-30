import QtQuick
import qs

// Wi-Fi fan: a dot and three arcs. Arcs light up in the accent with signal
// strength (0–100); unlit ones stay faint. `connected: false` greys it all out.
// Beside the fan, a house while Tailscale is up and a padlock while any other
// VPN is; with both, the house sits on top of the padlock.
Canvas {
    id: root

    property int strength: 0
    property bool connected: true
    property bool tailscale: false
    property bool vpn: false
    readonly property int bars: !connected ? 0 : strength > 70 ? 3 : strength > 45 ? 2 : strength > 20 ? 1 : 0

    anchors.verticalCenter: parent?.verticalCenter
    width: tailscale || vpn ? 24 : 18
    height: 14

    onBarsChanged: requestPaint()
    onConnectedChanged: requestPaint()
    onTailscaleChanged: requestPaint()
    onVpnChanged: requestPaint()
    Connections { target: Theme; function onAccentChanged() { root.requestPaint(); } }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = 9, cy = height - 1.5;
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

        // Badges, 6px tall, in a column at the right; the lone one sits at the bottom.
        const bx = width - 3.5;
        ctx.strokeStyle = ctx.fillStyle = on;
        if (tailscale) house(ctx, bx, vpn ? 0.5 : height - 6.5);
        if (vpn) padlock(ctx, bx, height - 6.5);
    }

    // Roof over a body.
    function house(ctx, x, top) {
        ctx.beginPath();
        ctx.moveTo(x - 3.2, top + 3);
        ctx.lineTo(x, top);
        ctx.lineTo(x + 3.2, top + 3);
        ctx.closePath();
        ctx.fill();
        ctx.fillRect(x - 2.2, top + 3, 4.4, 3);
    }

    // Shackle over a body.
    function padlock(ctx, x, top) {
        ctx.lineWidth = 1.4;
        ctx.beginPath();
        ctx.moveTo(x - 1.7, top + 2.5);
        ctx.arc(x, top + 2, 1.7, Math.PI, 0);
        ctx.lineTo(x + 1.7, top + 2.5);
        ctx.stroke();
        ctx.fillRect(x - 3, top + 2.5, 6, 3.5);
    }
}
