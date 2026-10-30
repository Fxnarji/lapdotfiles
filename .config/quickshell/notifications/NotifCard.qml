import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification. Used for toasts and in the center.
// Click: run the default action. Right-click or ×: dismiss.
Rectangle {
    id: root

    required property var notif
    property bool hovered: hover.containsMouse || closeArea.containsMouse

    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notif?.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notif?.actions.filter(a => a.identifier !== "default") ?? []
    readonly property string iconSource: notif?.image
        || (notif?.appIcon ? Quickshell.iconPath(notif.appIcon, true) : "")

    // Close after a click; resident notifications (e.g. music players) stay.
    function done(invoked) {
        if (!notif || (invoked && notif.resident)) return;
        notif.dismiss();
    }

    // Time left before a toast leaves, 1 → 0. Negative hides the bar.
    property real remaining: -1

    implicitHeight: content.implicitHeight + 28
    radius: 16
    color: hovered ? Theme.raised : Theme.surface
    border.width: 1
    border.color: critical ? Theme.accent : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            const invoke = mouse.button === Qt.LeftButton && root.defaultAction;
            if (invoke) root.defaultAction.invoke();
            root.done(invoke);
        }
    }

    Row {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        Image {
            id: icon
            visible: status === Image.Ready
            source: root.iconSource
            width: 36
            height: 36
            sourceSize: Qt.size(72, 72)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Column {
            width: parent.width - (icon.visible ? icon.width + parent.spacing : 0)
            spacing: 3

            // app · time                                           ×
            Item {
                width: parent.width
                height: meta.implicitHeight
                Text {
                    id: meta
                    text: [root.notif?.appName, Notifs.ago(root.notif)].filter(s => s).join("  ·  ")
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: root.critical ? Theme.accent : Theme.faint
                }
                Text {
                    anchors.right: parent.right
                    text: "×"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeXl
                    anchors.verticalCenter: meta.verticalCenter
                    color: closeArea.containsMouse ? Theme.text : Theme.faint
                    opacity: root.hovered ? 1 : 0
                    Behavior on opacity { Anim { duration: Theme.fast } }
                    MouseArea {
                        id: closeArea
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        onClicked: root.done(false)
                    }
                }
            }

            Text {
                width: parent.width
                text: root.notif?.summary ?? ""
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.notif?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSm
                lineHeight: 1.15
                color: Theme.dim
            }

            Row {
                visible: root.buttons.length > 0
                topPadding: 6
                spacing: 6
                Repeater {
                    model: root.buttons
                    Rectangle {
                        required property var modelData
                        width: label.implicitWidth + 20
                        height: 26
                        radius: 8
                        color: btn.containsMouse ? Theme.hover : Theme.raised
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        MouseArea {
                            id: btn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { modelData.invoke(); root.done(true); }
                        }
                    }
                }
            }
        }
    }

    // Countdown bar along the bottom edge.
    Rectangle {
        visible: root.remaining >= 0
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 1 }
        width: (root.width - 32) * Math.max(0, root.remaining)
        height: 2
        radius: 1
        color: Theme.accent
    }
}
