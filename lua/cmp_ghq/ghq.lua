local lsp = require "cmp.types.lsp"
local Path = require "plenary.path"
local async = require "plenary.async"
local async_system = require "cmp_ghq.async_system"
local git = require "cmp_ghq.git"
local timer = require "cmp_ghq.timer"

---@enum CmpGhqJobStatus
local STATUS = {
  REGISTERED = 0,
  STARTED = 1,
  FINISHED = 2,
}

---@class CmpGhqGhq
---@field cache table<string, lsp.completionItem[]>
---@field root? string
---@field jobs table<string, CmpGhqJobStatus>
---@field tx { send: fun(...: any): nil }
local Ghq = {}

---@return CmpGhqGhq
Ghq.new = function()
  local tx, rx = async.control.channel.mpsc()
  local self = setmetatable({ cache = {}, jobs = {}, tx = tx }, { __index = Ghq })
  async.void(function()
    local count = 0
    while true do
      count = count + 1
      local to_track = count % 10 == 0
      if to_track then
        timer.track(("fetch start: %d"):format(count))
      end
      local dir = rx.recv()
      self.jobs[dir] = STATUS.STARTED
      local ok, result = git.remote(dir)
      if ok then
        self.cache[dir] = self:make_candidate(result)
      else
        self:log("failed to fetch remote: %s", result)
      end
      self.jobs[dir] = STATUS.FINISHED
      if to_track then
        timer.track(("fetch finish: %d, %s"):format(count, dir))
      end
    end
  end)()
  return self
end

---@async
---@return string[]?
function Ghq:start()
  if not self.root then
    local ok, result = async_system { "ghq", "root" }
    if not ok then
      self:log("failed to ghq root: %s", result)
      return
    end
    self.root = result:gsub("\n", "")
  end
  local ok, result = async_system { "ghq", "list", "-p" }
  if not ok then
    self:log("failed to ghq list_p: %s", result)
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
  return {
    items = items,
    isIncomplete = not not vim.iter(pairs(self.jobs)):find(function(_, v)
      return v ~= STATUS.FINISHED
    end),
  }
end

---@private
---@param dir string
---@return lsp.completionItem[]
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

---@param fmt string
function Ghq:log(fmt, ...)
  require("cmp.utils.debug").log(("[cmp-ghq] " .. fmt):format(...))
end

local self
return {
  is_available = true,
  ghq = function()
    return self
  end,
  start = function(callback)
    if not self then
      self = Ghq.new()
    end
    async.void(function()
      callback(self:start())
    end)()
  end,
}
