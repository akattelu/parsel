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
local p = require 'parsel'
p.digit() -- matches any single digit
p.letter() -- matches any alphabetic letter
p.literal(str) -- matches the literal string `str`
p.untilLiteral(str) -- matches until the literal string `str` or end of string
p.newline() -- matches a newline character
p.whitespace() -- matches one or more spaces, tabs, or newlines
p.optionalWhitespace() -- matches zero or more spaces, tabs, or newlines
p.char() -- matches any single character
```

## Available combinators

```lua
local p = require 'parsel'
p.any(...) -- succeeds with the first successful parser
p.anyLiteral(...) -- succeeds if any of the specified literals match
p.either(c1, c2) -- succeds with first of c1 or c2, fails otherwise
p.seq(...) -- requires all parsers to succeed in order
p.optional(c) -- attempts to parse with c, succeeds with p.nullResult otherwise
p.zeroOrMore(c) -- attempts to parse 0 or more instances of c
p.oneOrMore(c) -- attempts to parse at least 1 instead of c
p.sepBy(c, delim) -- parses many instances of c parser delimited by delim parser
p.exclude(c, cond) -- Fails a parser if it matches condition set by cond
p.lazy(func) -- returns a combinator that lazily evaluates func (func should return a parser)
```


## TODO
[ ] elseif 
[ ] else 
[ ] tables
[ ] access operations
[x] and/or infix
[ ] comments
[x] blockstrings
[x] single quote strings
[ ] method access syntax
[x] concat operator
[x] local functions
[ ] table assignment
[ ] comparison operators
