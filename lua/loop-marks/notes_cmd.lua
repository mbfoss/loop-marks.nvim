local M = {}

local notes = require("loop-marks.notes")
local notesmonitor = require("loop-marks.notesmonitor")

--------------------------------------------
-- Dispatcher
-----------------------------------------------------------

local function _notes_commands(args)
    if #args == 0 then
        return {
            "set",
            "name",
            "remove",
            "list",
            "clear_file",
            "clear_all"
        }
    end
    return {}
end

---@param args string[]
---@param opts vim.api.keyset.create_user_command.command_args
local function _do_command(args, opts)
    local cmd = args[1]
    if not cmd or cmd == "" or cmd == "list" then
        notesmonitor.select_note()
    else
        notes.notes_command(cmd)
    end
end

---@type loop.UserCommandProvider
return {
    get_subcommands = function(args)
        return _notes_commands(args)
    end,
    dispatch = function(args, opts)
        return _do_command(args, opts)
    end,
}
