# cmp-ghq

[![CI](https://github.com/delphinus/cmp-ghq/actions/workflows/ci.yml/badge.svg)](https://github.com/delphinus/cmp-ghq/actions/workflows/ci.yml)

Completion source for [ghq][] — works with both [nvim-cmp][] and [blink.cmp][].

[nvim-cmp]: https://github.com/hrsh7th/nvim-cmp
[blink.cmp]: https://github.com/Saghen/blink.cmp
[ghq]: https://github.com/x-motemen/ghq

## Requirements

* Neovim v0.12.0 or newer (uses `vim.async` internally, falling back to the
  private `vim._async` on versions that predate it)
* `ghq` and `git` on `$PATH`

## Setup

### With nvim-cmp

```lua
{
  "hrsh7th/nvim-cmp",
  dependencies = { "delphinus/cmp-ghq" },
  opts = function(_, opts)
    table.insert(opts.sources, { name = "ghq" })
  end,
}
```

### With blink.cmp

```lua
{
  "saghen/blink.cmp",
  dependencies = { "delphinus/cmp-ghq" },
  opts = {
    sources = {
      default = { "ghq" },
      providers = {
        ghq = {
          name = "ghq",
          module = "blink-cmp-ghq",
          -- `ghq list -p` and the per-repo `git remote -v` lookups can take
          -- tens of milliseconds. Mark the provider async so blink.cmp shows
          -- results from cheaper sources (buffer, snippets, etc.) immediately
          -- and merges ghq candidates in as they arrive.
          async = true,
        },
      },
    },
  },
}
```

## Options

| key                  | default     | description                                        |
| -------------------- | ----------- | -------------------------------------------------- |
| `concurrency`        | `5`         | Max concurrent `git remote -v` lookups.            |
| `ghq`                | `"ghq"`     | Path to the `ghq` executable.                      |
| `git`                | `"git"`     | Path to the `git` executable.                      |
| `keyword_pattern`    | `[[\w\+]]`  | Pattern that triggers completion (nvim-cmp only).  |
| `trigger_characters` | `{}`        | Trigger characters. Set e.g. `{ "." }` to fire after a dot. |

For nvim-cmp, pass these under `option` of the source spec. For blink.cmp, pass them as the provider's `opts`.

## Development

Tests use [mini.test][]. The first run fetches it into `tests/deps/`
(gitignored).

```sh
make test       # fetch deps if needed, then run all tests headless
make deps       # just fetch test deps
make lint       # lua-language-server --check against .luarc.json
make fmt        # run stylua on lua/ and tests/
make fmt-check  # check formatting without rewriting
```

All three run in CI, `test` and `lint` against Neovim v0.12.0, `stable`
and `nightly`.

Each target looks for its tool on `$PATH`; override with `NVIM`, `LUALS`
or `STYLUA` if it lives elsewhere:

```sh
NVIM=/path/to/nvim make test
LUALS=~/.local/share/nvim/mason/bin/lua-language-server make lint
STYLUA=~/.local/share/nvim/mason/bin/stylua make fmt
```

`make lint` asks `$(NVIM)` for its `$VIMRUNTIME` and hands it to
lua-language-server, which `.luarc.json` references as the library path —
so the result reflects whichever Neovim you point it at. `luacheck` is
not used: lua-language-server covers the same ground (`.luarc.json`
raises `unused-local`, `unused-function`, `unused-vararg` and
`lowercase-global` to warnings) and adds type and annotation checking on
top.

[mini.test]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md
