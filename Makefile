NVIM ?= nvim

.PHONY: test
test:
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"
