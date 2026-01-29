local M = {}

local Trackers = require("loop.tools.Trackers")
local uitools = require("loop.tools.uitools")
local floatwin = require("loop.tools.floatwin")
local wsinfo = require('loop.wsinfo')

---@class loopmarks.Note
---@field id number
---@field file string
---@field line integer
---@field column integer|nil
---@field text string

---@class loopmarks.notes.Tracker
---@field on_set fun(nd:loopmarks.Note)|nil
---@field on_removed fun(nd:loopmarks.Note)|nil
---@field on_all_removed fun(bms:loopmarks.Note[])|nil
---@field on_moved fun(nd:loopmarks.Note,old_line:number)|nil

local _last_note_id = 1000

---@type table<string,table<number,number>> -- file --> line --> id
local _source_notes = {}

---@type table<number,loopmarks.Note>
local _by_id = {} -- notes by unique id

---@type loop.tools.Trackers<loopmarks.notes.Tracker>
local _trackers = Trackers:new()

---@param callbacks loopmarks.notes.Tracker
---@param no_snapshot boolean?
---@return loop.TrackerRef
function M.add_tracker(callbacks, no_snapshot)
    local tracker_ref = _trackers:add_tracker(callbacks)
    if not no_snapshot then
        --initial snapshot
        ---@type loopmarks.Note[]
        local current = vim.tbl_values(_by_id)
        if callbacks.on_set then
            for _, nd in ipairs(current) do
                callbacks.on_set(nd)
            end
        end
    end
    return tracker_ref
end

local function _norm(file)
    if not file or file == "" then return file end
    return vim.fn.fnamemodify(file, ":p")
end

--- Check if a file has a note on a specific line.
---@param file string File path
---@param line integer Line number
---@return number|nil
---@return loopmarks.Note|nil
local function _get_source_note(file, line)
    local lines = _source_notes[file]
    if not lines then return nil, nil end
    local id = lines[line]
    if not id then return nil, nil end
    return id, _by_id[id]
end

--- Check if a file has a note on a specific line.
---@param file string File path
---@param line integer Line number
---@return boolean has_note True if a note exists on that line
local function _have_source_note(file, line)
    return _get_source_note(file, line) ~= nil
end

--- Remove a single note.
---@param file string File path
---@param line integer Line number
---@return boolean removed True if a note was removed
local function _remove_source_note(file, line)
    local lines = _source_notes[file]
    if not lines then return false end
    local id = lines[line]
    if not id then return false end
    local nd = _by_id[id]
    if nd then
        lines[line] = nil
        _by_id[id] = nil
        _trackers:invoke("on_removed", nd)
    end
    return true
end

---@param file string File path
local function _clear_file_notes(file)
    local lines = _source_notes[file]
    local removed = {}
    if not lines then return end
    for _, id in pairs(lines) do
        local nd = _by_id[id]
        if nd then
            table.insert(removed, nd)
            _by_id[id] = nil
        end
    end
    _source_notes[file] = nil
    for _, nd in pairs(removed) do
        _trackers:invoke("on_removed", nd)
    end
end

local function _clear_notes()
    ---@type loopmarks.Note[]
    local removed = vim.tbl_values(_by_id)
    _by_id = {}
    _source_notes = {}
    _trackers:invoke("on_all_removed", removed)
end

--- Add a new note.
---@param file string File path
---@param line integer Line number
---@param text string Optional text
---@return boolean added
local function _set_source_note(file, line, text)
    if _have_source_note(file, line) then
        return false
    end
    local id = _last_note_id + 1
    _last_note_id = id
    ---@type loopmarks.Note
    local nd = {
        id = id,
        file = file,
        line = line,
        text = text
    }
    _by_id[id] = nd
    _source_notes[file] = _source_notes[file] or {}
    local lines = _source_notes[file]
    lines[line] = id
    _trackers:invoke("on_set", nd)
    return true
end

---@param file string
---@param lnum number
function M.remove_note(file, lnum)
    file = _norm(file)
    _remove_source_note(file, lnum)
end

---@param file string
---@param lnum number
---@param message string
function M.set_note(file, lnum, message)
    if type(message) == "string" and #message > 0 then
        file = _norm(file)
        _remove_source_note(file, lnum)
        _set_source_note(file, lnum, message)
    end
end

---@param file string
---@param lnum number
---@return string? mesage
function M.get_note(file, lnum)
    local lines = _source_notes[file]
    if not lines then return end
    local id = lines[lnum]
    if not id then return end
    local nd = _by_id[id]
    return nd and nd.text
end

---@param id number
---@param newline number
---@return boolean
function M.update_note_line(id, newline)
    local nd = _by_id[id]
    if not nd or nd.line == newline then
        return false
    end
    local old_line = nd.line
    local file = nd.file
    local lines = _source_notes[file]
    if lines then
        lines[old_line] = nil
        lines[newline] = id
    end
    nd.line = newline
    _trackers:invoke("on_moved", nd, old_line)
    return true
end

---@param file string
function M.clear_file_notes(file)
    _clear_file_notes(_norm(file))
end

--- clear all notes.
function M.clear_all_notes()
    _clear_notes()
end

---@return loopmarks.Note[]
function M.get_notes()
    ---@type loopmarks.Note[]
    local bms = {}
    for _, nd in pairs(_by_id) do
        table.insert(bms, nd)
    end
    return bms
end

---@param notes loopmarks.Note[]
local function _set_notes(notes)
    _clear_notes()
    table.sort(notes, function(a, b)
        if a.file ~= b.file then return a.file < b.file end
        return a.line < b.line
    end)
    for _, nd in ipairs(notes) do
        local file = vim.fn.fnamemodify(nd.file, ":p")
        _set_source_note(file,
            nd.line,
            nd.text
        )
    end
    return true, nil
end
---@return boolean
function M.have_notes()
    return next(_by_id) ~= nil
end

---@param handler fun(nd:loopmarks.Note)
function M.for_each(handler)
    for _, nd in pairs(_by_id) do
        handler(nd)
    end
end

---@param command nil
---| "set"
---| "text"
---| "remove"
---| "clear_file"
---| "clear_all"
function M.notes_command(command)
    local ws_dir = wsinfo.get_ws_dir()
    if not ws_dir then
        vim.notify('No active workspace')
        return
    end
    command = command and command:match("^%s*(.-)%s*$") or ""
    if command == "" or command == "set" then
        local file, line = uitools.get_current_file_and_line()
        if file and line then
            local note = M.get_note(file, line)
            floatwin.input_at_cursor({ prompt = "Note", default_text = note }, function(message)
                if message and message ~= "" then
                    M.set_note(file, line, message)
                end
            end)
        end
    elseif command == "remove" then
        local file, line = uitools.get_current_file_and_line()
        if file and line then
            M.remove_note(file, line)
        end
    elseif command == "clear_file" then
        local bufnr = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_is_valid(bufnr) then
            local full_path = vim.api.nvim_buf_get_name(bufnr)
            if full_path and full_path ~= "" then
                uitools.confirm_action("Clear notes in file", false, function(accepted)
                    if accepted == true then
                        M.clear_file_notes(full_path)
                    end
                end)
            end
        end
    elseif command == "clear_all" then
        uitools.confirm_action("Clear all notes", false, function(accepted)
            if accepted == true then
                M.clear_all_notes()
            end
        end)
    else
        vim.notify('Invalid notes subcommand: ' .. tostring(command))
    end
end

---@param notes loopmarks.Note[]
function M.set_notes(notes)
    _set_notes(notes)
end

return M
