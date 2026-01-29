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
    if cmd == "list" then
        bookmarksmonitor.select_bookmark()
    else
        bookmarks.bookmarks_command(cmd)
    end
end

---@type loop.UserCommandProvider
return {
    get_subcommands = function(args)
        return _bookmarks_commands(args)
    end,
    dispatch = function(args, opts)
        return _do_command(args, opts)
    end,
}
