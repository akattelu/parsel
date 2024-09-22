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
  return function(parser)
    local result = parser:run(c1)
    if result.parser:succeeded() then
      return result
    end
    local result2 = parser:run(c2)
    if result2.parser:succeeded() then
      return result2
    end
    return noMatch(parser, "neither parser found a match")
  end
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

M.token = Token
M.parser = Parser

return M
