-- Neovim promoted its coroutine-based async runtime from the private
-- `vim._async` to the public `vim.async`. `run` and `await` keep the
-- signatures this plugin relies on, but `vim.async` dropped `join` in favour
-- of `vim.async.semaphore`, so reimplement it here. Prefer the public module
-- and fall back to the private one on older versions.

-- The subset of the runtime this plugin uses, described loosely enough that
-- neither backend's annotations reach the call sites. `vim.async` in
-- particular declares generic return types on `run`, which would otherwise
-- make every fire-and-forget `run(function() ... end)` a missing-return
-- diagnostic.
---@class CmpGhqAsync
---@field run fun(func: async fun(): nil): nil
---@field await async fun(argc: integer, func: function, ...: any): any
---@field join async fun(max_jobs: integer, funs: (async fun(): nil)[]): nil

if not vim.async then
  return require "vim._async" --[[@as CmpGhqAsync]]
end

local async = vim.async

-- Yielding across `pcall` needs LuaJIT. Neovim ships coxpcall for the rare
-- PUC Lua builds, and both `vim._async` and `vim.async` do the same dance.
local copcall = package.loaded.jit and pcall or require("coxpcall").pcall

---Run `funs` with at most `max_jobs` of them in flight and return once all
---have finished. Errors raised by a fun are swallowed so that one failure
---does not abort the batch, matching `vim._async.join`.
---@async
---@param max_jobs integer
---@param funs (async fun(): nil)[]
---@return nil
local function join(max_jobs, funs)
  if #funs == 0 then
    return
  end
  local semaphore = async.semaphore(math.min(max_jobs, #funs))
  local tasks = vim
    .iter(funs)
    :map(function(fun)
      -- Each closure hands its result up so the batch stays a plain value
      -- pipeline; `pawait` below discards it.
      return async.run(function()
        return semaphore:with(function()
          -- `with` declares a variadic `R...` return, which LuaLS cannot
          -- unify with the plain `boolean` that `pcall` yields for a
          -- `fun(): nil`. `vim/async/_semaphore.lua` silences the same class
          -- of diagnostic for the same reason.
          ---@diagnostic disable-next-line: return-type-mismatch
          return copcall(fun)
        end)
      end)
    end)
    :totable()
  vim.iter(tasks):each(function(task)
    async.pawait(task)
  end)
end

return setmetatable({ join = join }, { __index = async }) --[[@as CmpGhqAsync]]
