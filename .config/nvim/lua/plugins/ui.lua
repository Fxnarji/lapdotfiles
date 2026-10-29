-- Colors live in lua/theme.lua; colors/*.lua expose them as colorschemes (:colorscheme <Tab>).
-- The last scheme picked is remembered across restarts.
local p = require("theme").p
local saved = vim.fn.stdpath("state") .. "/colorscheme"

return {
    {
        "nvim-mini/mini.base16",
        dependencies = { "folke/tokyonight.nvim" },
        lazy = false,
        priority = 1000,
        config = function()
            local f = io.open(saved, "r")
            local name = f and f:read("*l") or "accent"
            if f then f:close() end
            if not pcall(vim.cmd.colorscheme, name) then vim.cmd.colorscheme("accent") end

            vim.api.nvim_create_autocmd("ColorScheme", {
                callback = function(ev)
                    local out = io.open(saved, "w")
                    if out then out:write(ev.match) out:close() end
                end,
            })
        end,
    },


    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = function()
            local mode = function(bg)
                return {
                    a = { fg = p.bg, bg = bg, gui = "bold" },
                    b = { fg = p.fg, bg = p.line },
                    c = { fg = p.dim, bg = "NONE" },
                }
            end
            return {
                options = {
                    theme = {
                        normal   = mode(p.accent),
                        insert   = mode(p.fg),
                        visual   = mode(p.soft),
                        replace  = mode(p.accent),
                        command  = mode(p.soft),
                        inactive = mode(p.line),
                    },
                    section_separators   = { left = "\238\130\180", right = "\238\130\182" },
                    component_separators = "",
                    globalstatus = true,
                },
                sections = {
                    lualine_a = { { "mode", separator = { left = "\238\130\182" }, right_padding = 2 } },
                    lualine_b = { "branch" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "filetype", "encoding" },
                    lualine_y = {},
                    lualine_z = { { "location", separator = { right = "\238\130\180" }, left_padding = 2 } },
                },
            }
        end,
    },

    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        cmd = "Neotree",
        dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
        opts = {
            window = { width = 30 },
            filesystem = { follow_current_file = { enabled = true } },
            default_component_configs = { indent = { with_markers = false } },
        },
    },

    {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            options = {
                indicator = { style = "none" },   -- current buffer = white bold name
                separator_style = { "", "" },
                show_buffer_close_icons = false,
                show_close_icon = false,
                offsets = { { filetype = "neo-tree", text = "", padding = 0 } },
            },
            highlights = {
                fill                = { bg = "NONE" },
                background          = { fg = p.dim, bg = "NONE" },
                buffer_visible      = { fg = p.dim, bg = "NONE" },
                buffer_selected     = { fg = p.fg, bg = "NONE", bold = true, italic = false },
                modified            = { fg = p.accent, bg = "NONE" },
                modified_selected   = { fg = p.accent, bg = "NONE" },
                separator           = { fg = "NONE", bg = "NONE" },
            },
        },
    },
}
