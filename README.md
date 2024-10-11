# Parsel

<!--toc:start-->
- [Parsel](#parsel)
  - [Usage](#usage)
  - [Available Parsers](#available-parsers)
  - [Available combinators](#available-combinators)
  - [TODO](#todo)
<!--toc:end-->

A parser combinator library for Lua 

## Usage

```lua
local p = require 'parsel'

local digitsParser = p.oneOrMore(p.digit())
local intParserToNumber = p.map(digitsParser, function(digits)
  return tonumber(table.concat(digits, ""))
end)
local parsed = p.parse("1234", intParserToNumber)
print(parsed.result)
-- 1234
```

## Available Parsers

```lua
local Parsel = require 'parsel'
Parsel.literal (lit) -- Parse any string literal
Parsel.letter () -- Parse any alphabetic letter
Parsel.digit () -- Parse any digit
Parsel.char () -- Match any single character
Parsel.charExcept (char) -- Match anything but the specified literal single character
Parsel.newline () -- Match single newline char
Parsel.whitespace () -- Match whitespace Matches at least one tab, space, or newline and consumes it
Parsel.optionalWhitespace () -- Match optional whitespace Optionally matches and consumes spaces, tabs and newlines
Parsel.anyLiteral (...) -- Match any literal passed in, succeeds with the match
Parsel.untilLiteral (literal) -- Match the parsers string until the specified literal is found
```

## Available combinators

```lua
local Parsel = require 'parsel'
Parsel.any (...) -- Parse any combinators specified in the list
Parsel.either (p1, p2) -- Try first parser, and if that fails, try the second parser
Parsel.oneOrMore (p) -- Parse a combinator at least one time and until the parse fails
Parsel.seq (...) -- Parse all combinators in sequence
Parsel.zeroOrMore (p) -- Parse zero or more instances of combinators
Parsel.optional (p) -- Optionally parse a combinator, return Parsel.nullResult if not matched
Parsel.lazy (f) -- Returns a parser that lazily evaluates a function
Parsel.sepBy (p, delim) -- Match parsers delimited by successful parse of delim
Parsel.exclude (p, exclusionFunc) -- Fails a parser if it matches condition set by exclusionFunc
```

## TODO
[x] elseif 
[x] else 
[x] table literals
[x] access operation with dot
[ ] access operation with brackets
[ ] function calls
[ ] method access syntax
[ ] table assignment
[ ] bit and misc operators
[x] comments
[x] comparison operators
[x] concat operator
[x] blockstrings
[x] and/or infix
[x] single quote strings
[x] local functions
