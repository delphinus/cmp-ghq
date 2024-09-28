local Path = require "plenary.path"

---@class CmpGhqOptions
---@field cache_filename? string default: "wezterm"
---@field executable? string default: "wezterm"
---@field keyword_pattern? string default: [[\w\+]]
---@field trigger_characters? string[] default: { "." }

---@class CmpGhqRawConfig
---@field cache_filename string
---@field executable string
---@field keyword_pattern string
---@field trigger_characters string[]
local default_config = {
  cache_filename = Path:new(vim.fn.stdpath "cache") / "cmp-ghq.bin",
  executable = "wezterm",
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
