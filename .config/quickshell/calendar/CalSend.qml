import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// Send text to the calendar (Linux counterpart of the Windows tray app).
// Select text anywhere, press the hotkey (quickshell:calendar, or
// `qs ipc call calendar toggle`): a slim bar opens with the selection above a
// Notes field. Enter sends the note plus the selection, Esc cancels,
// Backspace in the empty field drops the selection. With nothing selected,
// type the appointment into the field. The result arrives as a notification.
//
// Sending goes through backend/calsend.py (a copy of clients/calsend.py from
// the Calendar repo), so the settings are the same:
// CALSEND_URL and CALSEND_KEY in ~/.config/calsend.conf.
Scope {
    id: root

    property bool open: false
    property string selection: ""

    // The bundled calsend.py; set CALSEND_PY to override.
    readonly property string calsend: Quickshell.env("CALSEND_PY") || Quickshell.shellDir + "/calendar/backend/calsend.py"

    function toggle() { open ? close() : show(); }
    function show() {
        selection = "";
        input.text = "";
        // Wayland's primary selection is whatever text is highlighted right now;
        // no Ctrl+C needed and the clipboard stays untouched.
        selectionProc.running = true;
        open = true;
    }
    function close() { open = false; }

    GlobalShortcut {
        name: "calendar"
        description: "Send the selected text to the calendar"
        onPressed: root.toggle()
    }
    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: selectionProc
        command: ["timeout", "2", "wl-paste", "--primary", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: root.selection = text.trim()
        }
    }

    // The note goes first, so it can say which part is meant.
    function compose(note) {
        const n = note.trim();
        if (n && selection) return `My note: ${n}\n\nText:\n${selection}`;
        return n || selection;
    }

    function send() {
        const text = compose(input.text);
        if (!text) return;
        close();
        // Detached, so several sends can run at once and survive a shell reload.
        Quickshell.execDetached(["sh", "-c", `
            out=$(python3 "$1" -- "$2" 2>&1); code=$?
            case $code in
                0) title="Added to calendar" ;;
                2) title="Partly added" ;;
                3) title="Calendar: check settings" ;;
                *) title="Not added" ;;
            esac
            notify-send -a Calendar -i x-office-calendar "$title" "$out"`,
            "--", calsend, text]);
    }

    readonly property string preview: selection.split(/\s+/).filter(w => w !== "").join(" ")
    readonly property int lines: selection === "" ? 0 : selection.split("\n").length

    // ---- window -----------------------------------------------------------

    PanelWindow {
        id: win

        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-calendar"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Faint dim; Hyprland blurs everything behind it (see rules.lua).
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.25)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        RectangularShadow {
            anchors.fill: box
            radius: box.radius
            offset.y: 24
            blur: 60
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: box.opacity
            transform: Translate { y: box.lift }
        }
        RectangularShadow {
            anchors.fill: box
            radius: box.radius
            blur: 40
            color: Qt.alpha(Theme.accent, 0.3)
            opacity: box.opacity
            transform: Translate { y: box.lift }
        }

        Rectangle {
            id: box

            width: 460
            height: body.implicitHeight + 28
            Behavior on height { Anim {} }
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.18)

            radius: 18
            color: Theme.raised
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.6)
            clip: true

            property real lift: 0
            transform: Translate { y: box.lift }
            ParallelAnimation {
                id: intro
                NumberAnimation { target: box; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                Anim { target: box; property: "lift"; from: -14; to: 0; duration: Theme.slow }
            }

            // Swallow clicks so they don't reach the close area behind.
            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 10

                // The selection that will be sent; × drops it.
                Rectangle {
                    id: chip
                    width: parent.width
                    height: root.selection !== "" ? 34 : 0
                    visible: height > 0
                    radius: 10
                    color: Qt.alpha(Theme.accent, 0.12)
                    clip: true
                    Behavior on height { Anim { duration: Theme.normal } }

                    Text {
                        id: chipIcon
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.accent
                    }
                    Text {
                        anchors { left: chipIcon.right; leftMargin: 10; right: chipLines.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: root.preview
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.dim
                    }
                    Text {
                        id: chipLines
                        anchors { right: drop.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        visible: root.lines > 1
                        text: root.lines + " lines"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.faint
                    }
                    Rectangle {
                        id: drop
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 26
                        height: 26
                        radius: 8
                        color: dropArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: dropArea.containsMouse ? Theme.text : Theme.faint
                        }
                        MouseArea {
                            id: dropArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selection = ""; input.forceActiveFocus(); }
                        }
                    }
                }

                // Notes field, ✗ and ✓
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width - 2 * (38 + parent.spacing)
                        height: 38
                        radius: 11
                        color: Theme.bg
                        border.width: 1
                        border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.5) : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                        Text {
                            id: fieldIcon
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.faint
                        }

                        TextInput {
                            id: input
                            anchors { left: fieldIcon.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.accent, 0.35)
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: root.selection !== "" ? "Notes (optional)" : "Appointment, e.g. Dentist Tuesday 14:00"
                                font: input.font
                                color: Theme.faint
                                visible: input.text === ""
                            }

                            Keys.onEscapePressed: root.close()
                            Keys.onReturnPressed: root.send()
                            Keys.onEnterPressed: root.send()
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Backspace && input.text === "" && root.selection !== "") {
                                    root.selection = "";
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    SquareButton {
                        glyph: ""
                        onClicked: root.close()
                    }
                    SquareButton {
                        glyph: ""
                        primary: true
                        enabled: root.selection !== "" || input.text.trim() !== ""
                        onClicked: root.send()
                    }
                }
            }
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (!root.open) return;
                box.opacity = 0;
                intro.restart();
                input.forceActiveFocus();
            }
        }
    }

    component SquareButton: Rectangle {
        id: button
        property string glyph
        property bool primary: false
        signal clicked()

        width: 38
        height: 38
        radius: 11
        opacity: enabled ? 1 : 0.4
        color: primary ? (area.containsMouse && enabled ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                       : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeMd
            color: button.primary ? Theme.accentText : Theme.text
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (button.enabled) button.clicked()
        }
    }
}
