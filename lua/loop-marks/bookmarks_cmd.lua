local M = {}

local bookmarks = require("loop-marks.bookmarks")
local bookmarksmonitor = require("loop-marks.bookmarksmonitor")

--------------------------------------------
-- Dispatcher
-----------------------------------------------------------

local function _bookmarks_commands(args)
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
        bookmarksmonitor.select_bookmark(ws_dir)
    else
        bookmarks.bookmarks_command(cmd, ws_dir)
    end
end

---@param ext_data loop.ExtensionData
function M.get_cmd_provider(ext_data)
    ---@type loop.UserCommandProvider
    return {
        get_subcommands = function(args)
            return _bookmarks_commands(args)
        end,
        dispatch = function(args, opts)
            return _do_command(args, opts, ext_data.ws_dir)
        end,
    }
end

return M
