.PHONY: test deps fmt fmt-check lint

MINI_NVIM := tests/deps/mini.nvim
NVIM ?= nvim
STYLUA ?= stylua
LUALS ?= lua-language-server

deps: $(MINI_NVIM)

$(MINI_NVIM):
	@mkdir -p tests/deps
	@git clone --depth=1 https://github.com/echasnovski/mini.nvim $(MINI_NVIM)

test: deps
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua \
		-c "lua MiniTest.run()"

# lua-language-server resolves Neovim's own annotations out of $VIMRUNTIME,
# which .luarc.json references, so ask the nvim being used where that is.
lint:
	@VIMRUNTIME="$$($(NVIM) --headless --clean -c 'lua io.write(vim.env.VIMRUNTIME)' -c q 2>/dev/null)" \
		$(LUALS) --check . --configpath=.luarc.json --checklevel=Warning \
		--logpath=tests/deps/luals

fmt:
	@$(STYLUA) lua/ tests/

fmt-check:
	@$(STYLUA) --check lua/ tests/
