local p = require 'parsel'

local file = io.open("test.mx", "r")
local contents
if file then
  contents = file:read("*a")
end


-- local function mapDropNull(parserFn)
--   return p.map(parserFn, function(results)
--     local final = {}
--     for _, r in ipairs(results) do
--       if r ~= p.nullResult then
--         table.insert(final, r)
--       end
--     end
--   end)
-- end


local localKeywordParser = p.map(p.literal("local"), function(_) return { type = "keyword", value = "local" } end)
local equalParser = p.map(p.literal("="), function(_) return { type = "keyword", value = "=" } end)
local identParser = p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))), function(tokens)
  return {
    type = "identifier",
    value = tokens[1] .. table.concat(tokens[2], "")
  }
end)
local intParser = p.map(p.oneOrMore(p.digit()),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
local floatParser = p.map(p.seq(intParser, p.literal("."), intParser),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
local numberParser = p.either(intParser, floatParser)

local stringParser = p.map(p.seq(p.literal('"'), p.zeroOrMore(p.literalBesides('"')), p.literal('"')), function(seq)
  return {
    type = "string",
    value = table.concat(seq[2], "")
  }
end)


local expressionParser = p.any(numberParser, stringParser, identParser)
local expressionStmtParser = expressionParser
local assignmentStmtParser = p.map(
  p.seq(localKeywordParser
  , p.optionalWhitespace()
  , identParser
  , p.optionalWhitespace()
  , equalParser
  , p.optionalWhitespace()
  , expressionParser
  ), function(results)
    return {
      type = "assignment",
      ident = results[3],
      value = results[7]
    }
  end)
local stmtParser = p.any(assignmentStmtParser, expressionStmtParser)
local programParser = p.oneOrMore(p.map(p.seq(stmtParser, p.newline()), function(x) return x[1] end))

local parsed = p.parse(contents, programParser)
if not parsed.parser:succeeded() then
  print(parsed.parser.error)
  os.exit(1)
end
p.dlog(parsed.result)
os.exit(0)
