local config = require "cmp_ghq.config"
local ghq = require "cmp_ghq.ghq"

---@class CmpGhq
local source = {}

---@return CmpGhq
source.new = function()
  config.set()
  return setmetatable({}, { __index = source })
end

---@return string
source.get_debug_name = function()
  return "ghq"
end

---@return boolean
source.is_available = function()
  return ghq.is_available
end

---@return string
function source:get_keyword_pattern()
  return config.keyword_pattern
end

---@return string[]
function source:get_trigger_characters()
  return config.trigger_characters
end

---@param callback fun(items?: vim.CompletedItem[]): nil
---@return nil
function source:complete(_, callback)
  ghq.start(callback)
end

return source
