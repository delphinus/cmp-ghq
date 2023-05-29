local ghq

return {
  ghq = function()
    return ghq
  end,

  setup = function(overrides)
    local Source = require "cmp_ghq.source"
    ghq = Source.new(overrides)
    require("cmp").register_source("ghq", ghq)
  end,
}
