local a = require "plenary.async_lib"
local AsyncJob = require "cmp_ghq.async_job"

---@class cmp_ghq.git.Opts
---@field executable string?
---@field default_remotes string[]?

---@class cmp_ghq.git.Config
---@field executable string
---@field default_remotes string[]

---@class cmp_ghq.git.Remote
---@field host string
---@field org string
---@field repo string

---@class cmp_ghq.git.Git
---@field config cmp_ghq.git.Config
---@field default_remotes_re string
---@field log cmp_ghq.logger.Logger
local Git = {}

---@type cmp_ghq.git.Config
local default_config = { default_remotes = { "origin" }, executable = "git" }

---@param log cmp_ghq.logger.Logger
---@param opts cmp_ghq.git.Opts?
---@return cmp_ghq.git.Git
Git.new = function(log, opts)
  local self = setmetatable(
    { config = vim.tbl_extend("force", default_config, opts or {}), log = log },
    { __index = Git }
  )
  self.default_remotes_re = ("^(%s)"):format(table.concat(self.config.default_remotes, "|"))
  return self
end

---@param url string?
---@return cmp_ghq.git.Remote?
function Git:parse_url(url)
  if not url then
    return nil
  end
  url = url:gsub(".git$", "")
  url = url:gsub("^[^:]+://", "")
  url = url:gsub("^[^@]+@", "")
  local host, org, repo = url:match "^([^:/]+)[:/]([^/]+)/(.+)"
  return host and { host = host, org = org, repo = repo } or nil
end

---@param line string?
---@return cmp_ghq.git.Remote?
function Git:parse_line(line)
  if line then
    local url = line:match "^%S+%s+(%S+)" --[[@as string?]]
    return self:parse_url(url)
  end
end

---@param dir string
---@return string[]?, cmp_ghq.git.Remote?
function Git:remote(dir)
  local err, result = a.await(AsyncJob { command = self.config.executable, args = { "remote", "-v" }, cwd = dir })
  if err then
    return err
  end
  local origin = vim.iter(result):find(function(line)
    return not not line:match(self.default_remotes_re)
  end)
  local remote = self:parse_line(origin)
  if remote then
    return nil, remote
  end
  return { "remote not found" }
end

return Git
