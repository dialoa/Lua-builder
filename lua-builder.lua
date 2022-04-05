--[[-- # Lua-builder - a simple builder to combine Lua source files

Searches requires commands with an input.lua file and
replace them with their source.

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2022 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.1

]]

--- parsarg: parse command line arguments
local function parsearg()
	local flag, result = '', {}
	for i=1, #arg do
		-- process flags
		if flag ~= '' then 
			if flag == '-o' or flag == '--output' then
				result.output = arg[i]
			end 
			flag = ''
		-- identify flags
		elseif arg[i]:match('^%-%g') or arg[i]:match('^%-%-%g+') then
			flag = arg[i]
		-- main argument
		else
			result.source = arg[i]
		end
	end
	return result
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
local opt = parsearg()
if opt.source then
	opt.sourcepath, opt.source = string.match(opt.source, "(.-)([^\\/]-%.?[^%.\\/]*)$")
else
	io.stderr:write('No source file specified. Usage: build.lua path/to/source.lua -o output.lua\n')
	return 
end

-- read source file
local f = io.open(opt.sourcepath..opt.source, 'r')
if not f then
	io.stderr:write('File '..opt.sourcepath..opt.source..' not found.\n')
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
		local module = contents:sub(i,j):match("require%s*%(%s*'(.+)'%)")

		local module_contents = find_module(module, {'', opt.sourcepath})

		if module_contents then
			result = result .. contents:sub(1,i-1) .. module_contents
			contents = contents:sub(j+1,-1)
		else
			io.stderr:write('Module '..module..' not found.\n')
			result = result..contents:sub(1,j)
			contents = contents:sub(j+1,-1)
		end

	else
		result = result..contents
		searching = false
	end
end

-- output the result
if opt.output then
	local f = io.open(opt.output, 'w')
	if not f then
		io.stderr:write('Could not write file '..opt.output..': permission denied.\n')
		return 
	end
	f:write(result)
	f:close()
else
	io.stdout:write(result)
end