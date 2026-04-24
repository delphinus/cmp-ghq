local async_system = require "cmp_ghq.async_system"
local config = require "cmp_ghq.config"
local git = require "cmp_ghq.git"
local log = require "cmp_ghq.log"

local async = require "vim._async"

-- LSP CompletionItemKind values; inlined so this module does not depend on nvim-cmp.
local CompletionItemKind = { Folder = 19 }

-- ghq always uses POSIX paths, and vim.fs.relpath returns POSIX paths.
local SEP = "/"

---@class CmpGhqGhq
---@field is_available boolean
---@field cache table<string, lsp.CompletionItem[]>
---@field root? string
---@field jobs table<string, true>
local Ghq = {}

---@return CmpGhqGhq
Ghq.new = function()
  return setmetatable({ cache = {}, is_available = (pcall(vim.system, { config.ghq })), jobs = {} }, { __index = Ghq })
end

---@async
---@return { items: lsp.CompletionItem[], isIncomplete: boolean }?
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
  local items, seen, pending = {}, {}, {}
  vim.iter(vim.gsplit(result, "\n", { plain = true, trimempty = true })):each(function(line)
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
    local funs = vim.iter(pending):map(function(dir)
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
    -- Fire-and-forget: caller does not wait for these. They populate the
    -- cache so subsequent start() calls can resolve them synchronously.
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
      ---@param callback fun(result?: { items: lsp.CompletionItem[], isIncomplete: boolean }): nil
      ---@return fun(): nil cancel
      return function(callback)
        local cancelled = false
        async.run(function()
          local result = instance():start()
          if not cancelled then
            callback(result)
          end
        end)
        return function()
          cancelled = true
        end
      end
    end
  end,
})
