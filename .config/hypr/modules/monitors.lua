-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1.25,
})

-- Any other monitor plugged in: sensible defaults, placed to the right.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
