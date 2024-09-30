local p = require 'parsel'

local file = io.open("sample.lua", "r")
local contents
if file then
  contents = file:read("*a")
end


--- Return a function that selects the nth item from a sequence
local pick = function(n)
  return function(seq)
    return seq[n]
  end
end

local Parsers = {
}

-- Keywords
Parsers.localDecl = p.map(p.literal("local"), function(_) return { type = "keyword", value = "local" } end)
Parsers.equals = p.map(p.literal("="), function(_) return { type = "EQUALS", value = "=" } end)

-- Primitives
Parsers.ident = p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))),
  function(tokens) return { type = "identifier", value = tokens[1] .. table.concat(tokens[2], "") } end)
Parsers.int = p.map(p.oneOrMore(p.digit()),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)

Parsers.string = p.map(p.seq(p.literal('"'), p.zeroOrMore(p.literalBesides('"')), p.literal('"')),
  function(seq)
    return {
      type = "string",
      value = table.concat(seq[2], "")
    }
  end)
Parsers.float = p.map(p.seq(Parsers.int, p.literal("."), Parsers.int),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
Parsers.number = p.either(Parsers.int, Parsers.float)

-- Expressions
Parsers.primitiveExpression = p.any(Parsers.number, Parsers.string, Parsers.ident)
Parsers.parenthesizedExpression = p.map(
  p.seq(p.literal("("), p.lazy(function() return Parsers.expression end),
    p.literal(")")), pick(2))
Parsers.baseExpression = p.either(Parsers.primitiveExpression, Parsers.parenthesizedExpression)
Parsers.expression = p.any(p.lazy(function() return Parsers.infixExpression end), Parsers.baseExpression)

Parsers.infixExpression = p.map(
  p.seq(Parsers.baseExpression,
    p.optionalWhitespace(),
    p.anyLiteral("+", "-", "^", "*", "==", "~=", "^"),
    p.optionalWhitespace(),
    Parsers.expression
  ), function(seq)
    return {
      type = "infix_expression",
      lhs = seq[1],
      op = seq[3],
      rhs = seq[5],
    }
  end
)
-- Statements
Parsers.expressionStatement = Parsers.expression
Parsers.assignment =
    p.map(
      p.seq(
        p.optional(Parsers.localDecl)
        , p.optionalWhitespace()
        , Parsers.ident
        , p.optionalWhitespace()
        , Parsers.equals
        , p.optionalWhitespace()
        , Parsers.expression
      ), function(results)
        local scope
        if results[1] == p.nullResult then
          scope = "GLOBAL"
        else
          scope = "LOCAL"
        end
        return {
          type = "assignment",
          ident = results[3],
          value = results[7],
          scope = scope,
        }
      end)

Parsers.statement = p.any(Parsers.assignment, Parsers.expressionStatement)

-- Program
Parsers.program = p.oneOrMore(p.map(p.seq(Parsers.statement, p.newline()), function(x) return x[1] end))

local parsed = p.parse(contents, Parsers.program)
if not parsed.parser:succeeded() then
  print(parsed.parser.error)
  os.exit(1)
end
p.dlog(parsed.result)
os.exit(0)
