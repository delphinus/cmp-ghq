.PHONY: test deps fmt fmt-check

MINI_NVIM := tests/deps/mini.nvim
STYLUA ?= stylua

deps: $(MINI_NVIM)

$(MINI_NVIM):
	@mkdir -p tests/deps
	@git clone --depth=1 https://github.com/echasnovski/mini.nvim $(MINI_NVIM)

test: deps
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua MiniTest.run()"

fmt:
	@$(STYLUA) lua/ tests/

fmt-check:
	@$(STYLUA) --check lua/ tests/
