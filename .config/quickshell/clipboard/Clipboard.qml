import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.popouts

// Clipboard history (design 8a, text only). Every text copy is recorded by
// cliphist (see ~/.local/bin/clip-store); pins live in clipboard-pins.json
// and are kept out of the history's 200-entry limit.
// Opened by Super+C (quickshell:clipboard) or `qs ipc call clipboard toggle`.
// Type to search, ↑ ↓ to pick, Enter to paste, Ctrl+P to pin, Del to remove.
Scope {
    id: root

    property bool open: false
    property string query: ""
    property var history: []   // [{ id, raw, text }] newest first; text is cliphist's preview
    property var pins: []      // full texts

    readonly property string home: Quickshell.env("HOME")

    function toggle() { open ? close() : show(); }
    function show() {
        query = "";
        clearArmed = false;
        listProc.running = true;
        open = true;
    }
    function close() { open = false; }

    GlobalShortcut {
        name: "clipboard"
        description: "Toggle the clipboard history"
        onPressed: root.toggle()
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle(); }
    }

    // ---- recording --------------------------------------------------------

    // Stores every text copy while the shell runs; restarted if it dies.
    Process {
        id: watcher
        running: true
        command: [root.home + "/.local/bin/clip-watch"]
        onExited: restartWatcher.start()
    }
    Timer { id: restartWatcher; interval: 2000; onTriggered: watcher.running = true }

    // ---- history ----------------------------------------------------------

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.history = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    return { id: l.slice(0, tab), raw: l, text: l.slice(tab + 1) };
                });
                root.rebuild();
            }
        }
    }

    // Commands that change the history, then reload it.
    Process {
        id: editProc
        onExited: listProc.running = true
    }
    function remove(entry) {
        if (entry.pinned) { unpin(entry.text); return; }
        editProc.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "--", entry.raw];
        editProc.running = true;
    }
    property bool clearArmed: false
    Timer { id: disarm; interval: 3000; onTriggered: root.clearArmed = false }
    function clearHistory() {
        if (!clearArmed) { clearArmed = true; disarm.restart(); return; }
        clearArmed = false;
        editProc.command = ["cliphist", "wipe"];
        editProc.running = true;
    }

    function paste(entry) {
        close();
        if (entry.pinned)
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy && exec "$2"', "--",
                                     entry.text, home + "/.local/bin/clip-paste"]);
        else
            Quickshell.execDetached([home + "/.local/bin/clip-paste", entry.cid]);
    }

    // ---- pins -------------------------------------------------------------

    FileView {
        id: pinFile
        path: root.home + "/.local/share/quickshell/clipboard-pins.json"
        printErrors: false
        onLoaded: {
            try { root.pins = JSON.parse(text()); } catch (e) { root.pins = []; }
            root.rebuild();
        }
    }
    function savePins() { pinFile.setText(JSON.stringify(pins, null, 2)); rebuild(); }
    function unpin(t) { pins = pins.filter(p => p !== t); savePins(); }

    // Pinning a history entry needs its full text, not the preview.
    Process {
        id: decodeProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text !== "" && !root.pins.includes(text)) {
                    root.pins = [text, ...root.pins];
                    root.savePins();
                }
            }
        }
    }
    function togglePin(entry) {
        if (entry.pinned) { unpin(entry.text); return; }
        decodeProc.command = ["cliphist", "decode", entry.cid];
        decodeProc.running = true;
    }

    // ---- list -------------------------------------------------------------

    function flat(s) { return s.split(/\s+/).filter(w => w !== "").join(" "); }

    ListModel { id: entries }

    // Pinned first, then the history without the pinned texts, both filtered
    // by the search.
    function rebuild() {
        const q = query.trim().toLowerCase();
        const match = t => q === "" || t.toLowerCase().includes(q);
        const pinnedFlat = pins.map(flat);
        const keep = list.currentIndex;
        entries.clear();
        for (const p of pins)
            if (match(p)) entries.append({ section: "Pinned", pinned: true, cid: "", raw: "", text: p });
        for (const h of history) {
            const preview = h.text.replace(/…$/, "");
            if (pinnedFlat.some(p => p.startsWith(preview))) continue;
            if (match(h.text)) entries.append({ section: "Recent", pinned: false, cid: h.id, raw: h.raw, text: h.text });
        }
        list.currentIndex = Math.max(0, Math.min(keep, entries.count - 1));
    }
    onQueryChanged: { list.currentIndex = 0; rebuild(); }

    function current() { return list.currentIndex >= 0 && list.currentIndex < entries.count ? entries.get(list.currentIndex) : null; }

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
        WlrLayershell.namespace: "qs-clipboard"
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

            width: 380
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
                spacing: 12

                // Search
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 11
                    color: Theme.bg
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Text {
                        id: searchIcon
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: "\uf002"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.faint
                    }

                    TextInput {
                        id: input
                        anchors { left: searchIcon.right; leftMargin: 10; right: clear.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: Theme.text
                        selectionColor: Qt.alpha(Theme.accent, 0.35)
                        clip: true
                        text: root.query
                        onTextEdited: root.query = text

                        Keys.onEscapePressed: root.close()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onBacktabPressed: list.decrementCurrentIndex()
                        Keys.onReturnPressed: { const e = root.current(); if (e) root.paste(e); }
                        Keys.onEnterPressed: { const e = root.current(); if (e) root.paste(e); }
                        Keys.onDeletePressed: { const e = root.current(); if (e) root.remove(e); }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                const e = root.current();
                                if (e) root.togglePin(e);
                                event.accepted = true;
                            }
                        }
                    }

                    // Clear the history (pins stay). Asks once: click again to confirm.
                    Rectangle {
                        id: clear
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: root.clearArmed ? clearLabel.implicitWidth + 24 : 30
                        height: 30
                        radius: 9
                        color: root.clearArmed ? Qt.alpha(Theme.accent, 0.2)
                             : clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
                        Behavior on width { Anim { duration: Theme.normal } }
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: root.clearArmed ? "clear?" : "\uf1f8"
                            font.family: Theme.fontMono
                            font.pixelSize: root.clearArmed ? Theme.fontSizeXs : Theme.fontSize
                            color: root.clearArmed ? Theme.accent : clearArea.containsMouse ? Theme.text : Theme.dim
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearHistory()
                        }
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: Math.min(contentHeight, 440)
                    visible: entries.count > 0
                    model: entries
                    clip: true
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    keyNavigationWraps: true

                    section.property: "section"
                    section.delegate: Item {
                        required property string section
                        width: list.width
                        height: 30
                        Divider {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
                            text: parent.section
                        }
                    }

                    delegate: ClipRow {
                        text: model.text
                        pinned: model.pinned
                        selected: ListView.isCurrentItem
                        onHovered: list.currentIndex = index
                        onActivated: root.paste(list.model.get(index))
                        onPinToggled: root.togglePin(list.model.get(index))
                        onRemoved: root.remove(list.model.get(index))
                    }
                }

                Text {
                    visible: entries.count === 0
                    width: parent.width
                    height: 40
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.query !== "" ? "No matches" : "Nothing copied yet"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.faint
                }
            }
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (!root.open) return;
                box.opacity = 0;
                intro.restart();
                list.currentIndex = 0;
                list.positionViewAtBeginning();
                input.forceActiveFocus();
            }
        }
    }
}
