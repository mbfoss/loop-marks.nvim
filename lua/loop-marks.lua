-- lua/loop/init.lua
local M = {}

-- Dependencies
local config = require("loop-marks.config")

-----------------------------------------------------------
-- Defaults
-----------------------------------------------------------

---@type loop-marks.Config
local DEFAULT_CONFIG = {
    sign_priority = 100,
    mark_symbol = "⚑",
    note_symbol = "✎",
}

-----------------------------------------------------------
-- State
-----------------------------------------------------------

local setup_done = false
local initialized = false

-----------------------------------------------------------
-- Setup (user config only)
-----------------------------------------------------------

---@param opts loop-marks.Config?
function M.setup(opts)
    if vim.fn.has("nvim-0.10") ~= 1 then
        error("loop.nvim requires Neovim >= 0.10")
    end

    config.current = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts or {})
    setup_done = true

    M.init()
end

-----------------------------------------------------------
-- Initialization (runs once)
-----------------------------------------------------------

function M.init()
    if initialized then
        return
    end
    initialized = true

    -- Apply defaults if setup() was never called
    if not setup_done then
        config.current = DEFAULT_CONFIG
    end

    require('loop-marks.bookmarksmonitor').init()
end

return M
