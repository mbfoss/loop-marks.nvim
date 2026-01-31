local bookmarks = require('loop-marks.bookmarks')
local notes = require('loop-marks.notes')

---@type loop.Extension
local extension =
{
    on_workspace_load = function(ext_data)
        bookmarks.set_bookmarks(ext_data.state.get("marks") or {})
        notes.set_notes(ext_data.state.get("notes") or {})
        ext_data.register_user_command("mark", require("loop-marks.bookmarks_cmd").get_cmd_provider(ext_data))
        ext_data.register_user_command("note", require("loop-marks.notes_cmd").get_cmd_provider(ext_data))
    end,
    on_workspace_unload = function(_)
        bookmarks.clear_all_bookmarks()
        notes.clear_all_notes()
    end,
    on_state_will_save = function(ext_data)
        ext_data.state.set("marks", bookmarks.get_bookmarks())
        ext_data.state.set("notes", notes.get_notes())
    end,
}
return extension
