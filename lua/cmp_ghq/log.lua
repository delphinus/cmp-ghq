return {
  ---@param fmt string
  ---@param ... any
  ---@return nil
  debug = function(fmt, ...)
    local ok, debug = pcall(require, "cmp.utils.debug")
    if ok then
      debug.log(("[cmp-ghq] " .. fmt):format(...))
    end
  end,
}
