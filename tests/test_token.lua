local Token = require("cmp_ghq.ghq")._Token

local T = MiniTest.new_set()

T["new token starts uncancelled"] = function()
  local tok = Token.new()
  MiniTest.expect.equality(tok:is_cancelled(), false)
end

T["cancel flips state to true"] = function()
  local tok = Token.new()
  tok:cancel()
  MiniTest.expect.equality(tok:is_cancelled(), true)
end

T["cancel is idempotent"] = function()
  local tok = Token.new()
  tok:cancel()
  tok:cancel()
  MiniTest.expect.equality(tok:is_cancelled(), true)
end

T["independent tokens do not share state"] = function()
  local a, b = Token.new(), Token.new()
  a:cancel()
  MiniTest.expect.equality(a:is_cancelled(), true)
  MiniTest.expect.equality(b:is_cancelled(), false)
end

return T
