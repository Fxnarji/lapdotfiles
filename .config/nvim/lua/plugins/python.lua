-- Python: tree-sitter highlighting, pyright LSP, blink.cmp completion.
local languages = { "python", "lua", "bash", "toml", "json", "yaml", "markdown" }

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").install(languages)
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "python", "lua", "sh", "bash", "toml", "json", "yaml", "markdown" },
                callback = function() pcall(vim.treesitter.start) end,
            })
        end,
    },

    {
        "saghen/blink.cmp",
        version = "1.*",
        lazy = false,
        opts = {
            -- Enter accepts, Tab / Shift-Tab move through the list, Ctrl-Space opens it.
            keymap = {
                preset = "enter",
                ["<Tab>"]   = { "select_next", "fallback" },
                ["<S-Tab>"] = { "select_prev", "fallback" },
            },
            completion = {
                menu = { border = "rounded" },
                documentation = { auto_show = true, window = { border = "rounded" } },
            },
            signature = { enabled = true, window = { border = "rounded" } },
            fuzzy = { implementation = "prefer_rust_with_warning" },
        },
    },

    {
        "neovim/nvim-lspconfig",
        lazy = false,
        dependencies = { "saghen/blink.cmp" },
        config = function()
            vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
            vim.lsp.enable("pyright")

            vim.diagnostic.config({
                virtual_text = { prefix = "●" },
                float = { border = "rounded" },
                severity_sort = true,
            })

            -- Built in: K hover, grn rename, gra code action, grr references.
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
        end,
    },
}
