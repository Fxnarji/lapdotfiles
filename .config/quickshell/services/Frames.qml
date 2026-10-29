pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Shared, throttled clock for the bar's never-ending animations (equalizer,
// title ticker, battery wave). Driving them from one 24 fps tick instead of
// per-frame animations means the bar redraws at most 24 times a second, not
// at the display's 144 Hz (24 divides 144, so every tick lasts exactly six
// refreshes), and all of them land in the same frame. Slower animations take
// every n-th tick (see FrameClient.fps).
// Runs only while something listens, and stops while a fullscreen window
// covers the bar or the battery is low (< 15%) and unplugged.
Singleton {
    id: root

    readonly property int fps: 24
    property int listeners: 0

    readonly property var battery: UPower.displayDevice
    readonly property bool lowPower: {
        if (!UPower.onBattery || !(battery?.isLaptopBattery ?? false)) return false;
        const p = battery.percentage;
        return (p <= 1 ? p * 100 : p) < 15;
    }
    readonly property bool paused: HyprState.fullscreen || lowPower

    signal tick(real dt)

    Timer {
        interval: Math.round(1000 / root.fps)
        repeat: true
        running: root.listeners > 0 && !root.paused
        onTriggered: root.tick(interval / 1000)
    }
}
