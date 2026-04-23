local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.register_source("ghq", require "cmp_ghq")
end
