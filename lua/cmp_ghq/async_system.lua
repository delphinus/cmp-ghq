local async = require "vim._async"

---@param cmd string[]
---@param opts table
---@param cb fun(obj: vim.SystemCompleted): nil
---@return nil
local function safe_system(cmd, opts, cb)
  local ok, err = pcall(vim.system, cmd, opts, cb)
  if not ok then
    cb { code = -1, signal = 0, stdout = "", stderr = tostring(err) }
  end
end

---@async
---@param cmd string[]
---@param opts? table
---@return boolean ok
---@return string result
return function(cmd, opts)
  opts = vim.tbl_extend("force", opts or {}, { text = true })
  local obj = async.await(3, safe_system, cmd, opts)
  if obj.code ~= 0 then
    return false, ("[cmp-ghq] returned error: %s: %s"):format(table.concat(cmd, " "), obj.stderr)
  end
  return true, obj.stdout
end
