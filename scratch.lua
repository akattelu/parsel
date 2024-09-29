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

local stringParser = p.seq(p.literal('"'), p.zeroOrMore(), p.literal('"'))


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
local expressionParser = p.any(numberParser, identParser)
local expressionStmtParser = expressionParser
local stmtParser = p.any(assignmentStmtParser, expressionStmtParser)

local parsed = p.parse(contents, stmtParser)
if not parsed.parser:succeeded() then
  print(parsed.parser.error)
  os.exit(1)
end
p.dlog(parsed.result)
os.exit(0)
