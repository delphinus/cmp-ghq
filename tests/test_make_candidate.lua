local Ghq = require("cmp_ghq.ghq")._Ghq

local T = MiniTest.new_set()

-- LSP CompletionItemKind.Folder = 19
local FOLDER = 19

---Build a stub LSP item with the same shape Ghq:make_candidate produces.
---@param label string
---@param doc string
---@return lsp.CompletionItem
local function item(label, doc)
  return { label = label, kind = FOLDER, documentation = doc }
end

T["multi-segment expands into part+suffix labels"] = function()
  local got = Ghq.make_candidate({}, "github.com/user/repo")
  MiniTest.expect.equality(got, {
    item("github.com", "github.com/user/repo"),
    item("github.com/user/repo", "github.com/user/repo"),
    item("user", "github.com/user/repo"),
    item("user/repo", "github.com/user/repo"),
    item("repo", "github.com/user/repo"),
  })
end

T["short part (len <= 2) is dropped from labels but suffix is kept"] = function()
  -- "ab" has length 2, so it never appears as a standalone label.
  local got = Ghq.make_candidate({}, "ab/foo")
  MiniTest.expect.equality(got, {
    item("ab/foo", "ab/foo"),
    item("foo", "ab/foo"),
  })
end

T["all-short parts produce only suffix labels"] = function()
  local got = Ghq.make_candidate({}, "x/y/z")
  MiniTest.expect.equality(got, {
    item("x/y/z", "x/y/z"),
    item("y/z", "x/y/z"),
  })
end

T["single segment of length > 2 returns just the label"] = function()
  local got = Ghq.make_candidate({}, "repo")
  MiniTest.expect.equality(got, { item("repo", "repo") })
end

T["single short segment returns nothing"] = function()
  -- "ab" alone: too short to be a label, no suffix to add either.
  local got = Ghq.make_candidate({}, "ab")
  MiniTest.expect.equality(got, {})
end

return T
