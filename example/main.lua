-- # Main module

-- modules
!input first.module -- loads first.module.lua
	--!input "more/second_mod_ule.lua" -- loads another
-- end modules
-- main code
print(module_1.output, module_2.output, module_3.output)
