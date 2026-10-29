import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// App launcher with a calculator. Toggled by Hyprland (quickshell:launcher)
// or `qs ipc call launcher toggle`. The box grows and shrinks with the results.
Scope {
    id: root

    property bool open: false
    property string query: ""

    readonly property int rowHeight: 34
    readonly property int maxRows: 10

    function toggle() { open ? close() : show(); }
    function show() { query = ""; intro = true; introTimer.restart(); open = true; }

    // True for the first moments after opening, so rows only cascade in on the intro.
    property bool intro: false
    Timer { id: introTimer; interval: 900; onTriggered: root.intro = false }
    function close() { open = false; }

    GlobalShortcut {
        name: "launcher"
        description: "Toggle the app launcher"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        // Open with a query already typed, e.g. `qs ipc call launcher search 2*7`.
        function search(q: string): void { root.show(); root.query = q; }
    }

    // ---- search -----------------------------------------------------------

    // Arithmetic only: digits, operators, parentheses. `^` is power.
    readonly property string calcResult: {
        const q = query.trim();
        if (!/^[0-9+\-*/%^().,\s]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q)) return "";
        try {
            const v = Function(`"use strict"; return (${q.replace(/,/g, ".").replace(/\^/g, "**")});`)();
            if (typeof v !== "number" || !isFinite(v)) return "";
            return String(Math.round(v * 1e10) / 1e10);
        } catch (e) {
            return "";
        }
    }

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // Higher is better; 0 means no match.
    function score(app, q) {
        const name = app.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length / 100;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        const extra = [app.genericName, ...(app.keywords ?? [])].join(" ").toLowerCase();
        if (extra.includes(q)) return 40;
        // Letters in order, e.g. "ffx" -> Firefox.
        let i = 0;
        for (const c of name) if (c === q[i]) i++;
        return i === q.length ? 20 : 0;
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        let list = q === "" ? apps.map(a => ({ app: a }))
            : apps.map(a => ({ app: a, s: score(a, q) }))
                  .filter(r => r.s > 0)
                  .sort((x, y) => y.s - x.s);
        if (calcResult !== "") list = [{ calc: calcResult }, ...list];
        return list;
    }

    function activate(index) {
        const r = results[index];
        if (!r) return;
        if (r.calc !== undefined) Quickshell.execDetached(["wl-copy", r.calc]);
        else r.app.execute();
        close();
    }

    // ---- window -----------------------------------------------------------

    PanelWindow {
        id: win

        // Hyprland fades the layer (and its blur) in and out; see rules.lua.
        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
                ?? Quickshell.screens[0]

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Faint dim over the whole screen; Hyprland blurs everything behind it.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.25)
        }

        // Click outside the box to close.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        RectangularShadow {
            anchors.fill: box
            radius: box.radius
            blur: 40
            spread: 0
            color: Qt.alpha(Theme.accent, 0.3)
            opacity: box.opacity
            scale: box.scale
            transform: Translate { y: box.lift }
        }

        Rectangle {
            id: box

            readonly property int visibleRows: Math.min(root.results.length, root.maxRows)

            width: 600
            height: search.height + (visibleRows > 0 ? list.anchors.topMargin + visibleRows * root.rowHeight : 0) + 2 * padding
            Behavior on height { Anim {} }

            readonly property int padding: 10

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.22)

            color: Theme.surface
            radius: 20
            border.width: 2
            border.color: Theme.accent
            clip: true

            // Intro: rises a little, grows from 92% and fades in.
            property real lift: 0
            transform: Translate { y: box.lift }

            ParallelAnimation {
                id: introAnim
                NumberAnimation { target: box; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
                Anim { target: box; property: "scale"; from: 0.92; to: 1; duration: 850 }
                Anim { target: box; property: "lift"; from: 24; to: 0; duration: 850 }
            }

            // Swallow clicks so they don't reach the close area behind.
            MouseArea { anchors.fill: parent }

            Item {
                id: search
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: box.padding }
                height: 44

                TextInput {
                    id: input
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.text
                    selectionColor: Qt.alpha(Theme.accent, 0.35)
                    cursorDelegate: Item {}
                    text: root.query
                    onTextEdited: { root.query = text; list.currentIndex = 0; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search apps or calculate…"
                        font: input.font
                        color: Theme.faint
                        visible: input.text === ""
                    }

                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.activate(list.currentIndex)
                    Keys.onEnterPressed: root.activate(list.currentIndex)
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onTabPressed: list.incrementCurrentIndex()
                    Keys.onBacktabPressed: list.decrementCurrentIndex()
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Theme.line
                    opacity: box.visibleRows > 0 ? 1 : 0
                    Behavior on opacity { Anim { duration: Theme.fast } }
                }
            }

            ListView {
                id: list
                anchors { top: search.bottom; left: parent.left; right: parent.right; margins: box.padding; topMargin: 6 }
                height: box.visibleRows * root.rowHeight
                model: root.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                keyNavigationWraps: true

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem
                    readonly property bool isCalc: modelData.calc !== undefined

                    width: list.width
                    height: root.rowHeight

                    // Cascade in, one row after another, during the intro.
                    property real lift: 0
                    transform: Translate { y: row.lift }
                    Component.onCompleted: if (root.intro) rowIntro.start()
                    SequentialAnimation {
                        id: rowIntro
                        PropertyAction { target: row; property: "opacity"; value: 0 }
                        PropertyAction { target: row; property: "lift"; value: 8 }
                        PauseAnimation { duration: 140 + row.index * 30 }
                        ParallelAnimation {
                            NumberAnimation { target: row; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                            Anim { target: row; property: "lift"; to: 0; duration: 600 }
                        }
                    }
                    radius: 8
                    color: selected ? Theme.selected
                         : index % 2 === 1 ? Theme.stripe
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    Text {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                        text: row.isCalc ? "= " + row.modelData.calc : row.modelData.app.name
                        elide: Text.ElideRight
                        font.family: row.isCalc ? Theme.fontMono : Theme.font
                        font.pixelSize: 14
                        font.weight: row.isCalc || row.selected ? Font.DemiBold : Font.Medium
                        color: row.isCalc ? Theme.accent : Theme.text
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                        visible: row.isCalc
                        text: "enter to copy"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.faint
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: root.activate(row.index)
                    }
                }
            }
        }

        Connections {
            target: root
            function onOpenChanged() {
                if (root.open) {
                    box.opacity = 0;
                    introAnim.restart();
                    list.currentIndex = 0;
                    list.positionViewAtBeginning();
                    input.forceActiveFocus();
                }
            }
        }
    }
}
