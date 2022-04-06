LUA_FILES = $(filter-out output.lua,$(wildcard *.lua))

all: output.lua

output.lua: $(LUA_FILES) ../lua-builder.lua
	@echo Combining main.lua and its modules into output.lua
	@lua ../lua-builder.lua main.lua -o output.lua --recursive
	@echo Running the combined script:
	@lua output.lua
