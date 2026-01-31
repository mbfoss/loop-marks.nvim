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
            "delete",
            "list",
            "clear_file",
            "clear_all"
        }
    end
    return {}
end

---@param args string[]
---@param opts vim.api.keyset.create_user_command.command_args
---@param ws_dir string
local function _do_command(args, opts, ws_dir)
    local cmd = args[1]
    if cmd == "list" then
        notesmonitor.select_note(ws_dir)
    else
        notes.notes_command(cmd, ws_dir)
    end
end

---@param ext_data loop.ExtensionData
function M.get_cmd_provider(ext_data)
---@type loop.UserCommandProvider
return {
    get_subcommands = function(args)
        return _notes_commands(args)
    end,
    dispatch = function(args, opts)
        return _do_command(args, opts, ext_data.ws_dir)
    end,
}
end

return M
