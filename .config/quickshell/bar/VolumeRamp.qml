import QtQuick
import qs

// Volume as a ramp: a wedge that fills from the left in the accent up to the
// current level (0–1). The rest stays faint; muted greys out the whole wedge.
Canvas {
    id: root

    property real level: 0
    property bool muted: false

    // Animated copy of `level`, so scrolling glides instead of jumping.
    property real shown: level
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    anchors.verticalCenter: parent?.verticalCenter
    width: 26
    height: 12

    onShownChanged: requestPaint()
    onMutedChanged: requestPaint()
    Connections { target: Theme; function onAccentChanged() { root.requestPaint(); } }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const wedge = () => {
            ctx.beginPath();
            ctx.moveTo(1, height - 1);
            ctx.lineTo(width - 1, height - 1);
            ctx.lineTo(width - 1, 1);
            ctx.closePath();
        };

        ctx.fillStyle = Qt.alpha(Theme.text, 0.18);
        wedge();
        ctx.fill();

        if (muted) return;
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, width * Math.min(1, shown), height);
        ctx.clip();
        ctx.fillStyle = Theme.accent;
        wedge();
        ctx.fill();
        ctx.restore();
    }
}
