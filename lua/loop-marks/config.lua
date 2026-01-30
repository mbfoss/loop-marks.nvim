---@class loop-marks.Config
---@field stack_levels_limit? number
---@field mark_sign_priority? number
---@field note_sign_priority? number
---@field mark_symbol? string
---@field note_symbol? string

local M = {}

---@type loop-marks.Config|nil
M.current = nil

return M
