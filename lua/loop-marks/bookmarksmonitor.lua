local config              = require('loop-marks.config')
local bookmarks           = require('loop-marks.bookmarks')
local signsmgr            = require('loop.signsmgr')
local extmarks            = require('loop.extmarks')
local selector            = require("loop.tools.selector")
local wsinfo              = require("loop.wsinfo")
local uitools             = require("loop.tools.uitools")

local M                   = {}

local _init_done          = false

local _sign_group         = "bookmarks"
local _bookmark_sign_name = "bookmark" -- single sign name

---@class loopmarks.BookmarkData
---@field bookmark loopmarks.Bookmark

---@type table<number, loopmarks.BookmarkData>
local _bookmarks_data     = {}

---@param bm loopmarks.Bookmark
local function _format_bookmark(bm)
    local file = bm.file
    local wsdir = wsinfo.get_ws_dir()
    if wsdir then
        file = vim.fs.relpath(wsdir, file) or file
    end

    local parts = {}
    table.insert(parts, file)
    table.insert(parts, ":")
    table.insert(parts, tostring(bm.line))

    if bm.name and bm.name ~= "" then
        table.insert(parts, "  →  " .. bm.name:gsub("\n", " "))
    end

    return table.concat(parts, '')
end

---@param bm loopmarks.Bookmark
local function _place_bookmark_sign(bm)
    signsmgr.place_file_sign(bm.id, bm.file, bm.line, _sign_group, _bookmark_sign_name)
end

-- ──────────────────────────────────────────────────────────────────────────────
--  Event handlers
-- ──────────────────────────────────────────────────────────────────────────────

local function _on_bookmark_set(bm)
    _bookmarks_data[bm.id] = { bookmark = bm }
    _place_bookmark_sign(bm)
end

local function _on_bookmark_removed(bm)
    _bookmarks_data[bm.id] = nil
    extmarks.remove_file_extmark(bm.id, _sign_group)
end

local function _on_all_bookmarks_removed(removed)
    _bookmarks_data = {}
    local files = {}
    for _, bm in ipairs(removed) do
        files[bm.file] = true
    end
    for file in pairs(files) do
        extmarks.remove_file_extmarks(file, _sign_group)
    end
end

local function _on_bookmark_moved(bm, _old_line)
    local data = _bookmarks_data[bm.id]
    if not data then return end
    -- Neovim already moved the sign → we just re-place if needed (usually not required)
    -- But to be safe / consistent:
    signsmgr.remove_file_sign(bm.id, _sign_group)
    _place_bookmark_sign(bm)
end

-- ──────────────────────────────────────────────────────────────────────────────
--  UI: Quick jump to any bookmark
-- ──────────────────────────────────────────────────────────────────────────────

function M.select_bookmark()
    local ws_dir = wsinfo.get_ws_dir()
    if not ws_dir then
        vim.notify('No active workspace')
        return
    end

    local bms = bookmarks.get_bookmarks()
    if #bms == 0 then
        vim.notify('No bookmarks set')
        return
    end

    local choices = {}
    for _, bm in ipairs(bms) do
        table.insert(choices, {
            label = _format_bookmark(bm),
            file  = bm.file,
            line  = bm.line,
            data  = bm,
        })
    end

    table.sort(choices, function(a, b)
        if a.file ~= b.file then return a.file < b.file end
        return a.line < b.line
    end)

    selector.select({
        prompt = "Bookmarks",
        items = choices,
        file_preview = true,
        callback = function(selected)
            if selected and selected.file then
                uitools.smart_open_file(selected.file, selected.line)
            end
        end,
    })
end

-- ──────────────────────────────────────────────────────────────────────────────
--  Init
-- ──────────────────────────────────────────────────────────────────────────────

function M.init()
    if _init_done then return end
    _init_done = true

    assert(config.current)

    -- Highlight group (feel free to change link or define your own)
    local hl = "LoopmarksBookmarksSign"
    vim.api.nvim_set_hl(0, hl, { link = "Todo" }) -- or "Special", "WarningMsg", etc.

    -- Define single sign
    signsmgr.define_sign_group(_sign_group, config.current.mark_sign_priority,
        function(file, signs)
            for id, sign in pairs(signs) do
                assert(sign.group == _sign_group)
                -- Update bookmark line to match sign
                bookmarks.update_bookmark_line(id, sign.lnum)
            end
        end)

    signsmgr.define_sign(
        _sign_group,
        _bookmark_sign_name,
        config.current.mark_symbol,
        hl
    )

    bookmarks.add_tracker({
        on_set         = _on_bookmark_set,
        on_removed     = _on_bookmark_removed,
        on_all_removed = _on_all_bookmarks_removed,
        on_moved       = _on_bookmark_moved,
    })
end

return M
