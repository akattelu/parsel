local p = require 'parsel'

local file = io.open("test.mx", "r")
local contents
if file then
  contents = file:read("*a")
end
local identParser = p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))), function(tokens)
  return {
    type = "ident",
    value = tokens[1] .. table.concat(tokens[2], "")
  }
end)

local parsed = p.parse(contents, identParser)
p.dlog(parsed.result)

os.exit(0)
