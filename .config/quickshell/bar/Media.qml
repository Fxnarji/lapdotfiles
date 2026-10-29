import QtQuick
import Quickshell.Services.Mpris
import qs

// Now playing: "title · artist" from MPRIS. Prefers a playing player, falls back
// to a paused one (dimmed), fades out when nothing is loaded.
// Click: play/pause. Right-click: next. Scroll: next / previous.
Pill {
    id: root

    readonly property var players: Mpris.players.values.filter(p => p.trackTitle)
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false

    spacing: 8
    opacity: player ? 1 : 0
    Behavior on opacity { Anim {} }

    // Little equalizer: bars bounce at random while playing, rest flat when paused.
    // Driven by the shared 30 fps clock: each bar eases toward a random target
    // and picks a new one every ~150 ms.
    Row {
        id: eq
        anchors.verticalCenter: parent.verticalCenter
        height: 12
        spacing: 2

        property var levels: [0.3, 0.5, 0.4, 0.6]
        property var targets: [0.3, 0.5, 0.4, 0.6]
        property var timers: [0, 0.05, 0.1, 0.15]

        FrameClient {
            active: root.playing
            onTick: dt => {
                const lv = eq.levels.slice(), tg = eq.targets.slice(), tm = eq.timers.slice();
                const k = 1 - Math.pow(0.6, dt * 30);   // same easing at any frame rate
                for (let i = 0; i < 4; i++) {
                    tm[i] -= dt;
                    if (tm[i] <= 0) { tg[i] = 0.2 + Math.random() * 0.8; tm[i] = 0.12 + Math.random() * 0.1; }
                    lv[i] += (tg[i] - lv[i]) * k;
                }
                eq.levels = lv; eq.targets = tg; eq.timers = tm;
            }
        }

        Repeater {
            model: 4
            Rectangle {
                anchors.bottom: parent.bottom
                width: 3
                height: Math.max(3, 12 * (root.playing ? eq.levels[index] : 0))
                radius: 1.5
                color: root.playing ? Theme.accent : Theme.faint
                // Only for the drop to flat on pause; while playing the clock moves them.
                Behavior on height { enabled: !root.playing; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
        }
    }

    // Title · artist. Scrolls like a ticker when it doesn't fit (while playing).
    Item {
        id: ticker
        readonly property int maxWidth: 360
        readonly property int gap: 48
        readonly property bool overflows: label.implicitWidth > maxWidth

        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(label.implicitWidth, maxWidth)
        height: label.implicitHeight
        clip: true

        Row {
            id: strip
            spacing: ticker.gap
            Label { id: label; mono: false; textFormat: Text.StyledText; text: ticker.text; color: root.playing ? Theme.text : Theme.dim }
            Label { visible: ticker.overflows; mono: false; textFormat: Text.StyledText; text: ticker.text; color: label.color }
        }

        readonly property string text: {
            const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
            const t = esc(root.player?.trackTitle ?? "");
            const a = esc(root.player?.trackArtist ?? "");
            return a ? `${t}<font color="${Theme.faint}">  ·  ${a}</font>` : t;
        }

        // Scrolls 1 px per tick (30 px/s), whole pixels so the text stays crisp;
        // wraps after text + gap, where the second copy lines up with the first.
        FrameClient {
            id: scroll
            active: ticker.overflows && root.playing
            onTick: dt => {
                strip.x -= 30 * dt;   // 30 px/s at any frame rate
                if (strip.x <= -(label.implicitWidth + ticker.gap)) strip.x += label.implicitWidth + ticker.gap;
            }
            onActiveChanged: if (!active) strip.x = 0
        }
        // Restart from the beginning on a new track.
        onTextChanged: strip.x = 0
    }

    // Lives on the pill itself, not in its content row.
    MouseArea {
        parent: root
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        enabled: root.player !== null
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) { if (root.player.canGoNext) root.player.next(); }
            else if (root.player.canTogglePlaying) root.player.togglePlaying();
        }
        onWheel: wheel => wheel.angleDelta.y < 0
            ? (root.player.canGoNext && root.player.next())
            : (root.player.canGoPrevious && root.player.previous())
    }
}
