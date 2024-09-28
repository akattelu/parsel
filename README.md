# Parsel

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
