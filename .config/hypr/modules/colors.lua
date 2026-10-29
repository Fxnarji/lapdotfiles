-- Mono palette from the design handoff, shared by the other modules.
colors = {
    bg      = "111111",
    surface = "171717",
    raised  = "1c1c1c",
    line    = "262626",
    faint   = "5c5c5c",
    dim     = "8a8a8a",
    soft    = "bdbdbd",
    fg      = "efefef",

    -- The single highlight color. Replaced by the wallpaper-derived one below.
    accent  = "f2545b",
}

function rgba(hex, alpha)
    return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

-- Wallpaper-derived accent from matugen (falls back to the handoff red above).
pcall(require, "modules.accent")
