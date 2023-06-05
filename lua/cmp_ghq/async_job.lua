local a = require "plenary.async_lib"
local Job = require "plenary.job"

---@class cmp_ghq.async_job.Options
---@field command string
---@field args string[]?
---@field cwd string?

---@alias cmp_ghq.async_job.Callback fun(err: string[]?, result: string[]?): nil

---@param opts cmp_ghq.async_job.Options
---@param cb fun(err: string[]?, result: string[]?): nil
return a.wrap(function(opts, cb)
  local j = Job:new { command = opts.command, args = opts.args, cwd = opts.cwd }
  j:after_success(function()
    cb(nil, j:result())
  end)
  j:after_failure(function(_, code, signal)
    cb(j:stderr_result())
  end)
  j:start()
end, 2)
