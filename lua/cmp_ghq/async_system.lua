local async = require "vim._async"

-- All vim.system handles spawned via this module that haven't exited yet.
-- Used by the VimLeavePre autocmd below to send SIGTERM on Neovim exit so we
-- don't leak ghq/git child processes when the user quits while a fire-and-
-- forget batch is still running.
---@type table<vim.SystemObj, true>
local inflight = {}

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("cmp_ghq.async_system", {}),
  callback = function()
    for h in pairs(inflight) do
      pcall(h.kill, h, 15)
    end
  end,
})

---@async
---@param cmd string[]
---@param opts? table
---@return boolean ok
---@return string result
return function(cmd, opts)
  opts = vim.tbl_extend("force", opts or {}, { text = true })
  local handle ---@type vim.SystemObj?
  local obj = async.await(3, function(c, o, cb)
    local ok, h = pcall(vim.system, c, o, function(...)
      if handle then
        inflight[handle] = nil
      end
      cb(...)
    end)
    if not ok then
      cb { code = -1, signal = 0, stdout = "", stderr = tostring(h) }
    else
      handle = h
      inflight[h] = true
    end
  end, cmd, opts)
  if obj.code ~= 0 then
    return false, ("[cmp-ghq] returned error: %s: %s"):format(table.concat(cmd, " "), obj.stderr)
  end
  return true, obj.stdout
end
