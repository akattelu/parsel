package.path = package.path .. ";../?.lua" -- import from parent
local p = require '../parsel'

local Parsers = {}

-- Helper functions

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
local paramParser = p.map(p.lazy(function() return Parsers.ident end), function(i) return i.value end)
local nameWithDots = p.map(p.sepBy(p.lazy(function() return Parsers.ident end), p.literal(".")), function(seq)
  local values = {}
  for _, v in ipairs(seq) do
    table.insert(values, v.value)
  end
  return table.concat(values, ".")
end)
local dotAccessKeyParser = p.map(p.seq(p.literal("."), p.lazy(function() return Parsers.ident end)), function(seq)
  return {
    type = "string",
    value = seq[2].value
  }
end)
local bracketAccessKeyParser = p.map(p.seq(
  p.literal("["),
  ows,
  p.lazy(function() return Parsers.expression end),
  ows,
  p.literal("]")
), pick(3))
local tableDictItemParser = p.map(p.seq(
  p.either(
    p.map(p.lazy(function() return Parsers.ident end),
      function(ident) return { type = "string", value = ident.value } end), -- use the raw string from the identifier
    p.map(p.seq(
      p.literal("["),
      ows,
      p.lazy(function() return Parsers.expression end),
      ows,
      p.literal("]")
    ), pick(3))
  ),
  ows,
  p.literal("="),
  ows,
  p.lazy(function() return Parsers.expression end)
), function(seq)
  return {
    type = "table_item",
    value = seq[5],
    key = seq[1]
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
local functionCallParser =
    p.either(
      p.map(
        p.seq(p.zeroOrMore(p.literal(" ")), p.lazy(function() return Parsers.string end)),
        function(seq)
          return {
            type = "function_call_expression",
            args = { seq[2] },
            func = "" -- should be filled in by caller
          }
        end),
      p.map(
        p.seq(
          p.literal("("),
          ows,
          p.optional(
            p.sepBy(p.lazy(function() return Parsers.expression end), p.seq(p.literal(","), ows))
          ),
          ows,
          p.literal(")")
        )
        , function(seq)
          return {
            type = "function_call_expression",
            args = seq[3] == p.nullResult and {} or seq[3],
            func = "" -- should be filled in by caller
          }
        end
      )
    )
local methodCallParser = p.map(
  p.seq(
    p.literal(":"),
    p.lazy(function() return Parsers.ident end),
    ows,
    p.literal("("),
    ows,
    p.optional(
      p.sepBy(p.lazy(function() return Parsers.expression end), p.seq(p.literal(","), ows))
    ),
    ows,
    p.literal(")")
  )
  , function(seq)
    return {
      type = "method_call_expression",
      args = seq[6] == p.nullResult and {} or seq[6],
      method = seq[2],
      self = "" -- filled in later
    }
  end
)


-- Primitives
Parsers.ident = p.exclude(
  p.any(
    p.map(
      p.seq(p.letter(), p.zeroOrMore(p.any(p.letter(), p.digit(), p.literal("_")))),
      function(tokens) return { type = "identifier", value = tokens[1] .. table.concat(tokens[2], "") } end),
    p.map(p.literal('...'), function(_) return { type = "identifier", value = "..." } end),
    p.map(p.literal("_"), function(_) return { type = "identifier", value = "_" } end)
  ),
  function(n)
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
        p.sepByAllowTrailing(tableDictItemParser, p.seq(p.literal(','), ows))
        , p.map(p.sepByAllowTrailing(tableListItemParser, p.seq(p.literal(','), ows)), function(itemList)
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
Parsers.baseExpression = p.any(p.lazy(function() return Parsers.accessExpression end), Parsers.primitiveExpression,
  Parsers.parenthesizedExpression)
Parsers.expression = p.any(
  p.lazy(function() return Parsers.functionExpression end),
  p.lazy(function() return Parsers.infixExpression end),
  p.lazy(function() return Parsers.notExpression end),
  p.lazy(function() return Parsers.prefixExpression end),
  Parsers.baseExpression
)
Parsers.prefixExpression = p.map(
  p.exclude(p.seq(
    p.anyLiteral("-", "#"),
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
  p.seq(p.any(Parsers.primitiveExpression, Parsers.parenthesizedExpression),
    p.oneOrMore(p.any(methodCallParser, functionCallParser, bracketAccessKeyParser, dotAccessKeyParser))),
  function(seq)
    local lhs
    local lastLHS = seq[1]
    for _, v in ipairs(seq[2]) do
      if v.type == "function_call_expression" then
        lhs = v
        lhs.func = lastLHS
      elseif v.type == "method_call_expression" then
        lhs = v
        lhs.self = lastLHS
      else
        lhs = {
          type = "table_access_expression",
          lhs = lastLHS,
          index = v
        }
      end
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
      p.map(p.seq(p.literal("("), p.sepBy(paramParser, p.seq(p.literal(','), ows)), p.literal(")")),
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
      params = seq[3],
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
    p.optional(p.seq(
      p.literal("else"),
      ws,
      block,
      ows
    )),
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
      else_block = seq[10] == p.nullResult and {} or seq[10][3],
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

Parsers.genericForStmt = p.map(
  p.seq(
    p.literal("for"),
    ws,
    p.sepBy(Parsers.ident, p.seq(p.literal(","), ows)),
    ws,
    p.literal("in"),
    ws,
    Parsers.expression,
    ws,
    p.literal("do"),
    ws,
    block,
    ows,
    p.literal("end")
  )
  , function(seq)
    return {
      type = "generic_for",
      listExpression = seq[7],
      loopVariables = seq[3],
      block = seq[11]
    }
  end
)

Parsers.numericForStmt = p.map(
  p.seq(
    p.literal("for"),
    ws,
    p.seq(
      Parsers.ident
      , ows
      , p.literal("=")
      , ows
      , Parsers.expression -- start
    ),
    ows,
    p.literal(","),
    ows,
    Parsers.expression, -- limit
    ows,
    p.optional(
      p.seq(
        p.literal(","),
        ows,
        Parsers.expression -- step
      )
    ),
    ows,
    p.literal("do"),
    ws,
    block,
    ows,
    p.literal("end")
  )
  , function(seq)
    return {
      type = "numeric_for",
      control = seq[3][1],
      start = seq[3][5],
      limit = seq[7],
      step = seq[9] ~= p.nullResult and seq[9][3] or { type = "number", value = 1 },
      block = seq[13]
    }
  end
)
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
      p.map(p.seq(p.literal("("), p.sepBy(paramParser, p.seq(p.literal(','), ows)), p.literal(")")),
        pick(2)))
    , ows
    , block
    , ows
    , p.literal('end')
  ), function(seq)
    return {
      type = "function",
      name = seq[4],
      params = seq[6],
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
  , Parsers.genericForStmt
  , Parsers.numericForStmt
  , Parsers.repeatStmt
  , Parsers.returnStmt
  , Parsers.functionStmt
  , Parsers.expressionStatement
)

-- Program
Parsers.program = p.oneOrMore(
  p.either(
    p.map(p.seq(ows, Parsers.statement, ows), pick(2)),
    lineComment
  )
)

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

local function printTable(t)
  local function printTableIndent(t2, indent)
    if (type(t2) == "table") then
      for pos, val in pairs(t2) do
        if (type(val) == "table") then
          if type(pos) == "string" then
            print(indent .. '"' .. pos .. '": ' .. "{")
          else
            print(indent .. pos .. ': ' .. "{")
          end
          printTableIndent(val, indent .. "  ")
          print(indent .. "}")
        elseif (type(val) == "string") then
          print(indent .. '"' .. pos .. '": "' .. val .. '"')
        else
          print(indent .. pos .. ": " .. tostring(val))
        end
      end
    else
      print(indent .. tostring(t2))
    end
  end

  if (type(t) == "table") then
    print("{")
    printTableIndent(t, " ")
    print("}")
  else
    printTableIndent(t, " ")
  end
end

local M = {
  parse = Parsers.parseProgramString,
  print = printTable,

  -- TODO: clean up exposed API
  parseString = Parsers.parseString,
  parseProgramString = Parsers.parseProgramString,
  ident = Parsers.ident,
  returnStmt = Parsers.returnStmt
}

return M
