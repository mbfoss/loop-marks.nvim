local bookmarks = require('loop-marks.bookmarks')
local cmd_provider = require('loop-marks.cmd_provider')

---@type loop.Extension
local extension =
{
    on_workspace_load = function(ext_data)
        bookmarks.set_bookmarks(ext_data.state.get("marks") or {})
        ext_data.register_user_command("mark", cmd_provider)
    end,
    on_workspace_unload = function(_)
        bookmarks.clear_all_bookmarks()
    end,
    on_state_will_save = function(ext_data)
        ext_data.state.set("marks", bookmarks.get_bookmarks())
    end,
}
return extension
