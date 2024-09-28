local p = require 'parsel'

local file = io.open("test.mx", "r")
local contents
if file then
  contents = file:read("*a")
end


local oWhitespace = p.optional(p.zeroOrMore(p.any(p.literal(" "), p.literal("\t"), p.literal("\n"))))
local localKeywordParser = p.map(p.literal("local"), function(_) return { type = "keyword", value = "local" } end)
local equalParser = p.map(p.literal("="), function(_) return { type = "keyword", value = "=" } end)
local identParser = p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))), function(tokens)
  return {
    type = "ident",
    value = tokens[1] .. table.concat(tokens[2], "")
  }
end)
local intParser = p.map(p.oneOrMore(p.digit()),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
local floatParser = p.map(p.seq(intParser, p.literal("."), intParser),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
local numberParser = p.either(intParser, floatParser)

local assignmentStmtParser = p.map(
  p.seq(localKeywordParser
  , oWhitespace
  , identParser
  , oWhitespace
  , equalParser
  , oWhitespace
  , numberParser
  ), function(results)
    return {
      type = "assignment",
      ident = results[3],
      value = results[7]
    }
  end)

local parsed = p.parse(contents, assignmentStmtParser)
p.dlog(parsed)
os.exit(0)
