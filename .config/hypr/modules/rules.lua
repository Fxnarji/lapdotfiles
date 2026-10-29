hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|thunar-.*)$" },
    float = true,
})

-- Launcher: blur the whole screen behind it and fade in/out. The panel itself
-- runs its own intro animation inside the layer.
hl.layer_rule({
    name         = "blur-qs-launcher",
    match        = { namespace = "^qs-launcher$" },
    blur         = true,
    ignore_alpha = 0,
    animation    = "fade",
})

-- Wallpaper switcher: same full-screen blur and fade as the launcher.
hl.layer_rule({
    name         = "blur-qs-wallpaper",
    match        = { namespace = "^qs-wallpaper$" },
    blur         = true,
    ignore_alpha = 0,
    animation    = "fade",
})

-- Clipboard history: same full-screen blur and fade as the launcher.
hl.layer_rule({
    name         = "blur-qs-clipboard",
    match        = { namespace = "^qs-clipboard$" },
    blur         = true,
    ignore_alpha = 0,
    animation    = "fade",
})
