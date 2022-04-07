-- # Main module

-- modules
module_1.option = require('first.module') -- loads first.module.lua
module_2.option = require('more/second_mod_ule') -- loads another
-- end modules
-- main code
print(module_1.output, module_2.output, module_3.output)
