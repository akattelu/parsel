local p = require 'parsel'

--- Return a function that selects the nth item from a sequence
local pick = function(n)
  return function(seq)
    return seq[n]
  end
end

local keywords = {
  "if", "else", "then", "end", "elseif", "return", "local", "function", "while", "for", "do", "in",
  "repeat", "until", "while", "true", "false", "nil"
}

local function isKeyword(word)
  for _, v in ipairs(keywords) do
    if v == word then
      return true
    end
  end

  return false
end

local Parsers = {}

-- Primitives
Parsers.ident = p.exclude(p.map(p.seq(p.letter(), p.zeroOrMore(p.either(p.letter(), p.digit()))),
  function(tokens) return { type = "identifier", value = tokens[1] .. table.concat(tokens[2], "") } end), function(n)
  return isKeyword(n.value)
end)
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
Parsers.string = p.map(p.seq(p.literal('"'), p.zeroOrMore(p.charExcept('"')), p.literal('"')),
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
  ), function(seq)
    return { type = "prefix_expression", op = seq[1], rhs = seq[2] }
  end)
Parsers.notExpression = p.map(
  p.seq(
    p.literal("not"),
    p.literal(" "),
    Parsers.expression
  ), function(seq)
    return { type = "prefix_expression", op = "not", rhs = seq[3] }
  end
)
Parsers.infixExpression = p.map(
  p.seq(Parsers.baseExpression,
    p.optionalWhitespace(),
    p.anyLiteral("+", "-", "/", "*", "==", "~=", "^"),
    p.optionalWhitespace(),
    Parsers.expression
  ), function(seq)
    return { type = "infix_expression", lhs = seq[1], op = seq[3], rhs = seq[5] }
  end)

-- Statements
Parsers.expressionStatement = p.map(Parsers.expression, function(e)
  -- Parsers.dlog(e)
  return e
end)
Parsers.ifStmt = p.map(
  p.seq(
    p.literal("if"),
    p.optionalWhitespace(),
    Parsers.expression,
    p.optionalWhitespace(),
    p.literal("then"),
    p.optionalWhitespace(),
    p.zeroOrMore(p.map(p.seq(p.lazy(function() return Parsers.statement end), p.optionalWhitespace()), pick(1))),
    -- p.zeroOrMore(p.map(
    --   p.seq(p.optionalWhitespace(), p.lazy(function() return Parsers.statement end), p.optionalWhitespace()), pick(2))),
    p.optionalWhitespace(),
    p.literal("end")
  ), function(seq)
    return {
      type = "conditional",
      cond = seq[3],
      then_block = seq[7],
      else_block = nil
    }
  end
)
Parsers.declaration = p.map(
  p.seq(p.literal("local"), p.optionalWhitespace(), Parsers.ident),
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
        p.optional(p.literal("local"))
        , p.optionalWhitespace()
        , Parsers.ident
        , p.optionalWhitespace()
        , p.literal("=")
        , p.optionalWhitespace()
        , Parsers.expression
      ), function(results)
        return {
          type = "assignment",
          ident = results[3],
          value = results[7],
          scope = results[1] == p.nullResult and "GLOBAL" or "LOCAL",
        }
      end)

Parsers.statement = p.any(Parsers.assignment, Parsers.declaration, Parsers.ifStmt, Parsers.expressionStatement)

-- Program
Parsers.program = p.oneOrMore(p.map(p.seq(p.optionalWhitespace(), Parsers.statement, p.optionalWhitespace()), pick(2)))

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
