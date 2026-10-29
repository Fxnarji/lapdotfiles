local map = vim.keymap.set

map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "File tree" })
map("n", "<S-l>",     "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<S-h>",     "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
map("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close buffer" })
map("n", "<Esc>",     "<cmd>nohlsearch<cr>")

-- Run the current file; <leader>R prompts for arguments (remembered per file)
map("n", "<leader>r", function() require("config.runner").run() end, { desc = "Run file" })
map("n", "<leader>R", function() require("config.runner").run_with_args() end, { desc = "Run file with args" })
