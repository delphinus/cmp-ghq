local a = require "plenary.async_lib"
local Job = require "plenary.job"

---@class cmp_ghq.async_job.Config
---@field concurrency integer

---@class cmp_ghq.async_job.Options
---@field command string
---@field args string[]?
---@field cwd string?

---@alias cmp_ghq.async_job.Callback fun(err: string[]?, result: string[]?): nil

---@class cmp_ghq.async_job.AsyncJob
---@field config cmp_ghq.async_job.Config
---@field _semaphore Semaphore

---@param opts cmp_ghq.async_job.Options
---@param cb cmp_ghq.async_job.Callback
local async_job = a.wrap(function(opts, cb)
  local j = Job:new { command = opts.command, args = opts.args, cwd = opts.cwd }
  j:after_success(function()
    cb(nil, j:result())
  end)
  j:after_failure(function(_, code, signal)
    cb(j:stderr_result())
  end)
  j:start()
end, 2)

return setmetatable({ config = { concurrency = 5 } }, {
  ---@param self cmp_ghq.async_job.AsyncJob
  __call = a.async(function(self, opts)
    if not self._semaphore then
      self._semaphore = a.util.Semaphore.new(self.config.concurrency)
    end
    local permit = a.await(self._semaphore:acquire() --[[@as Future]])
    local err, result = a.await(async_job(opts))
    permit:forget()
    return err, result
  end),
})
