-- # Main module

-- modules
module_1 = {
	output = 'Module 1 says hello'
}

module_2 = { 
	output = 'Module 2 says hello'
}
module_3 = { 
	output = 'Module 3 says hello'
}
-- end modules
-- main code
print(module_1.output, module_2.output, module_3.output)
