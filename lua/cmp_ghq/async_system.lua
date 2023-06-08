local a = require "plenary.async_lib"
local Job = require "plenary.job"

---@class cmp_ghq.async_system.Config
---@field concurrency integer

---@class cmp_ghq.async_system.Options
---@field cwd string?

---@class cmp_ghq.async_system.AsyncSystem
---@field config cmp_ghq.async_system.Config
---@field _semaphore Semaphore
---@operator call(string[], cmp_ghq.async_system.Options): Future

local async_system = a.wrap(vim.system, 3)

local function split(lines)
  return vim
    .iter(vim.split(lines, "\n"))
    :filter(function(line)
      return #line > 0
    end)
    :totable()
end

return setmetatable({ config = { concurrency = 5 } }, {
  ---@param self cmp_ghq.async_system.AsyncSystem
  ---@param cmd string[]
  ---@param opts cmp_ghq.async_system.Options
  __call = a.async(function(self, cmd, opts)
    if not self._semaphore then
      self._semaphore = a.util.Semaphore.new(self.config.concurrency)
    end
    local permit = a.await(self._semaphore:acquire() --[[@as Future]])
    local result = a.await(async_system(cmd, opts))
    permit:forget()
    if result.code == 0 then
      return nil, split(result.stdout)
    end
    return split(result.stderr)
  end),
})
