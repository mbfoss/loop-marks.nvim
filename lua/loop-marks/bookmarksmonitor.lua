local config          = require('loop-marks.config')
local bookmarks       = require('loop-marks.bookmarks')
local signsmgr        = require('loop.signsmgr')
local selector        = require("loop.tools.selector")
local wsinfo          = require("loop.wsinfo")
local uitools         = require("loop.tools.uitools")

local M               = {}

local _init_done      = false

local _sign_group     = "bookmarks"
local _bookmark_sign_name      = "bookmark" -- single sign name
local _note_sign_name      = "note" -- single sign name

---@class loopmarks.BookmarkData
---@field bookmark loopmarks.Bookmark
local _bookmarks_data = {}

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

    if bm.note and bm.note ~= "" then
        table.insert(parts, "  →  " .. bm.note:gsub("\n", " "))
    end

    return table.concat(parts, '')
end

---@param bm loopmarks.Bookmark
local function _place_bookmark_sign(bm)
    local sign = (bm.note and bm.note ~= "") and _note_sign_name or _bookmark_sign_name
    signsmgr.place_file_sign(bm.id, bm.file, bm.line, _sign_group, sign)
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
    signsmgr.remove_file_sign(bm.id, _sign_group)
end

local function _on_all_bookmarks_removed(removed)
    _bookmarks_data = {}
    local files = {}
    for _, bm in ipairs(removed) do
        files[bm.file] = true
    end
    for file in pairs(files) do
        signsmgr.remove_file_signs(file, _sign_group)
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
--  Sync line changes on save (very useful for bookmarks too)
-- ──────────────────────────────────────────────────────────────────────────────

local function _enable_bookmark_sync_on_save()
    local group = vim.api.nvim_create_augroup("LoopBookmarkSyncOnSave", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        callback = function(ev)
            local bufnr = ev.buf
            if not vim.api.nvim_buf_is_valid(bufnr) then return end
            if vim.bo[bufnr].buftype ~= "" then return end

            local file = vim.api.nvim_buf_get_name(bufnr)
            if file == "" then return end
            file = vim.fn.fnamemodify(file, ":p")

            local signs_by_id = signsmgr.get_file_signs_by_id(file)
            for id, sign in pairs(signs_by_id) do
                if sign.group == _sign_group then
                    bookmarks.update_bookmark_line(id, sign.lnum)
                end
            end
        end,
    })
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
    local hl = "LoopBookmarksSign"
    vim.api.nvim_set_hl(0, hl, { link = "Todo" }) -- or "Special", "WarningMsg", etc.

    -- Define single sign
    signsmgr.define_sign_group(_sign_group, config.current.sign_priority or 100)

    signsmgr.define_sign(
        _sign_group,
        _bookmark_sign_name,
        config.current.mark_symbol,
        hl
    )

    signsmgr.define_sign(
        _sign_group,
        _note_sign_name,
        config.current.note_symbol,
        hl
    )

    _enable_bookmark_sync_on_save()

    bookmarks.add_tracker({
        on_set         = _on_bookmark_set,
        on_removed     = _on_bookmark_removed,
        on_all_removed = _on_all_bookmarks_removed,
        on_moved       = _on_bookmark_moved,
    })
end

return M
