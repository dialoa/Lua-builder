# Lua-builder
 
 A simple builder to combine several Lua source files into one.

Requires a Lua interpreter installed. 

## Basic usage

```bash
lua lua-builder [path/to/source.lua] [-o path/to/output] [-n] [-h] [-v] [-q]
```

The script searches through `source.lua` for lines of the form:

```lua
!input filename
--!input 'filename.lua'
!input path/to/thirdfile -- a third file to read
```

And replaces them with the contents of the `filename.lua` file, if
found. If not found, it will try `filename`. Thus the second
line above will first look for `filename.lua.lua` then
`filename.lua`. See [Import line syntax]
(#import-line-syntax) below for more detail on how to format import
lines. 

The contents of `filename.lua` are imported as they
are, without modification. They replace the entire line, including 
anything after your filepath.

```lua
!input filepath the rest of this line is ignored
```

For legibility, though, I recommend adding `--` before any
comment at the end of your line.

File paths for imported files  are assumed to be relative to
the source file's path. For instance, if we run:

```bash
lua lua-builder src/source.lua -o output.lua
```

and `src/source.lua` contains:

```lua
input filepath/file
```

The script will look for `src/filepath/file.lua`. If found, it
replaces the require line with the contents of the file.

## Recursive mode

The script is recursive, that is, it processes the imported files too.
Paths are assumed to be relative to the imported file. 

For example, if the main file includes:

```lua
input mods/module
```

and `mods/module.lua` includes the line:

```lua
input helpers/submodule
```

the script attempts to import `<sourcepath>mods/helpers/submodule.lua`
into `<sourcepath>mods/module.lua` before importing the latter into
the main file.

You can disable recursion with the `-n` or `--no-recursion` option. 

## Mandatory, optional and deactivated imports

Import lines start with (spaces/tabs and) `!input` or `--!input`.

* `!input` is meant for necessary imports. If you run the source file
  without building it, they will generate errors. They're also more
  visible in syntax highlighting.
* `--!input` (two dashes, no space between them and `!input`) is for
  optional imports. The script will still import the files indicated
  at these lines. But if you can run the source file without building,
  these lines will simply be treated as comments.
* Any other way of commenting out an input line deactivates it, e.g.
  `-- !input`, `-- --!input`, `----!input` etc.

Illustration:

```lua
!input necessary_file -- necessary import, error if I run the unbuilt script
--!input optional_file -- optional import, doesn't generate an error
-- --!input third_file -- deactivated input line, won't import anything
```

*Warning*. Input lines in Lua multi-line comments aren't deactivated.
Example:

```lua 
--[[-- This multi-line Lua comment
contains an input line

!input somefile -- somefile.lua will be imported here

]]
```

## Linux pipes

The script can be used in pipes. It reads from stdin if no input file is
 provided and writes to stdout if no output file is provided.

## Import line syntax

To trigger an import, a line must have one of the forms below 
(the bracketed components are optional):

```lua
[spaces] !input spaces <filepath> [spaces] [-- comment]
[spaces] !input spaces '<filepath>' [spaces] [-- comment]
[spaces] !input spaces "<filepath>" [spaces] [-- comment]
[spaces] --!input spaces <filepath> [spaces] [-- comment]
[spaces] --!input spaces '<filepath>' [spaces] [-- comment]
[spaces] --!input spaces "<filepath>" [spaces] [-- comment]
```

There must be at least one space or tab between `!input` and your
`<filepath>`. If `<filepath>` contains spaces, it must be enclosed
within quotes. 

The script looks for `<filepath>` and `<filepath>.lua`. If you
don't want it to look for `<filepath>.lua` variants, use the
`-s` or `--strict` flag.

The entire line is replaced, including any comment ending the line.

## Options flags

* `-n`, `--no-recursion` do not process imported files
* `-s`, `--strict` do not add `.lua` to filenames
* `-h`, `--help` for help
* `-v`, `--verbose` verbose mode, displays info messages
* `-q`, `--quiet` quiet mode, no dot display warnings

## Tips

### Use verbose mode

If you're not sure about what the script is trying to import,
use the verbose mode.

```bash
lua lua-builder main.lua -o result.lua --verbose
```
