import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services

// Audio popout (design 7a): the active output as a card with its volume, the
// other outputs in grey below it, then the mic and a volume slider per app.
// Click another output or input to switch to it; click an app to mute it.
// The speaker button in the header mutes everything.
PopoutPanel {
    id: root

    width: 360

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Volume and mute are only live for tracked nodes.
    PwObjectTracker { objects: root.open ? [...root.sinks, ...root.sources, ...root.streams] : [] }

    // Short name: "Speaker" rather than "Ryzen HD Audio Controller Speaker".
    function label(n) {
        return n?.properties?.["device.profile.description"] || n?.description || n?.nickname || n?.name || "";
    }
    function pct(n) { return n?.audio?.muted ? "mute" : Math.round((n?.audio?.volume ?? 0) * 100) + "%"; }
    function setVolume(n, v) { if (n?.audio) { n.audio.muted = false; n.audio.volume = v; } }

    function outputGlyph(n) {
        const name = n?.name ?? "";
        if (name.startsWith("bluez")) return "";
        if (name.includes("hdmi") || label(n).includes("HDMI")) return "";
        return "";
    }
    function appName(n) { return n.properties["application.name"] || label(n); }
    function appGlyph(n) {
        const a = (appName(n) + " " + (n.properties["application.process.binary"] ?? "")).toLowerCase();
        if (a.includes("firefox")) return "";
        if (a.includes("chrom")) return "";
        if (a.includes("spotify")) return "";
        if (a.includes("discord")) return "";
        if (a.includes("steam")) return "";
        if (a.includes("mpv") || a.includes("vlc")) return "";
        return "";
    }

    PanelHeader {
        title: "Audio"
        // Mute everything (the default output).
        Rectangle {
            width: 30
            height: 30
            radius: 9
            color: muteAll.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Text {
                anchors.centerIn: parent
                text: root.sink?.audio?.muted ? "" : ""
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: root.sink?.audio?.muted ? Theme.accent : Theme.text
            }
            MouseArea {
                id: muteAll
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }

    // Active output
    Rectangle {
        visible: root.sink !== null
        width: parent.width
        height: card.implicitHeight + 24
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)

        Column {
            id: card
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 14

            Item {
                width: parent.width
                height: 20
                Glyph { id: outIcon; text: root.outputGlyph(root.sink); color: Theme.accent }
                Text {
                    anchors { left: outIcon.right; leftMargin: 12; right: outCheck.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: root.label(root.sink)
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Glyph { id: outCheck; anchors.left: undefined; anchors.right: parent.right; text: ""; size: 12; color: Theme.accent }
            }

            VolumeLine {
                node: root.sink
                glyph: ""
            }
        }
    }

    // Other outputs
    Column {
        width: parent.width
        spacing: 1
        Repeater {
            model: ScriptModel { values: root.sinks.filter(n => n !== root.sink) }
            PanelRow {
                required property var modelData
                glyph: root.outputGlyph(modelData)
                text: root.label(modelData)
                textColor: Theme.dim
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    Divider { text: "Input"; visible: root.sources.length > 0 }

    Column {
        width: parent.width
        spacing: 1

        // Active mic, highlighted, with its volume.
        Rectangle {
            visible: root.source !== null
            width: parent.width
            height: mic.implicitHeight + 18
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)

            Column {
                id: mic
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                spacing: 12
                Item {
                    width: parent.width
                    height: 20
                    Glyph { id: micIcon; text: ""; color: Theme.accent }
                    Text {
                        anchors { left: micIcon.right; leftMargin: 12; right: micCheck.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: root.label(root.source)
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 14
                        color: Theme.text
                    }
                    Glyph { id: micCheck; anchors.left: undefined; anchors.right: parent.right; text: ""; size: 12; color: Theme.accent }
                }
                VolumeLine { node: root.source }
            }
        }

        Repeater {
            model: ScriptModel { values: root.sources.filter(n => n !== root.source) }
            PanelRow {
                required property var modelData
                glyph: ""
                text: root.label(modelData)
                textColor: Theme.dim
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    Divider { text: "Apps" }

    Column {
        width: parent.width

        Repeater {
            model: ScriptModel { values: root.streams }
            Column {
                id: app
                required property var modelData
                readonly property bool muted: modelData.audio?.muted ?? false
                width: parent.width
                topPadding: 8
                bottomPadding: 8
                spacing: 8

                Item {
                    x: 10
                    width: parent.width - 20
                    height: 18
                    Glyph { id: appIcon; text: root.appGlyph(app.modelData); color: app.muted ? Theme.faint : Theme.dim }
                    Text {
                        anchors { left: appIcon.right; leftMargin: 12; right: appPct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: root.appName(app.modelData)
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: app.muted ? Theme.dim : Theme.text
                    }
                    Text {
                        id: appPct
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: root.pct(app.modelData)
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: app.muted ? Theme.faint : Theme.dim
                    }
                    // Click the name to mute / unmute this app.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (app.modelData.audio) app.modelData.audio.muted = !app.muted
                    }
                }

                Slider {
                    x: 38
                    width: parent.width - 48
                    value: app.modelData.audio?.volume ?? 0
                    muted: app.muted
                    onMoved: v => root.setVolume(app.modelData, v)
                }
            }
        }

        Text {
            visible: root.streams.length === 0
            width: parent.width
            height: 34
            leftPadding: 10
            verticalAlignment: Text.AlignVCenter
            text: "Nothing playing"
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.faint
        }
    }

    // 16px icon column, vertically centred in its row.
    component Glyph: Text {
        property int size: 14
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 16
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontMono
        font.pixelSize: size
    }

    // [icon] ───────●──── 64%   (no icon: indented under the row's label)
    component VolumeLine: Item {
        id: line
        property var node
        property string glyph
        width: parent.width
        height: 16

        Glyph { id: volIcon; visible: line.glyph !== ""; text: line.glyph; size: 13; color: Theme.dim }
        Slider {
            anchors { left: parent.left; leftMargin: 28; right: volPct.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            value: line.node?.audio?.volume ?? 0
            muted: line.node?.audio?.muted ?? false
            onMoved: v => root.setVolume(line.node, v)
        }
        Text {
            id: volPct
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 34
            horizontalAlignment: Text.AlignRight
            text: root.pct(line.node)
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.dim
        }
    }
}
