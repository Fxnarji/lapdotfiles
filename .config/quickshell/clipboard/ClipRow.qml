import QtQuick
import qs

// One clipboard entry: an icon for what it looks like (link, colour, code,
// text; a pin when pinned), the text on one line, and pin / remove buttons
// on the selected row.
Rectangle {
    id: root

    property string text
    property bool pinned: false
    property bool selected: false
    signal activated()
    signal hovered()
    signal pinToggled()
    signal removed()

    readonly property string flat: text.split(/\s+/).filter(w => w !== "").join(" ")
    readonly property string kind: {
        const s = text.trim();
        if (/^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)) return "color";
        if (/^(https?:\/\/|www\.)\S+$/i.test(s)) return "url";
        if (/[{};]|=>|\$\(|&&|\|\||^(sudo|git|cd|ls|cat|echo|hyprctl|pacman|yay|systemctl|ssh|scp|cp|mv|rm|mkdir|curl|wget|npm|python3?|qs)\s/.test(s)) return "code";
        return "text";
    }

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    width: ListView.view?.width ?? 0
    height: 38
    radius: 10
    color: selected ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }

    // Icon column
    Item {
        id: lead
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 16
        height: 16

        Rectangle {
            visible: root.kind === "color" && !root.pinned
            anchors.fill: parent
            radius: 5
            color: visible ? root.text.trim() : "transparent"
        }
        Text {
            visible: root.kind !== "color" || root.pinned
            anchors.centerIn: parent
            text: root.pinned ? "\uf08d" : root.selected ? "\uf0c5"
                : root.kind === "url" ? "\uf0c1" : root.kind === "code" ? "\uf121" : "\uf0f6"
            font.family: Theme.fontMono
            font.pixelSize: root.pinned ? Theme.fontSizeSm : Theme.fontSizeMd
            color: root.pinned || root.selected ? Theme.accent : Theme.dim
        }
    }

    Text {
        anchors { left: lead.right; leftMargin: 12; right: buttons.visible ? buttons.left : parent.right
                  rightMargin: 10; verticalCenter: parent.verticalCenter }
        readonly property bool mono: root.kind === "code" || root.kind === "color"
        textFormat: root.kind === "url" ? Text.StyledText : Text.PlainText
        // Links: the host in grey, the path in full colour.
        text: {
            if (root.kind !== "url") return root.flat;
            const s = root.flat.replace(/^https?:\/\//i, "");
            const cut = s.indexOf("/") + 1;
            if (cut <= 0) return root.esc(s);
            return `<font color="${Theme.dim}">${root.esc(s.slice(0, cut))}</font>${root.esc(s.slice(cut))}`;
        }
        elide: Text.ElideRight
        font.family: mono ? Theme.fontMono : Theme.font
        font.pixelSize: mono ? Theme.fontSizeSm : Theme.fontSize
        color: Theme.text
    }

    Row {
        id: buttons
        visible: root.selected
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 4
        IconButton { glyph: "\uf08d"; active: root.pinned; onClicked: root.pinToggled() }
        IconButton { glyph: "\uf1f8"; onClicked: root.removed() }
    }

    component IconButton: Rectangle {
        id: button
        property string glyph
        property bool active: false
        signal clicked()
        width: 30
        height: 30
        radius: 9
        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize
            color: button.active ? Theme.accent : area.containsMouse ? Theme.text : Theme.dim
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
