return {
  ---@param fmt string
  ---@param ... any
  ---@retunr nil
  debug = function(fmt, ...)
    require("cmp.utils.debug").log(("[cmp-ghq] " .. fmt):format(...))
  end,
}
