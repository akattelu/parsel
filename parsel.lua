local M = {}

local function noMatch(parser, error)
  return {
    token = nil,
    parser = parser:withError(error)
  }
end

local Token = {
  new = function(match, startPos, endPos)
    return {
      match = match,
      startPos = startPos,
      endPos = endPos
    }
  end
}

Parser = {
  new = function(input, pos, error)
    return {
      input = input,
      pos = pos or 1,
      error = error or nil,
      advance = function(self, amt)
        return Parser.new(self.input, self.pos + amt)
      end,
      withError = function(self, err)
        return Parser.new(self.input, self.pos, err)
      end,
      run = function(self, parser)
        return parser(self)
      end,
      print = function(self)
        print(string.format("Parser { token: %s, pos: %d, error: %s }", self.input, self.pos, self.error))
      end,
      succeeded = function(self)
        return not self.error
      end,
      inBounds = function(self)
        return self.pos <= #self.input
      end
    }
  end,
}

-- Entry point
function M.parse(input, combinator)
  local p = Parser.new(input)
  return p:run(combinator)
end

-- Parse any string literal
function M.literal(lit)
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local match = string.sub(parser.input, parser.pos, parser.pos + #lit - 1)
    if lit == match then
      return {
        token = Token.new(match, parser.pos, parser.pos + #lit),
        parser = parser:advance(#lit)
      }
    end
    return noMatch(parser, string.format("%s did not contain %s at position %d", parser.input, lit, parser.pos))
  end
end

-- Try first parser, and if that fails, try the second parser
function M.either(c1, c2)
  return M.any(c1, c2)
end

-- Parse any number
function M.number(value)
  assert(type(value) == "number", string.format("non-number passed to parsel.number: %s", value))
  return function(parser)
    return M.literal(tostring(value))(parser)
  end
end

-- Parse any alphabetic letter
function M.letter()
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local matched = string.match(string.sub(parser.input, parser.pos, parser.pos + 1), "%a")
    if matched then
      return {
        token = Token.new(matched, parser.pos, parser.pos + 1),
        parser = parser:advance(1)
      }
    end
    return noMatch(parser,
      string.format("%s did not contain an alphabetic letter at position %d", parser.input, parser.pos))
  end
end

-- Parse any digit
function M.digit()
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local matched = string.match(string.sub(parser.input, parser.pos, parser.pos + 1), "%d")
    if matched then
      return {
        token = Token.new(matched, parser.pos, parser.pos + 1),
        parser = parser:advance(1)
      }
    end
    return noMatch(parser,
      string.format("%s did not contain a digit at position %d", parser.input, parser.pos))
  end
end

-- Parse a combinator at least one time and until the parse fails
function M.oneOrMore(c)
  return function(parser)
    local result = parser:run(c)
    if result.parser:succeeded() then
      local current
      local next = result
      local tokens = {}
      repeat
        current = next
        table.insert(tokens, current.token)
        next = current.parser:run(c)
      until not next.parser:succeeded()
      return {
        tokens = tokens,
        parser = current.parser
      }
    else
      return noMatch(result.parser,
        string.format("could not match %s at least once at position %d: %s", result.parser.input, result.parser.pos,
          result.parser.error))
    end
  end
end

-- Parse any combinators specified in the list
function M.any(...)
  local combinators = table.pack(...)
  return function(parser)
    for _, c in ipairs(combinators) do
      local result = parser:run(c)
      if result.parser:succeeded() then
        return result
      end
    end
    return noMatch(parser, string.format("no parser matched %s at position %d", parser.input, parser.pos))
  end
end

-- Parse all combinators in sequence
function M.seq(...)
  local combinators = table.pack(...)

  return function(parser)
    local tokens = {}
    local result = { parser = parser }
    for _, c in ipairs(combinators) do
      result = result.parser:run(c)
      if not result.parser:succeeded() then
        return noMatch(result.parser, result.parser.error)
      end
      table.insert(tokens, result.token)
    end
    return {
      tokens = tokens,
      parser = result.parser
    }
  end
end

return M
