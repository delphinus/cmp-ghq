local a = require "plenary.async_lib"
local Git = require "cmp_ghq.git"
local AsyncJob = require "cmp_ghq.async_job"

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
---@return function
function Ghq:list(cb)
  return function()
    local items = {}
    self.log:debug("cache: %s", #vim.tbl_keys(self._cache))
    ---@type string[]?, string[]?
    local err, result = a.await(AsyncJob { command = self.config.executable, args = { "list", "-p" } })
    if err then
      cb { items = {}, isIncomplete = true }
      return
    end
    vim.iter(result):each(function(line)
      local host, org, repo = line:match "(github.[^/]+)/([^/]+)/([^?]+)$"
      if host then
        table.insert(items, { label = host .. "/" .. org .. "/" .. repo })
        table.insert(items, { label = org .. "/" .. repo })
      elseif self._cache[line] then
        vim.iter(self._cache[line]):each(function(v)
          table.insert(items, v)
        end)
      elseif not self._git_jobs[line] then
        ---@param err string[]?
        ---@param result cmp_ghq.git.Remote?
        self._git_jobs[line] = self.git:remote(line, function(err, result)
          if err then
            return
          end
          ---@cast result cmp_ghq.git.Remote
          self._cache[line] = {
            { label = result.host .. "/" .. result.org .. "/" .. result.repo },
            { label = result.org .. "/" .. result.repo },
          }
          self._git_jobs[line] = nil
        end)()
      end
    end)
    local is_incomplete = #vim.tbl_keys(self._git_jobs) > 0
    self.log:debug("items: %s, isIncomplete: %s", #items, is_incomplete)
    cb { items = items, isIncomplete = is_incomplete }
  end
end

return Ghq
