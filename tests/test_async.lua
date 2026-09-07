local async = require "cmp_ghq.async"

-- `join` is the one entry point whose implementation differs between the two
-- backends (`vim.async` dropped it, so cmp_ghq.async rebuilds it on top of
-- `vim.async.semaphore`). These specs pin down the contract both must honour:
-- every fun runs, no more than `max_jobs` are ever in flight, and a fun that
-- raises does not abort the batch.
--
-- The two differ in ways the specs deliberately do not assert: which queued
-- fun is picked up next, and whether it starts synchronously (`vim._async`)
-- or on the next event loop tick (`vim.async`).

-- Build `n` funs that park their resume callback in `pending` instead of
-- touching libuv, and track how many are running at once.
---@param n integer
---@param fails? table<integer, true> indices whose fun raises instead of finishing
local function new_jobs(n, fails)
  local jobs = { funs = {}, pending = {}, started = 0, in_flight = 0, max_in_flight = 0, finished = {} }
  for i = 1, n do
    jobs.funs[i] = function()
      jobs.started = jobs.started + 1
      jobs.in_flight = jobs.in_flight + 1
      jobs.max_in_flight = math.max(jobs.max_in_flight, jobs.in_flight)
      async.await(1, function(cb)
        table.insert(jobs.pending, cb)
      end)
      jobs.in_flight = jobs.in_flight - 1
      if fails and fails[i] then
        error("boom " .. i, 0)
      end
      table.insert(jobs.finished, i)
    end
  end
  function jobs:resolve_next()
    local cb = assert(table.remove(self.pending, 1), "no pending job to resolve")
    cb()
  end
  return jobs
end

-- Resolve parked jobs until `join` returns, pumping the event loop in between
-- so the backend that defers queued jobs to the next tick can make progress.
---@param jobs table
---@param is_done fun(): boolean
local function drain(jobs, is_done)
  vim.wait(2000, function()
    if not is_done() and #jobs.pending > 0 then
      jobs:resolve_next()
    end
    return is_done()
  end, 1)
end

local T = MiniTest.new_set()

T["join keeps at most max_jobs in flight and runs them all"] = function()
  local jobs = new_jobs(5)
  local done = false
  async.run(function()
    async.join(2, jobs.funs)
    done = true
  end)

  -- Only max_jobs may start before anything completes.
  MiniTest.expect.equality(jobs.started, 2)

  drain(jobs, function()
    return done
  end)

  MiniTest.expect.equality(done, true)
  MiniTest.expect.equality(jobs.max_in_flight, 2)
  MiniTest.expect.equality(jobs.started, 5)
  table.sort(jobs.finished)
  MiniTest.expect.equality(jobs.finished, { 1, 2, 3, 4, 5 })
end

T["join with fewer funs than max_jobs starts them all at once"] = function()
  local jobs = new_jobs(2)
  local done = false
  async.run(function()
    async.join(5, jobs.funs)
    done = true
  end)

  MiniTest.expect.equality(jobs.started, 2)

  drain(jobs, function()
    return done
  end)

  MiniTest.expect.equality(done, true)
  MiniTest.expect.equality(jobs.max_in_flight, 2)
end

T["join returns immediately on an empty list"] = function()
  local done = false
  async.run(function()
    async.join(5, {})
    done = true
  end)
  MiniTest.expect.equality(done, true)
end

T["join swallows a failing fun and still finishes the batch"] = function()
  local jobs = new_jobs(4, { [2] = true })
  local done = false
  async.run(function()
    async.join(2, jobs.funs)
    done = true
  end)

  drain(jobs, function()
    return done
  end)

  MiniTest.expect.equality(done, true)
  MiniTest.expect.equality(jobs.started, 4)
  -- Every job but the failing one recorded a result.
  table.sort(jobs.finished)
  MiniTest.expect.equality(jobs.finished, { 1, 3, 4 })
end

return T
