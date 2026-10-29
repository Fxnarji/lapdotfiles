import QtQuick

// NumberAnimation preset with the shell's "fluid" curve. Use in Behaviors:
//   Behavior on width { Anim {} }
NumberAnimation {
    duration: Theme.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curve
}
