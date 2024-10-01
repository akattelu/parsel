local p = require 'parsel'

--- Return a function that selects the nth item from a sequence
local pick = function(n)
  return function(seq)
    return seq[n]
  end
end

local Parsers = {}

-- Keywords
Parsers.localDecl = p.map(p.literal("local"), function(_) return { type = "keyword", value = "local" } end)
Parsers.equals = p.map(p.literal("="), function(_) return { type = "equals", value = "=" } end)

-- Primitives
Parsers.ident = p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))),
  function(tokens) return { type = "identifier", value = tokens[1] .. table.concat(tokens[2], "") } end)
Parsers.int = p.map(p.oneOrMore(p.digit()),
  function(digList) return { type = "number", value = tonumber(table.concat(digList, "")) } end)
Parsers.float = p.map(p.seq(Parsers.int, p.literal("."), Parsers.int),
  function(digList)
    return {
      type = "number",
      value = tonumber(tostring(digList[1].value) ..
        "." .. tostring(digList[3].value))
    }
  end)
Parsers.string = p.map(p.seq(p.literal('"'), p.zeroOrMore(p.literalBesides('"')), p.literal('"')),
  function(seq)
    return {
      type = "string",
      value = table.concat(seq[2], "")
    }
  end)
Parsers.number = p.either(Parsers.float, Parsers.int)
Parsers.boolean = p.map(p.anyLiteral("true", "false"), function(val)
  return { type = "boolean", value = val == "true" and true or false }
end)
Parsers.nilValue = p.map(p.literal("nil"), function(_) return { type = "nil" } end)

-- Expressions
Parsers.primitiveExpression = p.any(Parsers.number, Parsers.string, Parsers.boolean, Parsers.nilValue, Parsers.ident)
Parsers.parenthesizedExpression = p.map(
  p.seq(
    p.literal("("),
    p.lazy(function() return Parsers.expression end),
    p.literal(")")
  ), pick(2))
Parsers.baseExpression = p.either(Parsers.primitiveExpression, Parsers.parenthesizedExpression)
Parsers.expression = p.any(
  p.lazy(function() return Parsers.infixExpression end),
  p.lazy(function() return Parsers.notExpression end),
  p.lazy(function() return Parsers.prefixExpression end),
  Parsers.baseExpression
)

Parsers.prefixExpression = p.map(
  p.seq(
    p.anyLiteral("-"),
    Parsers.expression
  ),
  function(seq)
    return {
      type = "prefix_expression",
      op = seq[1],
      rhs = seq[2]
    }
  end
)
Parsers.notExpression = p.map(
  p.seq(
    p.literal("not"),
    p.literal(" "),
    Parsers.expression
  ), function(seq)
    return {
      type = "prefix_expression",
      op = "not",
      rhs = seq[3]
    }
  end
)
Parsers.infixExpression = p.map(
  p.seq(Parsers.baseExpression,
    p.optionalWhitespace(),
    p.anyLiteral("+", "-", "/", "*", "==", "~=", "^"),
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
Parsers.expressionStatement = p.map(Parsers.expression, function(e)
  -- Parsers.dlog(e)
  return e
end)
Parsers.declaration = p.map(
  p.seq(Parsers.localDecl, p.optionalWhitespace(), Parsers.ident),
  function(seq)
    return {
      type = "declaration",
      identifier = seq[3],
      scope = "LOCAL",
    }
  end
)
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

Parsers.statement = p.any(Parsers.assignment, Parsers.declaration, Parsers.expressionStatement)

-- Program
-- TODO: fix so that you can have new lines at the end of the program
Parsers.program = p.map(
  p.seq(p.optionalWhitespace(), p.sepBy(Parsers.statement, p.oneOrMore(p.seq(p.newline(), p.optionalWhitespace()))),
    p.optionalWhitespace()), pick(2))


-- Parse string
Parsers.parseString = function(s, parser)
  local parsed = p.parse(s, parser)
  if not parsed.parser:succeeded() then
    return nil, parsed.parser.error
  end
  return parsed.result, nil
end

Parsers.parseProgramString = function(s)
  return Parsers.parseString(s, Parsers.program)
end


-- debugging
Parsers.dlog = p.dlog

-- Main
-- local file = io.open("sample.lua", "r")
-- local contents
-- if file then
--   contents = file:read("*a")
-- end
-- local parsed = p.parse(contents, Parsers.program)
-- if not parsed.parser:succeeded() then
--   print(parsed.parser.error)
--   os.exit(1)
-- end
-- p.dlog(parsed.result)
-- os.exit(0)

return Parsers
