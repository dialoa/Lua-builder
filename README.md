# Lua-builder
 
 A simple builder to combine several Lua source files into one.

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

And replaces them with the contents of the `module.lua` file, if
found. See [Import line syntax](#import-line-syntax) below for more detail on how to
format import lines. The contents of `module.lua` are copied/pasted
as they are, without modification. This will not work with genuine
Lua modules that return a table. See [Warning](#warning) below.

Modules are assumed to be located relative to the source file's path.
For instance, if we run:

```bash
lua lua-builder src/source.lua -o output.lua
```

and `src/source.lua` contains:

```lua
myvariable = require('modpath/module') 
```

The script will look for `src/modpath/module.lua`. If found, it
replaces the require line with the contents of the file.

## Recursive mode

With the `-r` or `--recursive` flag the script processes the imported
files too. Paths should be relative to the imported file. If the main
file includes:

```lua
var = require('mods/module')
```

and `mods/module.lua` includes:

```lua
var = require('helpers/submodule')
```

the script attempts to import `<sourcepath>mods/helpers/submodule.lua`
into `<sourcepath>mods/module.lua` before importing the latter into
the main file.

## Import line syntax

To trigger an import, a line must have the form:

```lua
    [local] <variablename> = require ( '<module>' )
```

The line may start with spaces or tabs and the `local` keyword.

`<variablename>` should be a standard Lua variable name, starting
with a underscore or alphanumeric, followed by underscores, alphanumeric
and dots. Index notation (`[...]`) isn't allowed.

```lua
-- Good
myvariable = require('module')
my_var.subfield.subsub = require("module")
-- Bad
myvar[index] = require('module')
!my!var = require('module')
```

The variable name and `require` command must be separated by `=` surrounded
by any number of spaces (no tabs). The `require` command must uses 
brackets and `'` or `''` quotes. 

```lua
-- Good
myvar = require('module')
myvar = require("module")
-- Bad
myvar = require 'module'
myvar = require(module)
```

The entire line will be replaced, including anything after the `require`
command. So comments can be included:

```lua
myvar = require('module') -- to be replaced by module.lua
```

## Troubleshooting

### Warning

Imported files are copied/pasted in the source without modification.
They are not meant to be genuine Lua modules. Thus if your source contains:

```lua
myvariable = require('module')
```

Do not expect `myvariable` to exist after the combined file is built, unless 
the `module.lua` file sets it. If your imported file ends with:

```lua
return module_table
```

This will most likely not work once imported. 

To build a combined file from genuine Lua modules you should use
[LuaCC](https://luarocks.org/modules/mihacooper/luacc) instead.

### Do not include `.lua` in the module name

Do not include '.lua' in the module name. The following:

```lua
myvariable = require('module.lua') 
```

will look for `module.lua.lua` and probably not find it.

### Use verbose mode

If you're not sure about what the script is trying to import,
use the verbose mode.

```bash
lua lua-builder main.lua -o result.lua --verbose
```
