-- Neovim promoted its coroutine-based async runtime from the private
-- `vim._async` to the public `vim.async`. `run` and `await` keep the
-- signatures this plugin relies on, but `vim.async` dropped `join` in favour
-- of `vim.async.semaphore`, so reimplement it here. Prefer the public module
-- and fall back to the private one on older versions.

if not vim.async then
  return require "vim._async"
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
      return async.run(function()
        semaphore:with(function()
          copcall(fun)
        end)
      end)
    end)
    :totable()
  vim.iter(tasks):each(function(task)
    async.pawait(task)
  end)
end

return setmetatable({ join = join }, { __index = async })
