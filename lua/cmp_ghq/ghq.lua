local a = require "plenary.async_lib"
local Path = require "plenary.path"
local Git = require "cmp_ghq.git"
local AsyncJob = require "cmp_ghq.async_job"

---@class cmp_ghq.ghq.Config
---@field executable string

---@class cmp_ghq.ghq.Ghq
---@field config cmp_ghq.ghq.Config
---@field git cmp_ghq.git.Git
---@field log cmp_ghq.logger.Logger
---@field _semaphore Semaphore
---@field _roots string[]?
---@field _cache table<string, table>
---@field _git_jobs table<string, boolean>
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
    _semaphore = a.util.Semaphore.new(5),
    _roots = nil,
    _cache = {},
    _git_jobs = {},
  }, { __index = Ghq })
end

---@return table[]
function Ghq:list()
  self.log:debug "ghq:list()"
  local items = {}
  self.log:debug("cache: %s", #vim.tbl_keys(self._cache))
  if not self._roots then
    self.log:debug "ghq root --all"
    local err, result = a.await(AsyncJob { command = self.config.executable, args = { "root", "--all" } })
    if err then
      return {}
    end
    self._roots = result
  end
  self.log:debug "ghq list -p"
  ---@type string[]?, string[]?
  local err, result = a.await(AsyncJob { command = self.config.executable, args = { "list", "-p" } })
  if err then
    self.log:debug("ghq list -p: %s", err)
    return { items = {}, isIncomplete = true }
  end
  self.log:debug "iter start"
  vim.iter(result):each(function(line)
    local parent_root = vim.iter(self._roots):find(function(root)
      local s = line:find(root, nil, true)
      return not not s
    end)
    if parent_root then
      local dir = Path:new(line):make_relative(parent_root)
      local host, org, repo = dir:match "^([^/]+)/([^/]+)/([^/]+)$"
      if host then
        table.insert(items, { label = host .. "/" .. org .. "/" .. repo })
        table.insert(items, { label = org .. "/" .. repo })
        table.insert(items, { label = repo })
        return
      end
    end
    if self._cache[line] then
      vim.iter(self._cache[line]):each(function(v)
        table.insert(items, v)
      end)
    elseif not self._git_jobs[line] then
      self._git_jobs[line] = true
    end
  end)
  self.log:debug "iter end"
  local is_incomplete = #vim.tbl_keys(self._git_jobs) > 0
  self.log:debug("items: %s, isIncomplete: %s", #items, is_incomplete)
  return { items = items, isIncomplete = is_incomplete }
end

function Ghq:fetch_remotes()
  self.log:debug("start: permits: %d waiting: %d", self._semaphore.permits, #self._semaphore.handles)
  vim.iter(self._git_jobs):each(function(url)
    a.run(a.async(function()
      local permit = a.await(self._semaphore:acquire() --[[@as Future]])
      self.log:debug("permits: %d waiting: %d", self._semaphore.permits, #self._semaphore.handles)
      local err, result = self.git:remote(url)
      if not err then
        ---@cast result cmp_ghq.git.Remote
        self._cache[url] = {
          { label = result.host .. "/" .. result.org .. "/" .. result.repo },
          { label = result.org .. "/" .. result.repo },
          { label = result.repo },
        }
      end
      self._git_jobs[url] = nil
      permit:forget()
    end)())
  end)
end

return Ghq
