local uv = vim.loop

---@alias cmp_ghq.ghq.RawLogger fun(msg: string, level: integer): nil

---@class cmp_ghq.log.Opts
---@field raw_logger cmp_ghq.ghq.RawLogger?
---@field debug boolean?

---@class cmp_ghq.log.Config
---@field raw_logger cmp_ghq.ghq.RawLogger
---@field debug boolean

---@class cmp_ghq.logger.Logger
---@field count integer
---@field config cmp_ghq.log.Config
---@field started integer
local Logger = {}

---@type cmp_ghq.log.Opts
local default_options = {
  raw_logger = vim.schedule_wrap(vim.notify),
  debug = false,
}

---@param opts cmp_ghq.log.Opts
---@return cmp_ghq.logger.Logger
Logger.new = function(opts)
  return setmetatable(
    { count = 0, config = vim.tbl_extend("force", default_options, opts or {}), started = uv.hrtime() },
    { __index = Logger }
  )
end

---@param fmt string
---@param args any[]
---@param level integer
function Logger:log(fmt, args, level)
  local inspected = vim.iter.map(function(v)
    return type(v) == "table" and vim.inspect(v, { indent = "", newline = "" }) or v
  end, args)
  local now = (uv.hrtime() - self.started) / 1000000000
  self.count = self.count + 1
  self.config.raw_logger(("[cmp-ghq] %d (%.3f) " .. fmt):format(self.count, now, unpack(inspected)), level)
end

---@param fmt string
---@param ... any
function Logger:info(fmt, ...)
  self:log(fmt, { ... }, vim.log.levels.INFO)
end

---@param fmt string
---@param ... any
function Logger:debug(fmt, ...)
  if self.config.debug then
    self:log(fmt, { ... }, vim.log.levels.DEBUG)
  end
end

---@param fmt string
---@param ... any
function Logger:warn(fmt, ...)
  self:log(fmt, { ... }, vim.log.levels.WARN)
end

---@param fmt string
---@param ... any
function Logger:error(fmt, ...)
  self:log(fmt, { ... }, vim.log.levels.ERROR)
end

return Logger
