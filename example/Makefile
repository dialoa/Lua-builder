all: output.lua

output.lua: main.lua firstmodule.lua secondmodule.lua ../lua-builder.lua
	@echo Combining main.lua and its modules into output.lua
	@lua ../lua-builder.lua main.lua -o output.lua
	@echo Running the combined script
	@lua output.lua
