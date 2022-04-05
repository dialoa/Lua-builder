--[[-- # Lua-builder - a simple builder to combine Lua source files

Searches requires commands with an input.lua file and
replace them with their source.

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2022 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.1

]]
local options = {
	verbosity = 2,
	source = nil,
	output = nil,
}
--- options:parsarg: parse command line arguments
function options:parsearg()
	local flag
	for i=1, #arg do
		-- process flags with argument
		if flag then 
			if flag == '-o' or flag == '--output' then
				self.output = arg[i]
			end 
			flag = false
		-- identify flags
		elseif arg[i]:match('^%-%g') or arg[i]:match('^%-%-%g+') then
			if arg[i] == '-v' or arg[i] == '--verbose' then
				self.verbosity = 1
			elseif arg[i] == '-q' or arg[i] == '--quiet' then
				self.verbosity = 3
			else -- other flags need one argument, so we store them 
				flag = arg[i]
			end
		-- main argument
		else
			self.source = arg[i]
		end
	end
end

--- message: display message on stderror
-- levels: 1 info, 2 warning, 3 error
local function message(level,str)
	local heading = {
		'Lua builder info: ',
		'Lua builder warning: ',
		'Lua builder error: ',
	}
	if level >= options.verbosity then
		io.stderr:write(heading[level]..str..'\n')
	end
end

--- find_module: find module file and return its contents
--@param module string module name
--@param paths list of paths to search
local function find_module(module, paths)
	local contents
	
	for _,path in ipairs(paths) do
		local f = io.open(path..module..'.lua', 'r')
		if f then
			contents = f:read('a')
			f:close()
			-- add final newline if needed
			if not contents:match('\n$') then 
				contents = contents..'\n'
			end
			return contents
		end
	end

	return nil
end

-- parse arguments
options:parsearg()

-- read source file
if options.source then
	options.sourcepath, options.source = string.match(options.source, "(.-)([^\\/]-%.?[^%.\\/]*)$")
else
	message(3,'No source file specified. Usage: build.lua path/to/source.lua [-o output.lua] [-v] [-q].')
	return 
end
message(0, 'Looking for source file '..options.sourcepath..options.source..'.')
local f = io.open(options.sourcepath..options.source, 'r')
if not f then
	message(3, 'Source file '..options.sourcepath..options.source..' not found.')
	return 
end
local contents = f:read('a')
f:close()

-- search for require lines in the source file
local searching = true
local result = ''
local pattern = '[%w_]+%s*=%s*require%s*%b()'
while searching do
	-- need to try beginning of string and after each newline
	i,j = contents:find('^[%s\t]*'..pattern..'[%s\t]*[\n]')
	if not i then
		i,j = contents:find('[\n\r][%s\t]*'..pattern..'[%s\t]*[\n]')
		-- add 1 to keep the newline
		if i then i = i + 1 end
	end
	-- if require line found, try to import the module's content
	if i then
		local module = contents:sub(i,j)
										:gsub(".*require%s*%(%s*'",'')
										:gsub("'%)[%s\t]*[\n]$",'')
		message(1,'Looking for module '..module..'.')

		local module_contents = find_module(module, {'', options.sourcepath})

		if module_contents then
			message(1,'Importing module '..module..'.')
			result = result .. contents:sub(1,i-1) .. module_contents
			contents = contents:sub(j+1,-1)
		else
			message(2,'Module '..module..' not found.')
			result = result..contents:sub(1,j)
			contents = contents:sub(j+1,-1)
		end

	else
		result = result..contents
		searching = false
	end
end

-- output the result
if options.output then
	local f = io.open(options.output, 'w')
	if not f then
		message(3,'Could not write file '..options.output..': permission denied.')
		return 
	end
	f:write(result)
	f:close()
else
	io.stdout:write(result)
end