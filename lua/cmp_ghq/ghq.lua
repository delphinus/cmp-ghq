local async_system = require "cmp_ghq.async_system"
local config = require "cmp_ghq.config"
local git = require "cmp_ghq.git"
local log = require "cmp_ghq.log"

local lsp = require "cmp.types.lsp"
local Path = require "plenary.path"
local async = require "plenary.async"

---@enum CmpGhqJobStatus
local STATUS = {
  REGISTERED = 0,
  STARTED = 1,
  FINISHED = 2,
}

---@class CmpGhqGhq
---@field is_available boolean
---@field cache table<string, lsp.CompletionItem[]>
---@field root? string
---@field jobs table<string, CmpGhqJobStatus>
---@field tx { send: fun(...: any): nil }
local Ghq = {}

---@return CmpGhqGhq
Ghq.new = function()
  local tx, rx = async.control.channel.mpsc()
  local self = setmetatable(
    { cache = {}, is_available = (pcall(vim.system, { config.ghq })), jobs = {}, tx = tx },
    { __index = Ghq }
  )
  async.void(function()
    while true do
      local dir = rx.recv() --[[@as string?]]
      if not dir then
        break
      end
      self.jobs[dir] = STATUS.STARTED
      local ok, result = git.remote(dir)
      if ok then
        self.cache[dir] = self:make_candidate(result)
      else
        log.debug("failed to fetch remote: %s", result)
      end
      self.jobs[dir] = STATUS.FINISHED
    end
  end)()
  return self
end

---@async
---@return string[]?
function Ghq:start()
  if not self.root then
    local ok, result = async_system { config.ghq, "root" }
    if not ok then
      log.debug("failed to ghq root: %s", result)
      return
    end
    self.root = result:gsub("\n", "")
  end
  local ok, result = async_system { config.ghq, "list", "-p" }
  if not ok then
    log.debug("failed to ghq list_p: %s", result)
    return
  end
  local items, seen = {}, {}
  vim.iter(vim.gsplit(result, "\n", { plain = true, trimempty = true })):each(function(line)
    if not self.cache[line] then
      local has_cloned_from_ghq = not not line:find(self.root, nil, true)
      if has_cloned_from_ghq then
        local dir = Path:new(line):make_relative(self.root)
        self.cache[line] = self:make_candidate(dir)
      end
    end
    if self.cache[line] then
      vim.iter(self.cache[line]):each(function(candidate)
        if not seen[candidate.label] then
          table.insert(items, candidate)
          seen[candidate.label] = true
        end
      end)
    elseif not self.jobs[line] then
      self.tx.send(line)
      self.jobs[line] = STATUS.REGISTERED
    end
  end)
  self.tx.send()
  return {
    items = items,
    isIncomplete = not not vim.iter(pairs(self.jobs)):find(function(_, v)
      return v ~= STATUS.FINISHED
    end),
  }
end

---@param dir string
---@return lsp.CompletionItem[]
function Ghq:make_candidate(dir)
  local parts = vim.split(dir, Path.path.sep, { plain = true })
  return vim.iter(ipairs(parts)):fold({}, function(items, i, part)
    local function add(label)
      table.insert(items, { label = label, kind = lsp.CompletionItemKind.Folder, documentation = dir })
    end
    if #part > 2 then
      add(part)
    end
    if i < #parts then
      add(table.concat(vim.list_slice(parts, i, #parts), Path.path.sep))
    end
    return items
  end)
end

return setmetatable({}, {
  __index = function(self, key)
    ---@return CmpGhqGhq
    local function instance()
      return rawget(self, "instance")
    end
    if not instance() then
      rawset(self, "instance", Ghq.new())
    end
    if key == "is_available" then
      return instance().is_available
    elseif key == "start" then
      return async.void(function(callback)
        callback(instance():start())
      end)
    end
  end,
})
