-- Run the current file in a terminal split at the bottom (<leader>r).
-- <leader>R asks for arguments first and remembers them per file.
-- Saves first, runs from the file's directory, and reuses the same split.
-- When the program ends the output stays; q closes the split.
local M = {}

-- Interpreter per filetype; anything else falls back to the file's shebang.
local runners = {
    python = function(file)
        -- Prefer a project virtualenv next to (or above) the file.
        local venv = vim.fs.find(".venv", { path = vim.fs.dirname(file), upward = true, type = "directory" })[1]
        return { venv and (venv .. "/bin/python") or "python3", file }
    end,
    sh = function(file) return { "bash", file } end,
    bash = function(file) return { "bash", file } end,
    zsh = function(file) return { "zsh", file } end,
    fish = function(file) return { "fish", file } end,
    lua = function(file) return { "nvim", "-l", file } end,
    javascript = function(file) return { "node", file } end,
}

local function shebang(file)
    local first = vim.fn.readfile(file, "", 1)[1] or ""
    local interp = first:match("^#!%s*(.+)$")
    if not interp then return nil end
    local cmd = vim.split(vim.trim(interp), "%s+")
    table.insert(cmd, file)
    return cmd
end

local win -- the runner split, reused between runs

function M.run(args)
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("Save the file first", vim.log.levels.WARN)
        return
    end
    if vim.bo.modified then vim.cmd.write() end

    local runner = runners[vim.bo.filetype]
    local cmd = runner and runner(file) or shebang(file)
    if not cmd then
        vim.notify("Don't know how to run " .. (vim.bo.filetype ~= "" and vim.bo.filetype or "this file"),
            vim.log.levels.WARN)
        return
    end

    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
    else
        vim.cmd("botright 12split")
        win = vim.api.nvim_get_current_win()
    end
    local old = vim.api.nvim_get_current_buf()
    vim.cmd.enew()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[old].buftype == "terminal" then vim.api.nvim_buf_delete(old, { force = true }) end

    if args and args ~= "" then
        -- Go through the shell so quoting, $VARS and globs in args work.
        cmd = table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ") .. " " .. args
    end
    vim.fn.jobstart(cmd, { term = true, cwd = vim.fs.dirname(file) })
    vim.bo[buf].bufhidden = "wipe"
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close runner" })
    -- Keep the output on screen when the program ends (instead of the
    -- terminal closing on the next key).
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function() vim.schedule(function() vim.cmd.stopinsert() end) end,
    })
    vim.cmd.startinsert() -- so input() / read work straight away
end

-- Last arguments per file, kept across sessions.
local args_file = vim.fn.stdpath("state") .. "/runner_args.json"

local function load_args()
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(args_file), "\n")) end)
    return ok and type(data) == "table" and data or {}
end

local function save_args(all)
    vim.fn.writefile({ vim.json.encode(all) }, args_file)
end

-- Small floating prompt, prefilled with the last arguments for this file.
function M.run_with_args()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("Save the file first", vim.log.levels.WARN)
        return
    end
    local all = load_args()
    local src_win = vim.api.nvim_get_current_win()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { all[file] or "" })
    local width = math.min(60, vim.o.columns - 4)
    local prompt = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = math.floor((vim.o.lines - 3) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = 1,
        style = "minimal",
        border = "rounded",
        title = " Args: " .. vim.fs.basename(file) .. " ",
        title_pos = "center",
    })
    vim.cmd.startinsert({ bang = true }) -- cursor at end of the old args

    local function close()
        vim.cmd.stopinsert()
        if vim.api.nvim_win_is_valid(prompt) then vim.api.nvim_win_close(prompt, true) end
        if vim.api.nvim_win_is_valid(src_win) then vim.api.nvim_set_current_win(src_win) end
    end
    local function confirm()
        local args = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
        close()
        all[file] = args ~= "" and args or nil
        save_args(all)
        vim.schedule(function() M.run(args) end)
    end
    local opts = { buffer = buf, nowait = true }
    vim.keymap.set({ "i", "n" }, "<CR>", confirm, opts)
    vim.keymap.set("i", "<Esc>", close, opts)
    vim.keymap.set("n", "<Esc>", close, opts)
    vim.keymap.set("n", "q", close, opts)
    vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = function() vim.schedule(close) end })
end

return M
