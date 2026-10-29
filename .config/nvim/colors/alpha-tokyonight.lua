-- Full tokyonight-moon (UI and code colors), but with kitty's translucent background showing through.
-- Options are passed to load() only, so plain :colorscheme tokyonight stays opaque.
require("tokyonight").load({
    style = "moon",
    transparent = true,
    styles = { sidebars = "transparent", floats = "transparent" },
})
vim.g.colors_name = "alpha-tokyonight"
