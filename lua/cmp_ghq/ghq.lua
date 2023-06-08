local lsp = require "cmp.types.lsp"
local a = require "plenary.async_lib"
local Path = require "plenary.path"
local Git = require "cmp_ghq.git"
local AsyncSystem = require "cmp_ghq.async_system"

---@class cmp_ghq.ghq.Config
---@field executable string

---@class cmp_ghq.ghq.Ghq
---@field config cmp_ghq.ghq.Config
---@field git cmp_ghq.git.Git
---@field log cmp_ghq.logger.Logger
---@field _semaphore Semaphore
---@field _root string?
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
    _root = nil,
    _cache = {},
    _git_jobs = {},
  }, { __index = Ghq })
end

---@param dir string
---@return lsp.CompletionItem[]
function Ghq:make_candidates(dir)
  local parts = vim.split(dir, "/")
  local items = {}
  local function add(label)
    table.insert(items, { label = label, kind = lsp.CompletionItemKind.Folder, documentation = dir })
  end
  vim.iter(ipairs(parts)):each(function(i, part)
    if #part > 2 then
      add(part)
    end
    if i < #parts then
      add(table.concat(vim.iter(parts):slice(i, #parts):totable(), "/"))
    end
  end)
  return items
end

---@return table[]
function Ghq:list()
  self.log:debug "ghq:list()"
  self.log:debug("cache: %s", #vim.tbl_keys(self._cache))
  if not self._root then
    self.log:debug "ghq root"
    local err, result = a.await(AsyncSystem { self.config.executable, "root" })
    if err then
      return {}
    end
    self._root = result[1]
  end
  self.log:debug "ghq list -p"
  ---@type string[]?, string[]?
  local err, result = a.await(AsyncSystem { self.config.executable, "list", "-p" })
  if err then
    self.log:debug("ghq list -p: %s", err)
    return { items = {}, isIncomplete = true }
  end
  self.log:debug "iter start"
  local items = {}
  vim.iter(result):each(function(line)
    local has_cloned_from_ghq = not not line:find(self._root, nil, true)
    if has_cloned_from_ghq then
      local dir = Path:new(line):make_relative(self._root)
      local candidates = self:make_candidates(dir)
      vim.iter(candidates):each(function(c)
        table.insert(items, c)
      end)
      return
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
  vim.iter(self._git_jobs):each(function(url)
    a.run(a.async(function()
      local err, result = self.git:remote(url)
      if not err then
        ---@cast result string
        self._cache[url] = self:make_candidates(result)
      end
      self._git_jobs[url] = nil
    end)())
  end)
end

return Ghq
