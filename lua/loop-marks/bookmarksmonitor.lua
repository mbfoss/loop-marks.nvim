local config     = require('loop-marks.config')
local bookmarks  = require('loop-marks.bookmarks')
local loopsigns  = require('loop.signs')
local selector   = require("loop.tools.selector")
local uitools    = require("loop.tools.uitools")

local M          = {}

local _init_done = false


---@type loop.signs.Group
local _sign_group

local _bookmark_sign_name = "bookmark" -- single sign name

---@class loopmarks.BookmarkData
---@field bookmark loopmarks.Bookmark

---@type table<number, loopmarks.BookmarkData>
local _bookmarks_data     = {}

---@param bm loopmarks.Bookmark
---@param wsdir string
local function _format_bookmark(bm, wsdir)
    local file = bm.file
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
    _sign_group.place_file_sign(bm.id, bm.file, bm.line, _bookmark_sign_name)
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
    _sign_group.remove_file_sign(bm.id)
end

local function _on_all_bookmarks_removed(removed)
    _bookmarks_data = {}
    local files = {}
    for _, bm in ipairs(removed) do
        files[bm.file] = true
    end
    for file in pairs(files) do
        _sign_group.remove_file_signs(file)
    end
end

local function _on_bookmark_moved(bm, _old_line)
    local data = _bookmarks_data[bm.id]
    if not data then return end
    -- Neovim already moved the sign → we just re-place if needed (usually not required)
    -- But to be safe / consistent:
    _sign_group.remove_file_sign(bm.id)
    _place_bookmark_sign(bm)
end

-- ──────────────────────────────────────────────────────────────────────────────
--  UI: Quick jump to any bookmark
-- ──────────────────────────────────────────────────────────────────────────────

---@param wsdir string
function M.select_bookmark(wsdir)
    local bms = bookmarks.get_bookmarks()
    if #bms == 0 then
        vim.notify('No bookmarks set')
        return
    end

    local choices = {}
    for _, bm in ipairs(bms) do
        table.insert(choices, {
            label = _format_bookmark(bm, wsdir),
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
    vim.api.nvim_set_hl(0, hl, { link = "Directory" }) -- or "Special", "WarningMsg", etc.

    -- Define single sign
    _sign_group = loopsigns.define_group("bookmarks", { priority = config.current.mark_sign_priority },
        function(file, signs)
            for id, sign in pairs(signs) do
                -- Update bookmark line to match sign
                bookmarks.update_bookmark_line(id, sign.lnum)
            end
        end)

    _sign_group.define_sign(_bookmark_sign_name, config.current.mark_symbol, hl)

    bookmarks.add_tracker({
        on_set         = _on_bookmark_set,
        on_removed     = _on_bookmark_removed,
        on_all_removed = _on_all_bookmarks_removed,
        on_moved       = _on_bookmark_moved,
    })
end

return M
