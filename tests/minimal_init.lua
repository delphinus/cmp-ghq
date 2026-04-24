-- Minimal init for `make test`. Adds the plugin and mini.nvim (just for
-- mini.test) to the runtimepath, then bootstraps mini.test.

vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend "tests/deps/mini.nvim"

require("mini.test").setup {
  collect = {
    -- Only pick up our own tests, not mini.nvim's own suite under tests/deps/.
    find_files = function()
      return vim.fn.globpath("tests", "test_*.lua", true, true)
    end,
  },
}
