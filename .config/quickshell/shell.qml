//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "bar"
import "clipboard"
import "launcher"
import "notifications"
import "popouts"
import "wallpaper"

ShellRoot {
    // Quickshell only learns about windows from events; fetch the current state once.
    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    // One bar per monitor.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher {}

    Popups {}
    Center {}
    Popouts {}
    OsdWindow {}
    Switcher {}
    Clipboard {}
}
