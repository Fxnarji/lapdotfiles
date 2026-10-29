hl.config({
    input = {
        kb_layout    = "de,us",
        kb_options   = "grp:alt_shift_toggle", -- Alt+Shift switches DE <-> US
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
