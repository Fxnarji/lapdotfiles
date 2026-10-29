import QtQuick
import qs

// Text in the bar's mono font, vertically centered.
Text {
    property bool mono: true

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: Theme.text
    font.family: mono ? Theme.fontMono : Theme.font
    font.pixelSize: mono ? Theme.fontSizeMono : Theme.fontSize
    renderType: Text.NativeRendering

    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
