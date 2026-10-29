import QtQuick
import qs

// Battery on its side: a faint body with a nub, filled in the accent up to the
// charge level (0–100), like the volume ramp. The fill's edge is flat (==|
// when not charging and a moving sine wave (==S while charging, with a second,
// fainter wave behind it for depth. Below 20% (not charging) the empty part
// takes on a hint of the accent.
Item {
    id: root

    property real level: 0
    property bool charging: false
    readonly property bool low: !charging && level <= 20
    // Print the level inside the battery (makes the icon bigger to fit).
    property bool showLevel: false

    // Animated copy of `level` for the fill edge.
    property real shown: Math.max(0, Math.min(100, level))
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

    anchors.verticalCenter: parent?.verticalCenter
    width: showLevel ? 32 : 24
    height: showLevel ? 15 : 12

    Rectangle {
        id: body
        width: parent.width - 3
        height: parent.height
        radius: 3
        color: root.low ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(Theme.text, 0.18)
        Behavior on color { ColorAnimation { duration: Theme.normal } }

        Canvas {
            id: fill
            anchors.fill: parent

            readonly property real edge: width * root.shown / 100
            property real phase: 0

            onEdgeChanged: requestPaint()
            Connections {
                target: root
                function onChargingChanged() { fill.requestPaint(); }
            }
            Connections {
                target: Theme
                function onAccentChanged() { fill.requestPaint(); }
            }

            // Moves the wave at 12 fps on the shared clock (only while charging).
            FrameClient {
                active: root.charging && root.visible
                fps: 12
                onTick: dt => { fill.phase += dt * 5; fill.requestPaint(); }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.save();
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, body.radius, body.radius);
                ctx.clip();
                ctx.fillStyle = Theme.accent;

                if (!root.charging) {
                    ctx.fillRect(0, 0, edge, height);
                } else {
                    // Back wave: further out, offset, half opacity.
                    wave(ctx, edge + 1.2, phase * 0.8 + 2.2, 0.45);
                    wave(ctx, edge, phase, 1);
                }
                ctx.restore();
            }

            // Fill from the left up to a vertical sine edge around x = e.
            function wave(ctx, e, ph, alpha) {
                const amp = 1.3;
                ctx.globalAlpha = alpha;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                for (let y = 0; y <= height; y += 1)
                    ctx.lineTo(e + amp * Math.sin(y / height * Math.PI * 2 + ph), y);
                ctx.lineTo(0, height);
                ctx.closePath();
                ctx.fill();
            }
        }

        // Level number. Dark where it sits on the fill, light over the empty
        // part: two copies, each clipped to its side of the fill edge. Hidden
        // while charging so the wave stays readable.
        Item {
            visible: root.showLevel && !root.charging
            anchors.fill: parent
            Item {
                width: fill.edge
                height: parent.height
                clip: true
                LevelText { color: Theme.accentText }
            }
            Item {
                x: fill.edge
                width: parent.width - fill.edge
                height: parent.height
                clip: true
                LevelText { x: -parent.x; color: Theme.text }
            }
        }
    }

    // Nub
    Rectangle {
        anchors { left: body.right; leftMargin: 0.5; verticalCenter: body.verticalCenter }
        width: 2
        height: 5
        radius: 1
        color: body.color
    }

    component LevelText: Text {
        width: body.width
        height: body.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Math.round(root.level)
        font.family: Theme.fontMono
        font.pixelSize: 10
        font.weight: Font.Bold
    }
}
