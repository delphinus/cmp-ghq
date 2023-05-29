local Job = require "plenary.job"

---@class cmp_ghq.git.Config
---@field executable string

---@class cmp_ghq.git.Remote
---@field host string
---@field org string
---@field repo string

---@class cmp_ghq.git.Git
---@field config cmp_ghq.git.Config
---@field log cmp_ghq.logger.Logger
local Git = {}

---@type cmp_ghq.git.Config
local default_config = { executable = "git" }

---@param log cmp_ghq.logger.Logger
---@param overrides table?
---@return cmp_ghq.git.Git
Git.new = function(log, overrides)
  return setmetatable(
    { config = vim.tbl_extend("force", default_config, overrides or {}), log = log },
    { __index = Git }
  )
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
  local host, org, repo = url:match "^([^:]+):([^/]+)/(.+)"
  if not host then
    host, org, repo = url:match "^([^/]+)/([^/]+)/(.+)"
  end
  return host and { host = host, org = org, repo = repo } or nil
end

---@param cb fun(result: cmp_ghq.git.Remote): nil
---@return table
function Git:remote(dir, cb)
  local j = Job:new { command = self.config.executable, args = { "remote", "-v" }, cwd = dir }
  j:after_success(function()
    local origin = vim.iter(j:result()):find(function(line)
      return not not line:match "^origin"
    end)
    local url = origin:match "^%S+%s+(%S+)"
    if url then
      local remote = self:parse_url(url)
      if remote then
        cb(remote)
      end
    end
  end)
  j:start()
  return j
end

return Git
