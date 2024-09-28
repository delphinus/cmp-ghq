---@class FrecencyTimer
---@field has_lazy boolean?
local M = {
  enabled = not not vim.env.CMP_GHQ_DEBUG,
}

---@param event string
---@return nil
function M.track(event)
  local debug = require "cmp.utils.debug"
  if not M.enabled then
    return
  elseif M.has_lazy == nil then
    M.has_lazy = (pcall(require, "lazy.stats"))
    if not M.has_lazy then
      debug.log "frecency.timer needs lazy.nvim"
    end
  end
  if M.has_lazy then
    local stats = require "lazy.stats"
    local function make_key(num)
      local key = num and ("[cmp-ghq] %s: %d"):format(event, num) or "[cmp-ghq] " .. event
      return stats._stats.times[key] and make_key((num or 1) + 1) or key
    end
    stats.track(make_key())
  end
end

---@return string
function M.pp()
  local times = require("lazy.stats")._stats.times
  local result = vim.tbl_map(function(k)
    return { event = k, t = times[k] }
  end, vim.tbl_keys(times))
  table.sort(result, function(a, b)
    return a.t < b.t
  end)
  return table.concat(
    vim.tbl_map(function(r)
      return ("%8.3f : %s"):format(r.t, r.event)
    end, result),
    "\n"
  )
end

return M
