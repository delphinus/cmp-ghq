local async = require "vim._async"

-- A controllable async_system replacement. Each call records its arguments
-- in `call_log` and parks the resume callback in `pending`; the test then
-- calls `fake:resolve(...)` to wake the next pending caller. Because every
-- step is synchronous (no libuv involvement) we never need vim.wait().
local function new_fake_async()
  local fake = { call_log = {}, pending = {} }
  fake.fn = function(cmd, opts)
    table.insert(fake.call_log, { cmd = vim.deepcopy(cmd), opts = vim.deepcopy(opts) })
    return async.await(1, function(cb)
      table.insert(fake.pending, cb)
    end)
  end
  function fake:resolve(ok, result)
    local cb = assert(table.remove(self.pending, 1), "fake: no pending call to resolve")
    cb(ok, result)
  end
  return fake
end

-- Inject the fake into package.loaded *before* (re)loading any module that
-- captures async_system as an upvalue, then return a freshly-loaded ghq module.
local function load_ghq_with_fake(fake)
  package.loaded["cmp_ghq.async_system"] = fake.fn
  package.loaded["cmp_ghq.git"] = nil
  package.loaded["cmp_ghq.ghq"] = nil
  require("cmp_ghq.config").set_from_opts {}
  return require "cmp_ghq.ghq"
end

local T = MiniTest.new_set()

T["_get_list coalesces concurrent callers into one spawn"] = function()
  local fake = new_fake_async()
  local M = load_ghq_with_fake(fake)
  local ghq = M._Ghq.new()

  local r1, r2
  async.run(function()
    r1 = ghq:_get_list()
  end)
  async.run(function()
    r2 = ghq:_get_list()
  end)

  MiniTest.expect.equality(#fake.call_log, 1)
  MiniTest.expect.equality(fake.call_log[1].cmd, { "ghq", "list", "-p" })

  fake:resolve(true, "github.com/foo/bar\n")

  MiniTest.expect.equality(r1, { ok = true, result = "github.com/foo/bar\n" })
  MiniTest.expect.equality(r2, { ok = true, result = "github.com/foo/bar\n" })
end

T["_get_root caches result so the second call does not spawn"] = function()
  local fake = new_fake_async()
  local M = load_ghq_with_fake(fake)
  local ghq = M._Ghq.new()

  local r1
  async.run(function()
    r1 = ghq:_get_root()
  end)
  fake:resolve(true, "/home/me/ghq\n")
  MiniTest.expect.equality(r1, "/home/me/ghq")
  MiniTest.expect.equality(#fake.call_log, 1)

  local r2
  async.run(function()
    r2 = ghq:_get_root()
  end)
  -- Second call must short-circuit synchronously: no new spawn, no pending.
  MiniTest.expect.equality(r2, "/home/me/ghq")
  MiniTest.expect.equality(#fake.call_log, 1)
  MiniTest.expect.equality(#fake.pending, 0)
end

T["cancel before result suppresses the callback"] = function()
  local fake = new_fake_async()
  local M = load_ghq_with_fake(fake)

  local called_with = "<not-called>"
  local cancel = M.start(function(r)
    called_with = r
  end)
  -- One pending spawn so far: `ghq root`.
  MiniTest.expect.equality(#fake.pending, 1)
  MiniTest.expect.equality(fake.call_log[1].cmd, { "ghq", "root" })

  cancel()
  fake:resolve(true, "/root\n") -- start() bails out at the first is_cancelled check

  MiniTest.expect.equality(called_with, "<not-called>")
  -- The cancelled coroutine never reaches `ghq list -p`.
  MiniTest.expect.equality(#fake.call_log, 1)
  MiniTest.expect.equality(#fake.pending, 0)
end

T["cancel of one start does not affect concurrent siblings"] = function()
  local fake = new_fake_async()
  local M = load_ghq_with_fake(fake)

  local r1, r2 = "<not-called>", "<not-called>"
  local cancel1 = M.start(function(r)
    r1 = r
  end)
  local _ = M.start(function(r)
    r2 = r
  end)

  cancel1()
  fake:resolve(true, "/root\n") -- both subscribers wake; cancelled one bails

  -- Live sibling proceeded to spawn `ghq list -p`; cancelled one stopped
  -- at the post-_get_root cancel check.
  MiniTest.expect.equality(#fake.call_log, 2)
  MiniTest.expect.equality(fake.call_log[2].cmd, { "ghq", "list", "-p" })

  fake:resolve(true, "/root/foo\n")

  MiniTest.expect.equality(r1, "<not-called>")
  MiniTest.expect.equality(r2 ~= "<not-called>" and r2 ~= nil, true)
  MiniTest.expect.equality(r2.isIncomplete, false)
  MiniTest.expect.equality(r2.items[1].label, "foo")
end

return T
