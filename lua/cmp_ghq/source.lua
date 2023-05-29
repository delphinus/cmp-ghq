local default_config = require "cmp_ghq.default_config"
local Ghq = require "cmp_ghq.ghq"
local Logger = require "cmp_ghq.logger"

---@class cmp_ghq.source.Source: cmp.Source
---@field log cmp_ghq.logger.Logger
---@field ghq cmp_ghq.ghq.Ghq
local Source = {}

---@param overrides table
---@return cmp_ghq.source.Source
Source.new = function(overrides)
  local log = Logger.new(overrides)
  return setmetatable({
    config = vim.tbl_extend("force", default_config, overrides),
    ghq = Ghq.new(log),
    log = log,
  }, { __index = Source })
end

function Source:complete(_, callback)
  self.log:debug "completion start"
  self.ghq:list(callback)
end

function Source:get_debug_name()
  return "ghq"
end

function Source:is_available()
  return true
end

function Source:get_keyword_pattern()
  return [[\w\+]]
end

function Source:get_trigger_characters()
  return { "." }
end

return Source
