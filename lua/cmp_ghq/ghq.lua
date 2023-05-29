local Git = require "cmp_ghq.git"
local Job = require "plenary.job"

---@class cmp_ghq.ghq.Config
---@field executable string

---@class cmp_ghq.ghq.Ghq
---@field config cmp_ghq.ghq.Config
---@field git cmp_ghq.git.Git
---@field log cmp_ghq.logger.Logger
---@field _cache table<string, table>
---@field _git_jobs table<string, table>
local Ghq = {}

---@type cmp_ghq.ghq.Config
local default_config = { executable = "ghq" }

---@param log cmp_ghq.logger.Logger
---@param overrides table?
---@return cmp_ghq.ghq.Ghq
Ghq.new = function(log, overrides)
  return setmetatable({
    config = vim.tbl_extend("force", default_config, overrides or {}),
    git = Git.new(log),
    log = log,
    _cache = {},
    _git_jobs = {},
  }, { __index = Ghq })
end

---@param cb function
function Ghq:list(cb)
  local items = {}
  self.log:debug("cache: %s", #vim.tbl_keys(self._cache))
  local j = Job:new {
    command = self.config.executable,
    args = { "list", "-p" },
  }
  j:after_success(function()
    for _, line in ipairs(j:result()) do
      local host, org, repo = line:match "(github.[^/]+)/([^/]+)/([^?]+)$"
      if host then
        table.insert(items, { label = host .. "/" .. org .. "/" .. repo })
        table.insert(items, { label = org .. "/" .. repo })
      elseif self._cache[line] then
        vim.iter(self._cache[line]):each(function(v)
          table.insert(items, v)
        end)
      elseif not self._git_jobs[line] then
        self._git_jobs[line] = self.git:remote(line, function(result)
          self._cache[line] = {
            { label = result.host .. "/" .. result.org .. "/" .. result.repo },
            { label = result.org .. "/" .. result.repo },
          }
          self._git_jobs[line] = nil
        end)
      end
    end
    self.log:debug("items: %s", #items)
    self.log:debug("waiting line: %s", #vim.tbl_keys(self._git_jobs))
    cb(items)
  end)
  j:start()
end

return Ghq
