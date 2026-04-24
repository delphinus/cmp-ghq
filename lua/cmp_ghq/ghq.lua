local async_system = require "cmp_ghq.async_system"
local config = require "cmp_ghq.config"
local git = require "cmp_ghq.git"
local log = require "cmp_ghq.log"

local async = require "vim._async"

-- LSP CompletionItemKind values; inlined so this module does not depend on nvim-cmp.
local CompletionItemKind = { Folder = 19 }

-- ghq always uses POSIX paths, and vim.fs.relpath returns POSIX paths.
local SEP = "/"

---@class CmpGhqToken
---@field _cancelled boolean
local Token = {}
Token.__index = Token

---@return CmpGhqToken
function Token.new()
  return setmetatable({ _cancelled = false }, Token)
end

function Token:cancel()
  self._cancelled = true
end

---@return boolean
function Token:is_cancelled()
  return self._cancelled
end

---@class CmpGhqPending<T>: { subs: (fun(payload: T): nil)[] }

---@class CmpGhqGhq
---@field is_available boolean
---@field cache table<string, lsp.CompletionItem[]>
---@field root? string
---@field jobs table<string, true>
---@field _root_pending? CmpGhqPending<string?>
---@field _list_pending? CmpGhqPending<{ ok: boolean, result: string }>
local Ghq = {}

---@return CmpGhqGhq
Ghq.new = function()
  return setmetatable({ cache = {}, is_available = (pcall(vim.system, { config.ghq })), jobs = {} }, { __index = Ghq })
end

-- Single-flight wrapper for `ghq root`. Once resolved, the value is cached on
-- self.root for the lifetime of the instance, so subsequent calls short-circuit
-- without yielding.
---@async
---@return string?
function Ghq:_get_root()
  if self.root then
    return self.root
  end
  if self._root_pending then
    return async.await(1, function(cb)
      table.insert(self._root_pending.subs, cb)
    end)
  end
  self._root_pending = { subs = {} }
  local ok, result = async_system { config.ghq, "root" }
  local root = ok and (result:gsub("\n", "")) or nil
  if root then
    self.root = root
  else
    log.debug("failed to ghq root: %s", result)
  end
  local subs = self._root_pending.subs
  self._root_pending = nil
  for _, cb in ipairs(subs) do
    cb(root)
  end
  return root
end

-- Single-flight wrapper for `ghq list -p`. Unlike `_get_root` the result is
-- not cached past completion: once the broadcast finishes, the next call spawns
-- a fresh process. This keeps the repo list fresh while still coalescing the
-- bursts of calls that blink.cmp produces during typing.
---@async
---@return { ok: boolean, result: string }
function Ghq:_get_list()
  if self._list_pending then
    return async.await(1, function(cb)
      table.insert(self._list_pending.subs, cb)
    end)
  end
  self._list_pending = { subs = {} }
  local ok, result = async_system { config.ghq, "list", "-p" }
  local payload = { ok = ok, result = result }
  local subs = self._list_pending.subs
  self._list_pending = nil
  for _, cb in ipairs(subs) do
    cb(payload)
  end
  return payload
end

---@async
---@param token CmpGhqToken
---@return { items: lsp.CompletionItem[], isIncomplete: boolean }?
function Ghq:start(token)
  local root = self:_get_root()
  if not root or token:is_cancelled() then
    return
  end

  local list = self:_get_list()
  if not list.ok then
    log.debug("failed to ghq list_p: %s", list.result)
    return
  end
  if token:is_cancelled() then
    return
  end

  local items, seen, pending = {}, {}, {}
  vim.iter(vim.gsplit(list.result, "\n", { plain = true, trimempty = true })):each(function(line)
    if not self.cache[line] then
      local has_cloned_from_ghq = not not line:find(self.root, nil, true)
      if has_cloned_from_ghq then
        local dir = vim.fs.relpath(self.root, line) or line
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
      self.jobs[line] = true
      table.insert(pending, line)
    end
  end)
  if #pending > 0 then
    local funs = vim
      .iter(pending)
      :map(function(dir)
        return function()
          local r_ok, r_res = git.remote(dir)
          if r_ok then
            self.cache[dir] = self:make_candidate(r_res)
          else
            log.debug("failed to fetch remote: %s", r_res)
          end
          self.jobs[dir] = nil
        end
      end)
      :totable()
    -- Fire-and-forget: caller does not wait for these. They populate the
    -- cache so subsequent start() calls can resolve them synchronously.
    -- Cancellation does not stop this batch; VimLeavePre cleanup in
    -- async_system.lua kills any handles still alive on Neovim exit.
    async.run(function()
      async.join(config.concurrency, funs)
    end)
  end
  return {
    items = items,
    isIncomplete = next(self.jobs) ~= nil,
  }
end

---@param dir string
---@return lsp.CompletionItem[]
function Ghq:make_candidate(dir)
  local parts = vim.split(dir, SEP, { plain = true })
  return vim.iter(ipairs(parts)):fold({}, function(items, i, part)
    local function add(label)
      table.insert(items, { label = label, kind = CompletionItemKind.Folder, documentation = dir })
    end
    if #part > 2 then
      add(part)
    end
    if i < #parts then
      add(table.concat(vim.list_slice(parts, i, #parts), SEP))
    end
    return items
  end)
end

return setmetatable({
  -- Test hooks: not part of the stable public API.
  _Ghq = Ghq,
  _Token = Token,
}, {
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
      ---@param callback fun(result?: { items: lsp.CompletionItem[], isIncomplete: boolean }): nil
      ---@return fun(): nil cancel
      return function(callback)
        local token = Token.new()
        async.run(function()
          local result = instance():start(token)
          if not token:is_cancelled() then
            callback(result)
          end
        end)
        return function()
          token:cancel()
        end
      end
    end
  end,
})
