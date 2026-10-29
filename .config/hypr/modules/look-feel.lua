hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 1,

        col = {
            active_border   = rgba(colors.accent),
            inactive_border = "rgba(ffffff12)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Accent glow around the focused window only.
        shadow = {
            enabled        = true,
            range          = 10,
            render_power   = 3,
            color          = rgba(colors.accent, "4d"),
            color_inactive = "rgba(00000000)",
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = tonumber("0x" .. colors.bg),

        -- Animate while dragging/resizing instead of snapping.
        animate_manual_resizes         = true,
        animate_mouse_windowdragging   = true,
    },
})

-- "Fluid": a fast start with a slight overshoot (from ilyamiro's Serpantinum).
-- The Quickshell bar uses the same curve (Theme.qml), so everything moves alike.
hl.curve("fluid", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "global",              enabled = true, speed = 5, bezier = "fluid" })
hl.animation({ leaf = "windows",             enabled = true, speed = 5, bezier = "fluid", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 5, bezier = "fluid", style = "popin 80%" })
hl.animation({ leaf = "layers",              enabled = true, speed = 5, bezier = "fluid", style = "fade" })
hl.animation({ leaf = "fade",                enabled = true, speed = 5, bezier = "fluid" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 5, bezier = "fluid", style = "slide" })
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 5, bezier = "fluid", style = "fade" })
