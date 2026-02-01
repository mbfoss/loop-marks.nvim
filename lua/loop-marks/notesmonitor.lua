local config      = require('loop-marks.config')
local notes       = require('loop-marks.notes')
local extmarks    = require('loop.extmarks')
local selector    = require("loop.tools.selector")
local uitools     = require("loop.tools.uitools")

local M           = {}

local _init_done  = false

local _extmarks_group

---@class loopmarks.NoteData
---@field note loopmarks.Note

---@type table<number, loopmarks.NoteData>
local _notes_data = {}

---@param bm loopmarks.Note
---@param wsdir string
local function _format_note(bm, wsdir)
    local file = bm.file
    if wsdir then
        file = vim.fs.relpath(wsdir, file) or file
    end

    local parts = {}
    table.insert(parts, file)
    table.insert(parts, ":")
    table.insert(parts, tostring(bm.line))
    table.insert(parts, "  →  " .. bm.text:gsub("\n", " "))
    return table.concat(parts, '')
end

---@param bm loopmarks.Note
local function _place_note_sign(bm)
    local text = (" %s %s"):format(config.current.note_symbol, bm.text or "Note")
    _extmarks_group.place_file_extmark(bm.id, bm.file, bm.line, 0, {
        virt_text     = { { text, "Todo" } },
        virt_text_pos = "eol",
        hl_mode       = "combine",
    })
end

-- ──────────────────────────────────────────────────────────────────────────────
--  Event handlers
-- ──────────────────────────────────────────────────────────────────────────────

local function _on_note_set(bm)
    _notes_data[bm.id] = { note = bm }
    _place_note_sign(bm)
end

local function _on_note_removed(bm)
    _notes_data[bm.id] = nil
    _extmarks_group.remove_extmark(bm.id)
end

local function _on_all_notes_removed(removed)
    _notes_data = {}
    local files = {}
    for _, bm in ipairs(removed) do
        files[bm.file] = true
    end
    for file in pairs(files) do
        _extmarks_group.remove_file_extmarks(file)
    end
end

local function _on_note_moved(bm, _old_line)
    local data = _notes_data[bm.id]
    if not data then return end
    -- Neovim already moved the sign → we just re-place if needed (usually not required)
    -- But to be safe / consistent:
    _extmarks_group.remove_extmark(bm.id)
    _place_note_sign(bm)
end

-- ──────────────────────────────────────────────────────────────────────────────
--  UI: Quick jump to any note
-- ──────────────────────────────────────────────────────────────────────────────

---@param wsdir string
function M.select_note(wsdir)
    local bms = notes.get_notes()
    if #bms == 0 then
        vim.notify('No notes set')
        return
    end

    local choices = {}
    for _, bm in ipairs(bms) do
        table.insert(choices, {
            label = _format_note(bm, wsdir),
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
        prompt = "Notes",
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

    _extmarks_group =
        extmarks.define_group("Notes", { priority = config.current.note_sign_priority },
            function(file, marks)
                for id, mark in pairs(marks) do
                    -- Update note line to match sign
                    notes.update_note_line(id, mark.lnum)
                end
            end)

    -- Highlight group (feel free to change link or define your own)
    local hl = "LoopmarksNotesSign"
    vim.api.nvim_set_hl(0, hl, { link = "Todo" }) -- or "Special", "WarningMsg", etc.

    notes.add_tracker({
        on_set         = _on_note_set,
        on_removed     = _on_note_removed,
        on_all_removed = _on_all_notes_removed,
        on_moved       = _on_note_moved,
    })
end

return M
