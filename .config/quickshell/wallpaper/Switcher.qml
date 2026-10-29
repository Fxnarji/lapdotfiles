import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

// Wallpaper switcher: square previews fanned out like flipping through
// records. The selected one faces you; the rest tilt away and stack up on
// either side. ← → / h l / scroll to flip, Enter or click to apply, Esc to close.
// Opened by Super+Shift+D (quickshell:wallpaper) or `qs ipc call wallpaper open`.
//
// Previews come from ~/.local/bin/wallpaper-thumbs, which cuts the middle
// square of each wallpaper into ~/Pictures/.wallpapercache when this opens.
Scope {
    id: root

    property bool open: false
    property var items: []          // [{ src, thumb }]
    property int current: 0
    property string active: ""      // path of the wallpaper in use

    // Animated position the cards lay out around; follows `current`.
    property real pos: 0
    Behavior on pos { Anim { duration: Theme.slow } }
    onCurrentChanged: pos = current

    // 0 → 1 on open: cards fan out from a stack in the middle.
    property real spread: 0
    Behavior on spread { Anim { duration: 700 } }

    function show() {
        items = [];
        current = 0;
        spread = 0;
        open = true;
        currentQuery.running = true;
        thumbs.running = true;
        fanOut.restart();
    }
    function close() { open = false; }
    function step(d) { if (items.length) current = Math.max(0, Math.min(items.length - 1, current + d)); }
    function apply(i) {
        const item = items[i];
        if (!item) return;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper", item.src]);
        close();
    }

    Timer { id: fanOut; interval: 60; onTriggered: root.spread = 1 }

    GlobalShortcut {
        name: "wallpaper"
        description: "Open the wallpaper switcher"
        onPressed: root.open ? root.close() : root.show()
    }
    IpcHandler {
        target: "wallpaper"
        function open(): void { root.show(); }
        function close(): void { root.close(); }
    }

    Process {
        id: currentQuery
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.cache/current-wallpaper"]
        stdout: StdioCollector { onStreamFinished: root.active = text.trim() }
    }

    // One line per wallpaper as its preview is ready.
    Process {
        id: thumbs
        command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-thumbs"]
        stdout: SplitParser {
            onRead: line => {
                const [src, thumb] = line.split("\t");
                if (!thumb) return;
                root.items = [...root.items, { src: src, thumb: thumb }];
                // Start on the wallpaper in use (the fan-out swings to it).
                if (src === root.active) root.current = root.items.length - 1;
            }
        }
    }

    PanelWindow {
        id: win

        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        readonly property real card: Math.round(Math.min(380, height * 0.44))
        readonly property real cx: width / 2
        readonly property real cy: height / 2 - 24

        // Faint dim; Hyprland blurs everything behind it (see rules.lua).
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
            Keys.onReturnPressed: root.apply(root.current)
            Keys.onEnterPressed: root.apply(root.current)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_H) root.step(-1);
                else if (event.key === Qt.Key_L) root.step(1);
                else if (event.key === Qt.Key_Home) root.current = 0;
                else if (event.key === Qt.Key_End) root.current = root.items.length - 1;
            }
        }

        // Click the background to close; scroll anywhere to flip.
        MouseArea {
            anchors.fill: parent
            property real acc: 0
            onClicked: root.close()
            onWheel: wheel => {
                acc += wheel.angleDelta.y + wheel.angleDelta.x;
                while (acc >= 120) { root.step(-1); acc -= 120; }
                while (acc <= -120) { root.step(1); acc += 120; }
            }
        }

        Repeater {
            model: root.items

            Item {
                id: cover
                required property var modelData
                required property int index

                // Distance from the selected cover, in covers (animated).
                readonly property real o: index - root.pos
                readonly property real a: Math.abs(o)
                readonly property real s: o < 0 ? -1 : 1
                readonly property real near: Math.min(a, 1)
                readonly property bool selected: index === root.current

                width: win.card
                height: win.card
                // The first neighbour sits well clear of the centre; the rest
                // stack tightly behind it, like records in a crate.
                x: win.cx - width / 2 + root.spread * s * (near * win.card * 0.78 + Math.max(0, a - 1) * win.card * 0.2)
                y: win.cy - height / 2
                z: 100 - a
                scale: 1 - near * 0.18
                opacity: a > 5.5 ? Math.max(0, 6.5 - a) : 1
                visible: opacity > 0

                transform: Rotation {
                    origin.x: cover.width / 2
                    origin.y: cover.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: -cover.s * cover.near * 62 * root.spread
                }

                // Glow behind the selected cover.
                RectangularShadow {
                    anchors.fill: art
                    radius: art.radius
                    blur: 48
                    color: Qt.alpha(Theme.accent, 0.35)
                    opacity: cover.selected ? 1 : 0
                    Behavior on opacity { Anim { duration: Theme.normal } }
                }
                RectangularShadow {
                    anchors.fill: art
                    radius: art.radius
                    offset.y: 20
                    blur: 40
                    color: Qt.rgba(0, 0, 0, 0.55)
                }

                ClippingRectangle {
                    id: art
                    anchors.fill: parent
                    radius: 18
                    color: Theme.surface

                    Image {
                        anchors.fill: parent
                        source: "file://" + cover.modelData.thumb
                        sourceSize: Qt.size(640, 640)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { Anim { duration: Theme.normal } }
                    }

                    // Covers further back get darker.
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: Math.min(0.55, cover.a * 0.22)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cover.selected ? root.apply(cover.index) : root.current = cover.index
                }
            }
        }

        // Name and position of the selected wallpaper.
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: win.cy + win.card / 2 + 36 }
            spacing: 6
            opacity: root.items.length && root.spread > 0.9 ? 1 : 0
            Behavior on opacity { Anim { duration: Theme.normal } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, win.card * 1.6)
                elide: Text.ElideMiddle
                text: (root.items[root.current]?.src ?? "").split("/").pop().replace(/\.[^.]+$/, "")
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.current + 1) + " / " + root.items.length
                      + (root.items[root.current]?.src === root.active ? "  ·  current" : "")
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        Text {
            visible: root.items.length === 0 && !thumbs.running
            anchors.centerIn: parent
            text: "No wallpapers in ~/Pictures/wallpapers"
            font.family: Theme.font
            font.pixelSize: 14
            color: Theme.dim
        }
    }
}
