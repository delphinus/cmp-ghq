local config = require "cmp_ghq.config"
local ghq = require "cmp_ghq.ghq"

---@class BlinkCmpGhq
local M = {}

---@param opts table
---@return BlinkCmpGhq
function M.new(opts)
  config.set_from_opts(opts or {})
  return setmetatable({}, { __index = M })
end

---@return string[]
function M:get_trigger_characters()
  return config.trigger_characters
end

---@return boolean
function M:enabled()
  return ghq.is_available
end

---@param _ table blink.cmp.Context
---@param callback fun(response?: table): nil
---@return fun(): nil
function M:get_completions(_, callback)
  return ghq.start(function(result)
    if not result then
      return callback()
    end
    callback {
      is_incomplete_forward = result.isIncomplete,
      is_incomplete_backward = result.isIncomplete,
      items = result.items,
    }
  end)
end

return M
