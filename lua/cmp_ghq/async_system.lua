local config = require "cmp_ghq.config"
local async = require "plenary.async"

local async_system = async.wrap(vim.system, 3)

local semaphore

---@async
---@param cmd string[]
---@param opts? table
---@return boolean ok
---@return string result
return function(cmd, opts)
  opts = vim.tbl_extend("force", opts or {}, { text = true })
  if not semaphore then
    semaphore = async.control.Semaphore.new(config.concurrency)
  end
  local permit = semaphore:acquire()
  local ok, err_or_result = async.util.apcall(async_system, cmd, opts)
  permit:forget()
  if not ok then
    return false, ("[cmp-ghq] failed to spawn: %s"):format(err_or_result)
  elseif err_or_result.code ~= 0 then
    return false, ("[cmp-ghq] returned error: %s: %s"):format(table.concat(cmd, " "), err_or_result.stderr)
  end
  return true, err_or_result.stdout
end
