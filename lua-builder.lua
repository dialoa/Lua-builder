--[[-- # Lua-builder - A crude builder to combine Lua source files

Searches `requires` commands within an input file and
replace them with their source.

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2022 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.2

]]
Builder = {
	verbosity = 2,
	recursive = false,
	sourcepath = '',
	outputfile = nil,
	source = nil, -- source text, from sourcefile or stdin
	help_message = [[A simple builder to combine several Lua source files into one. 

Usage: lua lua-builder path/to/input [-o path/to/output] [-h] [-v] [-q]

input               input file to be scanned
-o, --output file   save the result in an output file
-r, --recursive			recursive mode
-q, --quiet         quiet mode
-v, --verbose       verbose mode
-h, --help          this help message

]]
}
--- new: create a new builder object based on options
function Builder:new(options) 

		o = {}
		self.__index = self 
		setmetatable(o, self)

		-- if no options provided, get them from the command line
		options = options or self:parsearg()

		for key,value in pairs(options) do
			o[key] = value
		end

		return o

end
--- message: display message on stderror
-- levels: 1 info, 2 warning, 3 error
function Builder:message(level,str)
	local heading = {
		'Lua builder info: ',
		'Lua builder warning: ',
		'Lua builder error: ',
	}
	if level >= self.verbosity then
		io.stderr:write(heading[level]..str..'\n')
	end
end
--- splitpath: split a filepath into path and filename
function Builder:splitpath(filepath)
	local path, filename = string.match(filepath,"(.-)([^\\/]-%.?[^%.\\/]*)$")
	return path, filename
end
--- parsearg: parse command line arguments
-- return them as a table
function Builder:parsearg()

	local arguments = {}
	function add_arg(key,value) 
		if not arguments[key] then 
			arguments[key] = value
		elseif type(arguments[key]) == 'table' then
			table.insert(arguments[key], value)
		else
			arguments[key] = {arguments[key], value}
		end
	end

	local flag
	for i=1, #arg do
		-- process flags with 1 argument
		if flag then 
			if flag == '-o' or flag == '--output' then
				add_arg('outputfile', arg[i])
			end 
			flag = false
		-- identify flags
		elseif arg[i]:match('^%-%g') or arg[i]:match('^%-%-%g+') then
			if arg[i] == '-r' or arg[i] == '--recursive' then
				arguments.recursive = true
			elseif arg[i] == '-h' or arg[i] == '--help' then
				arguments.help = true
			elseif arg[i] == '-v' or arg[i] == '--verbose' then
				arguments.verbosity = 1
			elseif arg[i] == '-q' or arg[i] == '--quiet' then
				arguments.verbosity = 3
			else -- other flags need one argument, so we store them 
				flag = arg[i]
			end
		-- main argument
		else
				add_arg('sourcefile', arg[i])
		end
	end

	-- process arguments
	-- help
	if arguments.help then 
		io.stderr:write(Builder.help_message)
		io.exit()
	end

	-- source
	if not arguments.sourcefile then
		-- read from stdin
		arguments.source = io.read("*a")
		arguments.sourcepath = ''
	else
		-- check that only one source is provided
		if type(arguments.sourcefile) == 'table' then
			self:message(2,'Several sources specified. This is not allowed, we only process the first.'
				..' Use `-h` for help.')
			arguments.sourcefile = arguments.sourcefile[1]
		end
		-- split source into path and filename
		arguments.sourcepath, arguments.sourcefile = self:splitpath(arguments.sourcefile)
		-- try read from file
		local f = io.open(arguments.sourcepath..arguments.sourcefile, 'r')
		if not f then
			self:message(3, 'Source file '..arguments.sourcepath..arguments.sourcefile..' not found.')
			return 
		end
		arguments.source = f:read('a')
		f:close()
	end

	-- check that only one output is provided
	if arguments.outputfile then
		if type(arguments.outputfile) == 'table' then
			self:message(2,'Several outputs specified. This is not allowed, we only write the first.'
				..' Use `-h` for help.')
			arguments.outputfile = arguments.outputfile[1]
		else
			arguments.outputfile = arguments.outputfile
		end
	end

	return arguments

end
--- find_require_line: find the first `require` line in text
function Builder:find_require_line(text)
	local pattern = '[%w_]+%s*=%s*require%s*%b()'
	-- try at start of file and after each newline

	-- try with or without `local`
	i,j = text:find('^[%s\t]*'..pattern..'[%s\t]*[\n]')
	if not i then
		i,j = text:find('[\n\r][%s\t]*local[%s\t]*'..pattern..'[%s\t]*[\n]')
	end
	if not i then
		i,j = text:find('[\n\r][%s\t]*'..pattern..'[%s\t]*[\n]')
		-- add 1 to keep the newline
		if i then i = i + 1 end
	end
	if not i then
		i,j = text:find('[\n\r][%s\t]*local[%s\t]*'..pattern..'[%s\t]*[\n]')
		-- add 1 to keep the newline
		if i then i = i + 1 end
	end

	-- if found, extract module name
	if not i then
		return
	else
		module_name = text:sub(i,j)
										:gsub(".*require%s*%(%s*'",'')
										:gsub("'%)[%s\t]*[\n]$",'')
		if module_name then
			return i,j,module_name
		end
	end

end
--- find_module: find a module file and return its contents
--@param module string module name
--@param paths list of paths to search
--@return fcontents string the file's contents
--@return modpath the module's path (for recursive mode)
function Builder:find_module(module, paths)
	local fcontents

	local modpath, modname = self:splitpath(module)
	
	for _,path in ipairs(paths) do
		local f = io.open(path..modpath..modname..'.lua', 'r')
		if f then
			fcontents = f:read('a')
			f:close()
			-- add final newline if needed
			if not fcontents:match('\n$') then 
				fcontents = fcontents..'\n'
			end
			return fcontents, path..modpath
		end
	end

	return nil
end
--- build: replace input's 'require' lines with module contents
function Builder:build()

	local input = self.source
	local result = ''

	-- search for require lines in the source file
	local search_in_progress = true
	while search_in_progress do
		local i,j,module = self:find_require_line(input)

		if module then
			self:message(1,'Looking for module '..module..'.')
			local module_contents, module_path = self:find_module(module, {self.sourcepath})

			if module_contents then
				self:message(1,'Importing module '..module..'.')

				-- if recursive mode, create a builder to process the imported contents
				if self.recursive then
					local newbuilder = Builder:new({
																verbosity = self.verbosity,
																recursive = true,
																sourcepath = module_path,
																resultfile = nil,
																source = module_contents,
															})
					module_contents = newbuilder:build()
				end
				-- place the beginning of `input` up to the require line, 
				-- followed by module contents, in result
				result = result .. input:sub(1,i-1) .. module_contents
				-- take out the beginning of `input` and the require line
				input = input:sub(j+1,-1)
			else
				self:message(2,'Module '..module..' not found.')
				result = result..input:sub(1,j)
				input = input:sub(j+1,-1)
			end

		else -- no require line found, end search
			result = result..input
			search_in_progress = false
		end
	end

	return result
end
--- write: output the built file
function Builder:output()

	local output = self:build()

	if output then

		if self.outputfile then
			local f = io.open(self.outputfile, 'w')
			if not f then
				self:message(3,'Could not write file '..self.outputfile..': permission denied.')
				return 
			end
			f:write(output)
			f:close()
		else
			io.stdout:write(output)
		end

	end
end

builder = Builder:new()
builder:output()