---@class CmpGhqOptions
---@field concurrency integer default: 5
---@field ghq? string default: "ghq"
---@field git? string default: "git"
---@field keyword_pattern? string default: [[\w\+]]
---@field trigger_characters? string[] default: { "." }

---@class CmpGhqRawConfig
---@field concurrency integer
---@field ghq string
---@field git string
---@field keyword_pattern string
---@field trigger_characters string[]
local default_config = {
  concurrency = 5,
  ghq = "ghq",
  git = "git",
  keyword_pattern = [[\w\+]],
  trigger_characters = { "." },
}

---@class CmpGhqConfig: CmpGhqRawConfig
local Config = {}

---@return nil
Config.set = function()
  local cfg = require("cmp.config").get_source_config "ghq"
  local extended = vim.tbl_extend("force", default_config, (cfg or {}).option or {})
  vim.iter(pairs(extended)):each(function(k, v)
    Config[k] = v
  end)
end

return Config
