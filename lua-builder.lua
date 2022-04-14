--[[-- # Lua-builder - A simple builder to combine Lua source files

Searches `requires` commands within an input file and
replace them with their source.

Usage lua lua-builder source.lua [-o,--output output.lua] [-r, --recursive]

More info <https://github.com/jdutant/Lua-builder>.

@author Julien Dutant <julien.dutant@kcl.ac.uk>
@copyright 2022 Julien Dutant
@license MIT - see LICENSE file for details.
@release 0.4

]]
Builder = {
	verbosity = 2,
	recursive = true,
	strict = false,
	sourcepath = '',
	outputfile = nil,
	source = nil, -- source text, from sourcefile or stdin
	help_message = [[A simple builder to combine several Lua source files into one. 

Usage: lua lua-builder sourcepath/to/source [-o outpath/to/output] [-n] [-h] [-v] [-q]

Replace lines of the form 'input filepath/to/filename' with the contents
of filename (or filename.lua) located at `sourcepath/to/filepath/to/filename`.
See <https://github.com/jdutant/Lua-builder> for details.

source              source file to be scanned
-o, --output file   save the result in an output file
-n, --no-recursion	do not process imported files
-s, --strict				strict filenames, not looking for `<filename>.lua`
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
			if arg[i] == '-n' or arg[i] == '--no-recursion' then
				arguments.recursive = false
			elseif arg[i] == '-s' or arg[i] == '--strict' then
				arguments.strict = true
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
		os.exit(1)
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

---find_input_line: find the first `input` line in text
--@return i number index in `text` where the line begins
--@return j number index in `text` where the line ends
--@return match str filepath found in the input line between `input` and EOL or --
function Builder:find_input_line(text)

	-- find the first line beginning with 'input'
	local line_beginings = {'^[%s\t]*', '[\n\r][%s\t]*',
		'^[%s\t]*%-%-', '[\n\r][%s\t]*%-%-',
	}
	local line_endings = {'.-[\n]', '.-$'}
	local pattern = '!input'
	local firstpos,lastpos
	for _,begining in ipairs(line_beginings) do
		for _,ending in ipairs(line_endings) do
			firstpos,lastpos = text:find(begining..pattern..ending)
			if firstpos then break end
		end
		if firstpos then break end
	end
	
	-- if nothing found, return
	if not firstpos then return end

	-- get the line, trim out '...!input...'
	local line = text:sub(firstpos,lastpos)
	local i,j = line:find(pattern..'[%s%t]*')
	-- remove beginning up to the pattern and following spaces
	line = line:sub(j+1,-1)
	-- looking for quote patterns, 
	--  i.e. smallest set of arbitrary chars between matching quotes
	local quote_patterns = { "^'.-'", '^".-"'}
	i,j = nil,nil
	for _,quote_pattern in ipairs(quote_patterns) do
		i,j = line:find(quote_pattern)
		if i and i+1 < j-1 then
			filepath = line:sub(i+1,j-1)
			return firstpos, lastpos, filepath
		end
	end
	-- otherwise match a string of non-space chars
	i,j = line:find("^%g+")
	if i then
		filepath = line:sub(i,j)
		return firstpos, lastpos, filepath
	end

	return

end

function Builder:find_require_line(text)
	-- pattern: '<variable_name[.subfield[.subfield] = require('<module_name>')\n'
	-- variable name starts with alphanumeric or _, optionally 
	-- followed by alphanum, underscores and dots.
	-- end is the rest of the line, up to newline or end of string.
	local pattern = '[%w_][%w_%.]*%s*=%s*require%s*(%b())'
	local wrappers = {
		'^[%s\t]*', '[\n\r][%s\t]*', 
		'^[%s\t]*local[%s\t]*', '[\n\r][%s\t]*local[%s\t]*'

	}
	local endwrappers = {
		'.-[\n]', '.-$'
	}
	local i,j
	for _,wrapper in ipairs(wrappers) do
		for __,endwrapper in ipairs(endwrappers) do
			i,j = text:find(wrapper..pattern..endwrapper)
			if i then break end
		end
		if i then break end
	end

	-- if found, extract module name
	if not i then
		return
	else
		-- get the content within matching brackets
		local match
		for _,wrapper in ipairs(wrappers) do
			for __,endwrapper in ipairs(endwrappers) do
				match = text:sub(i,j):match(wrapper..pattern..endwrapper)
				if match then break end
			end
			if match then break end
		end
		-- get the string between matching quotes and remove them
		match = match:match("%b''") or match:match('%b""')
		if match then
			match = match:sub(2,-2)
		end
		-- return result if we have one
		if match and match ~= '' then 
			return i,j,match
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
		-- try .lua first unless `--strict` flag is set
		local f
		if not self.strict then
			f = io.open(path..modpath..modname..'.lua', 'r')
		end
		if not f then
			f = io.open(path..modpath..modname, 'r')
		end
		if f then
			fcontents = f:read('a')
			f:close()
			-- add beginning and final newline if needed
			if not fcontents:match('^[\n\r]') then
				fcontents = '\n'..fcontents
			end
			if not fcontents:match('[\n\r]$') then 
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
		local i,j,module = self:find_input_line(input)

		if module then
			local name = self.strict and self.sourcepath..module
									or self.sourcepath..module..'[.lua]'
			self:message(1,'Looking for file '..name)
			local module_contents, module_path = self:find_module(module, {self.sourcepath})

			if module_contents then
				self:message(1,'Importing module '..module..'.')

				-- if recursive mode, create a builder to process the imported contents
				if self.recursive then
					local newbuilder = Builder:new({
																verbosity = self.verbosity,
																strict = self.strict,
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
				self:message(2,'File '..module..'.lua not found.')
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