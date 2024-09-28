local config = require "cmp_ghq.config"
local async = require "plenary.async"

---@class CmpGhqCacheEntry
---@field dir string
---@field timestamp integer

---@class CmpGhqCache
---@field filename string
---@field entries table<string, CmpGhqCacheEntry>
---@field saved boolean
local Cache = {}

Cache.new = function()
  return setmetatable({ entries = {}, saved = false }, { __index = Cache })
end

---@async
---@return nil
function Cache:load()
  local err, stat = async.uv.fs_stat(config.cache_filename)
  if err then
    return self:log("cache file not found: %s", err)
  end
  local fd
  err, fd = async.uv.fs_open(config.cache_filename, "r", tonumber("644", 8))
  assert(not err, err)
  local data
  err, data = async.uv.fs_read(fd, stat.size)
  assert(not err, err)
  assert(not async.uv.fs_close(fd))
  local entries = vim.F.npcall(loadstring(data or ""))
  if entries then
    self.entries = entries
  end
end

---@async
---@return nil
function Cache:save()
  local f = assert(load("return " .. vim.inspect(self.entries)))
  local data = string.dump(f)
  local err, fd = async.uv.fs_open(config.cache_filename, "w", tonumber("644", 8))
  assert(not err, err)
  assert(not async.uv.fs_write(fd, data))
  assert(not async.uv.fs_close(fd))
end

function Cache:log(fmt, ...)
  require("cmp.utils.debug").log(fmt:format(...))
end

return setmetatable({}, {
  __index = function(self, key)
    if not self.cache then
      self.cache = Cache.new()
    end
    if key == "load" then
      self:load()
    elseif key == "save" then
      self:load()
    end
  end,
})
