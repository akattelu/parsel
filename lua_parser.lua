local p = require 'parsel'


local Parsers = {}


-- Helper functions

-- Mapper that prints the result before returning it as is
local function printed(parser)
  return p.map(parser, function(res) p.dlog(res) end)
end

--- Check if word is a lua keyword
local function isKeyword(word)
  local keywords = {
    "or", "and", "if", "else", "then", "end", "elseif", "return", "local", "function", "while", "for", "do", "in",
    "repeat", "until", "while", "true", "false", "nil"
  }
  for _, v in ipairs(keywords) do
    if v == word then
      return true
    end
  end

  return false
end

-- Return a function that selects the nth item from a sequence
local pick = function(n)
  return function(seq)
    return seq[n]
  end
end


-- Helper smaller parsers
local lineComment = p.map(
  p.oneOrMore(p.seq(p.optionalWhitespace(), p.literal('--'), p.untilLiteral("\n"), p.optionalWhitespace())),
  function(val)
    return {
      type = "comment",
      value = val
    }
  end)
local ws = p.either(
  lineComment,
  p.whitespace()
)
local ows = p.either(
  lineComment,
  p.optionalWhitespace()
)
local block = p.zeroOrMore(p.map(p.seq(p.lazy(function() return Parsers.statement end), ows), pick(1)))
local argParser = p.map(p.lazy(function() return Parsers.ident end), function(i) return i.value end)
local nameWithDots = p.map(p.sepBy(p.lazy(function() return Parsers.ident end), p.literal(".")), function(seq)
  local values = {}
  for _, v in ipairs(seq) do
    table.insert(values, v.value)
  end
  return table.concat(values, ".")
end)
local accessKeyParser = p.map(p.seq(p.literal("."), p.lazy(function() return Parsers.ident end)), function(seq)
  return {
    type = "access_key_string",
    name = seq[2].value
  }
end)
local tableDictItemParser = p.map(p.seq(
  p.lazy(function() return Parsers.ident end),
  ows,
  p.literal("="),
  ows,
  p.lazy(function() return Parsers.expression end)
), function(seq)
  return {
    type = "table_item",
    value = seq[5],
    key = seq[1].value -- use the raw string from the identifier
  }
end)
local tableListItemParser = p.map(p.lazy(function() return Parsers.expression end), function(expr)
  return {
    type = "table_item",
    value = expr,
    key = 0 -- fill this in later for numerical indices
  }
end
)


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
Parsers.string = p.map(
  p.any(
    p.seq(p.literal('"'), p.untilLiteral('"'), p.literal('"'))
    , p.seq(p.literal([[']]), p.untilLiteral("'"), p.literal([[']]))
    , p.seq(p.literal('[['), p.untilLiteral("]]"), p.literal(']]'))
  ), function(val)
    return {
      type = "string",
      value = val[2]
    }
  end)
Parsers.number = p.either(Parsers.float, Parsers.int)
Parsers.boolean = p.map(p.anyLiteral("true", "false"), function(val)
  return { type = "boolean", value = val == "true" and true or false }
end)
Parsers.nilValue = p.map(p.literal("nil"), function(_) return { type = "nil" } end)
Parsers.tableLiteral = p.map(
  p.seq(
    p.literal("{"),
    ows,
    p.optional(
      p.either(
        p.sepBy(tableDictItemParser, p.seq(p.literal(','), ows))
        , p.map(p.sepBy(tableListItemParser, p.seq(p.literal(','), ows)), function(itemList)
          for i, v in ipairs(itemList) do
            v.key = i -- assign raw numerical index
          end
          return itemList
        end)
      )
    ),
    ows,
    p.literal("}")
  ),
  function(seq)
    return {
      type = "table_literal",
      items = seq[3] == p.nullResult and {} or seq[3]
    }
  end
)

-- Expressions
Parsers.primitiveExpression = p.any(Parsers.number, Parsers.string, Parsers.boolean, Parsers.nilValue,
  Parsers.tableLiteral, Parsers.ident)
Parsers.parenthesizedExpression = p.map(
  p.seq(
    p.literal("("),
    p.lazy(function() return Parsers.expression end),
    p.literal(")")
  ), pick(2))
Parsers.baseExpression = p.any(Parsers.primitiveExpression, Parsers.parenthesizedExpression)
Parsers.expression = p.any(
  p.lazy(function() return Parsers.accessExpression end),
  p.lazy(function() return Parsers.functionExpression end),
  p.lazy(function() return Parsers.infixExpression end),
  p.lazy(function() return Parsers.notExpression end),
  p.lazy(function() return Parsers.prefixExpression end),
  Parsers.baseExpression
)
Parsers.prefixExpression = p.map(
  p.exclude(p.seq(
    p.anyLiteral("-"),
    ows,
    Parsers.expression
  ), function(seq)
    return seq[3].type == "prefix_expression" and seq[3].op == "-"
  end), function(seq)
    return { type = "prefix_expression", op = seq[1], rhs = seq[3] }
  end)
Parsers.notExpression = p.map(
  p.seq(
    p.literal("not"),
    ws,
    Parsers.expression
  ), function(seq)
    return { type = "prefix_expression", op = "not", rhs = seq[3] }
  end
)
Parsers.infixExpression = p.map(
  p.exclude(p.seq(Parsers.baseExpression,
    ows,
    p.anyLiteral("<<", ">>", "&", "|", "+", "-", "//", "*", "==", "~=", "^", "or", "and", "..", ">=", "<=", ">", "<", "%",
      "~", "/"),
    ows,
    Parsers.expression
  ), function(seq)
    return seq[3] == "-" and seq[5].type == "prefix_expression" and seq[5].op == "-"
  end), function(seq)
    return { type = "infix_expression", lhs = seq[1], op = seq[3], rhs = seq[5] }
  end)


-- handle left recursion for expression dot access chaining
-- by greedily taking as many access as possible with oneOrMore
Parsers.accessExpression = p.map(
  p.seq(Parsers.baseExpression, p.oneOrMore(accessKeyParser)),
  function(seq)
    local lhs, rhs
    local lastLHS = seq[1]
    for _, v in ipairs(seq[2]) do
      rhs = v
      lhs = {
        type = "table_access_expression",
        lhs = lastLHS,
        index = rhs
      }
      lastLHS = lhs
    end
    return lhs
  end
)

Parsers.functionExpression = p.map(
  p.seq(
    p.literal("function")
    , ows
    , p.any(
      p.map(p.literal("()"), function(_) return {} end),
      p.map(p.literal("(...)"), function(_) return { "..." } end),
      p.map(p.seq(p.literal("("), p.sepBy(argParser, p.seq(p.literal(','), ows)), p.literal(")")),
        pick(2))
    )
    , ows
    , block
    , ows
    , p.literal('end')
  ), function(seq)
    return {
      type = "function",
      name = nil,
      args = seq[3],
      block = seq[5]
    }
  end)

-- Statements

Parsers.expressionStatement = Parsers.expression
Parsers.ifStmt = p.map(
  p.seq(
    p.literal("if"),
    ws,
    Parsers.expression,
    ws,
    p.literal("then"),
    ws,
    block,
    ows,
    p.optional(
      p.seq(
        p.literal("else"),
        ws,
        block,
        ows
      )
    ),
    p.literal("end")
  ), function(seq)
    return {
      type = "conditional",
      cond = seq[3],
      then_block = seq[7],
      else_block = (seq[9] == p.nullResult and nil or seq[9][3]),
    }
  end)
Parsers.switchStmt = p.map(
  p.seq(
    p.literal("if"),
    ws,
    Parsers.expression,
    ws,
    p.literal("then"),
    ws,
    block,
    ows,
    p.oneOrMore(
      p.seq(
        p.literal("elseif"),
        ws,
        Parsers.expression,
        ws,
        p.literal("then"),
        ws,
        block,
        ows
      )),
    p.seq(
      p.literal("else"),
      ws,
      block,
      ows
    ),
    p.literal("end")
  ), function(seq)
    local cases = {}
    table.insert(cases, {
      type = "switch_case",
      cond = seq[3],
      block = seq[7],
    })
    for _, v in ipairs(seq[9]) do
      table.insert(cases, {
        type = "switch_case",
        cond = v[3],
        block = v[7],
      })
    end
    return {
      type = "switch",
      cases = cases,
      else_block = seq[10][3],
    }
  end)
Parsers.whileStmt = p.map(
  p.seq(
    p.literal("while"),
    ws,
    Parsers.expression,
    ws,
    p.literal("do"),
    ws,
    block,
    ows,
    p.literal("end")
  ), function(seq)
    return {
      type = "while",
      cond = seq[3],
      block = seq[7],
    }
  end)

Parsers.repeatStmt = p.map(
  p.seq(
    p.literal("repeat"),
    ws,
    block,
    ows,
    p.literal("until"),
    ws,
    Parsers.expression
  ), function(seq)
    return {
      type = "repeat",
      cond = seq[7],
      block = seq[3],
    }
  end)
Parsers.declaration = p.map(
  p.seq(p.literal("local"), ws, Parsers.ident),
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
        p.optional(p.seq(p.literal("local"), ws))
        , Parsers.ident
        , ows
        , p.literal("=")
        , ows
        , Parsers.expression
      ), function(results)
        return {
          type = "assignment",
          ident = results[2],
          value = results[6],
          scope = results[1] == p.nullResult and "GLOBAL" or "LOCAL",
        }
      end)

Parsers.tableAssignment =
    p.map(
      p.seq(
        Parsers.accessExpression
        , ows
        , p.literal("=")
        , ows
        , Parsers.expression
      ), function(results)
        return {
          type = "table_assignment",
          table = results[1].lhs,
          index = results[1].index,
          value = results[5],
        }
      end)

Parsers.returnStmt = p.map(
  p.seq(
    p.literal('return'), ws, Parsers.expression
  ), function(seq)
    return {
      type = "return",
      value = seq[3]
    }
  end
)


Parsers.functionStmt = p.map(
  p.seq(
    p.optional(p.seq(p.literal('local'), ws))
    , p.literal("function")
    , ws
    , nameWithDots
    , ows
    , p.any(
      p.map(p.literal("()"), function(_) return {} end),
      p.map(p.literal("(...)"), function(_) return { "..." } end),
      p.map(p.seq(p.literal("("), p.sepBy(argParser, p.seq(p.literal(','), ows)), p.literal(")")),
        pick(2)))
    , ows
    , block
    , ows
    , p.literal('end')
  ), function(seq)
    return {
      type = "function",
      name = seq[4],
      args = seq[6],
      block = seq[8],
      scope = seq[1] == p.nullResult and "GLOBAL" or "LOCAL"
    }
  end)

Parsers.statement = p.any(
  lineComment
  , Parsers.tableAssignment
  , Parsers.assignment
  , Parsers.declaration
  , Parsers.switchStmt
  , Parsers.ifStmt
  , Parsers.whileStmt
  , Parsers.repeatStmt
  , Parsers.returnStmt
  , Parsers.functionStmt
  , Parsers.expressionStatement
)

-- Program
Parsers.program = p.oneOrMore(p.map(p.seq(ows, Parsers.statement, ows), pick(2)))

-- Parse string
Parsers.parseString = function(s, parser)
  local parsed = p.parse(s, parser)
  if not parsed.parser:succeeded() then
    return parsed.result, parsed.parser.error
  end
  if (parsed.parser.pos - 1) ~= #s then
    return parsed.result, "did not complete entire string"
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
