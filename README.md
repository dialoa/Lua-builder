# Lua-builder
 
 A crude builder to combine several Lua source files into one.

Requires a Lua interpreter installed. 

## Usage

```bash
lua lua-builder [path/to/source.lua] [-o path/to/output] [-h] [-v] [-q]
```

The script searches through `source.lua` for lines of the form:

```lua
myvariable = require('module')
local myvariable = require('path/module')
```

And replaces them with the contents of the `module.lua` file, if found. 

Modules are assumed to be located relative
to the source file's path. For instance, if we run:

```bash
lua lua-builder src/source.lua -o output.lua
```

and `src/source.lua` contains:

```
myvariable = require('modpath/module') 
```

The script will look for `src/modpath/module.lua`. If found, it replaces the require line with the contents of the file.

## Recursive mode

With the `-r` or `--recursive` flag the script processes the imported files
too. 

## Warning

Imported files are copied/pasted in the source without modification.
They are not meant to be genuine Lua modules. Thus if your source contains:

```lua
myvariable = require('module')
```

Do not expect `myvariable` to exist after the document is built, unless 
the `module.lua` file sets it. If your imported file ends with:

```lua
return module_table
```

This will probably not work once imported. 

To build a combined file from genuine Lua modules you should use
[LuaCC](https://luarocks.org/modules/mihacooper/luacc) instead.
