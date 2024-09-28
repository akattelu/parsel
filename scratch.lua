local p = require 'parsel'

local file = io.open("test.mx", "r")
local contents
if file then
  contents = file:read("*a")
end

local letter = p.letter(function(match) return {} end)

local identParser = p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit())))
-- local identParser = p.zeroOrMore(p.either(p.letter(), p.digit()))
local result = p.parse(contents, identParser)
p.printTokens(result)
result.parser:print()

os.exit(0)
