--- a parser combinator library for Lua

-- holds parser combinator functions
-- @module Parsel
local Parsel = {}

local function noMatch(parser, error)
  return {
    token = nil,
    parser = parser:withError(error),
    result = nil
  }
end


--- a result indicating an optional match
-- returned as a placeholder when an optional match did not succeed
-- @field type always "NULL"
-- @see Parsel.optional
Parsel.nullResult = { type = "NULL" }

local Token = {
  new = function(match, startPos, endPos)
    return {
      match = match,
      startPos = startPos,
      endPos = endPos
    }
  end
}

local function insertToken(t, result)
  if result.tokens then
    table.insert(t, result.tokens)
  elseif result.token then
    table.insert(t, result.token)
  end
end

Parser = {
  new = function(input, pos, error)
    return {
      input = input,
      pos = pos or 1,
      error = error or nil,
      advance = function(self, amt)
        return Parser.new(self.input, self.pos + amt, self.error)
      end,
      withError = function(self, err)
        return Parser.new(self.input, self.pos, err)
      end,
      run = function(self, parser)
        return parser(self)
      end,
      print = function(self)
        print(string.format("Parser { input: %s, pos: %d, error: %s }", self.input, self.pos, self.error))
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

--- Entry point to parsing a string
-- @param input the string to match
-- @param parser to use on the string
-- @return the result returned by the parser
function Parsel.parse(input, parser)
  local p = Parser.new(input)
  return p:run(parser)
end

--- Map the result of a parser
-- @param base parser to run and map the result of
-- @param mapFn function to apply to the result of the parser operation
-- @return a new parser function with a mapped result
function Parsel.map(base, mapFn)
  return function(parser)
    local after = base(parser)
    if after.parser:succeeded() then
      after.result = mapFn(after.result)
    end
    return after
  end
end

--- Base parsers
-- @section parsers

--- Parse any string literal
-- @param lit the literal to match
-- @return a parser function matching the literal
function Parsel.literal(lit)
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local match = string.sub(parser.input, parser.pos, parser.pos + #lit - 1)
    if lit == match then
      return {
        token = Token.new(match, parser.pos, parser.pos + #lit),
        parser = parser:advance(#lit),
        result = match
      }
    end
    return noMatch(parser, string.format("%s did not contain %s at position %d", parser.input, lit, parser.pos))
  end
end

--- Parse any alphabetic letter
-- @return a parser function
function Parsel.letter()
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local matched = string.match(string.sub(parser.input, parser.pos, parser.pos), "%a")
    if matched then
      return {
        token = Token.new(matched, parser.pos, parser.pos),
        parser = parser:advance(1),
        result = matched,
      }
    end
    return noMatch(parser,
      string.format("%s did not contain an alphabetic letter at position %d", parser.input, parser.pos))
  end
end

--- Parse any digit
-- @return a parser function
function Parsel.digit()
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local matched = string.match(string.sub(parser.input, parser.pos, parser.pos), "%d")
    if matched then
      return {
        token = Token.new(matched, parser.pos, parser.pos),
        parser = parser:advance(1),
        result = matched
      }
    end
    return noMatch(parser,
      string.format("%s did not contain a digit at position %d", parser.input, parser.pos))
  end
end

--- Match any single character
-- @return a parser function that matches any character
function Parsel.char()
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local match = string.sub(parser.input, parser.pos, parser.pos)
    return {
      token = Token.new(match, parser.pos, parser.pos),
      parser = parser:advance(1),
      result = match
    }
  end
end

--- Match anything but the specified literal single character
-- @param char character to exclude
-- @return a parser function that matches any character besides char
function Parsel.charExcept(char)
  return function(parser)
    if not parser:inBounds() then return noMatch(parser, "out of bounds") end
    local match = string.sub(parser.input, parser.pos, parser.pos)
    if match ~= char then
      return {
        token = Token.new(match, parser.pos, parser.pos),
        parser = parser:advance(1),
        result = match
      }
    else
      return noMatch(parser, string.format("%s matched %s at position %d", parser.input, char, parser.pos))
    end
  end
end

--- Match single newline char
-- @return a parser function that matches a newline character
function Parsel.newline()
  return Parsel.literal("\n")
end

--- Match whitespace
-- Matches at least one tab, space, or newline and consumes it
-- @return a parser function
function Parsel.whitespace()
  return Parsel.oneOrMore(Parsel.any(Parsel.literal(" "), Parsel.literal("\t"), Parsel.newline()))
end

--- Match optional whitespace
-- Optionally matches and consumes spaces, tabs and newlines
-- @return a parser function
function Parsel.optionalWhitespace()
  return Parsel.optional(Parsel.oneOrMore(Parsel.any(Parsel.literal(" "), Parsel.literal("\t"), Parsel.newline())))
end

--- Match any literal passed in, succeeds with the match
-- @param ... a sequence of literals to try in order
-- @return a parser function that matches any of the literals
function Parsel.anyLiteral(...)
  local literalParsers = {}
  for _, l in ipairs(table.pack(...)) do
    table.insert(literalParsers, Parsel.literal(l))
  end
  return Parsel.any(table.unpack(literalParsers))
end

--- Match the parsers string until the specified literal is found
-- @param literal the literal to match until
-- @return a parser function matched until right before the literal is found or end of string
-- @usage
--local untilEnd = parsel.untilLiteral('end')
--parsel.parse("if then end").result
-- -- "if then "
function Parsel.untilLiteral(literal)
  return function(parser)
    local start = parser.pos
    local stride = #literal - 1
    local strEnd = #parser.input - stride

    for i = start, strEnd, 1 do
      local slice = string.sub(parser.input, i, i + stride)
      if slice == literal then
        local capture = string.sub(parser.input, start, i - 1)
        return {
          token = Token.new(capture, start, i - 1),
          result = capture,
          parser = parser:advance(i - start)
        }
      end
    end

    local inputLen = #parser.input
    local capture = string.sub(parser.input, start, inputLen)
    return {
      token = Token.new(capture, start, inputLen),
      parser = parser:advance(inputLen - start),
      result = capture
    }
  end
end

--- Combinators
-- @section combinators

--- Parse any combinators specified in the list
-- @param ... a list of required parsers to parse in attempt in order
-- @return a combined parser function
function Parsel.any(...)
  local combinators = table.pack(...)
  return function(parser)
    for _, c in ipairs(combinators) do
      local result = parser:run(c)
      if result.parser:succeeded() then
        return result
      end
    end
    return noMatch(parser,
      string.format([[no parser matched %s at position %d (starting at "%s")]], parser.input, parser.pos,
        string.sub(parser.input, parser.pos, parser.pos)))
  end
end

--- Try first parser, and if that fails, try the second parser
-- @param p1 the first parser to try
-- @param p2 the second parser to try
-- @return a parser function
function Parsel.either(p1, p2)
  return Parsel.any(p1, p2)
end

--- Parse a combinator at least one time and until the parse fails
-- @param p the parser to attempt one or more times
-- @return a parser function
function Parsel.oneOrMore(p)
  return function(parser)
    local result = parser:run(p)
    if result.parser:succeeded() then
      local current
      local next = result
      local tokens = {}
      local results = {}
      repeat
        current = next
        insertToken(tokens, current)
        table.insert(results, current.result)
        next = current.parser:run(p)
      until not next.parser:succeeded()
      return {
        tokens = tokens,
        parser = current.parser,
        result = results
      }
    else
      return noMatch(result.parser,
        string.format("could not match %s at least once at position %d: %s", result.parser.input, result.parser.pos,
          result.parser.error))
    end
  end
end

--- Parse all combinators in sequence
-- @param ... a list of required parsers to parse in sequence
-- @return a combined parser function
function Parsel.seq(...)
  local combinators = table.pack(...)

  return function(parser)
    local tokens = {}
    local results = {}
    local current = { parser = parser }
    for _, c in ipairs(combinators) do
      current = current.parser:run(c)
      if not current.parser:succeeded() then
        return noMatch(current.parser, current.parser.error)
      end
      insertToken(tokens, current)
      table.insert(results, current.result)
    end
    return {
      tokens = tokens,
      parser = current.parser,
      result = results
    }
  end
end

--- Parse zero or more instances of combinators
-- @param p the parser to attempt zero or more times
-- @return a parser function
function Parsel.zeroOrMore(p)
  return function(parser)
    local result = parser:run(p)
    if result.parser:succeeded() then
      local tokens = {}
      insertToken(tokens, result)
      local results = { result.result }
      local currentParser = result.parser

      while true do
        local nextResult = currentParser:run(p)
        if not nextResult.parser:succeeded() then
          break
        else
          insertToken(tokens, nextResult)
          table.insert(results, nextResult.result)
          currentParser = nextResult.parser
        end
      end

      return {
        tokens = tokens,
        parser = currentParser,
        result = results
      }
    else
      -- zero matches
      return {
        tokens = {},
        parser = parser, -- return parser before result
        result = {}
      }
    end
  end
end

--- Optionally parse a combinator, return Parsel.nullResult if not matched
-- @param p parser to attempt, if failed, nullResult will be returned
-- @return a parser function
-- @see Parsel.nullResult
function Parsel.optional(p)
  return function(parser)
    local result = parser:run(p)
    if result.parser:succeeded() then
      return result
    else
      return {
        token = Parsel.nullResult,
        parser = parser,
        result = Parsel.nullResult,
      }
    end
  end
end

--- Returns a parser that lazily evaluates a function
-- @param f func (must return a parser)
-- @return a parser function
function Parsel.lazy(f)
  return function(parser)
    return parser:run(f())
  end
end

--- Match parsers delimited by successful parse of delim
-- the result is a table containing just the parsed values (delimiter ignored)
-- fails if parsing a delimiter then parser fails, or if the first parsing of p fails
-- @param p the parser to match repeatedly
-- @param delim the parser to match as a delimiter
-- @return a parser function
function Parsel.sepBy(p, delim)
  return function(parser)
    local parsed = parser:run(p)
    if not parsed.parser:succeeded() then
      return noMatch(parsed.parser, parsed.parser.error)
    end
    local tokens = {}
    insertToken(tokens, parsed)
    local results = { parsed.result }
    local current = parsed

    while true do
      local afterDelim = current.parser:run(delim)
      if not afterDelim.parser:succeeded() then
        break
      end

      current = afterDelim.parser:run(p)
      if not current.parser:succeeded() then
        return noMatch(current.parser, current.parser.error)
      end
      insertToken(tokens, current)
      table.insert(results, current.result)
    end
    return {
      tokens = tokens,
      result = results,
      parser = current.parser,
    }
  end
end

--- Match parsers delimited by successful parse of delim, but allow a trailing delimiter
-- @param p the parser to match repeatedly
-- @param delim the parser to match as a delimiter
-- @return a parser function
-- @see Parsel.sepBy
function Parsel.sepByAllowTrailing(p, delim)
  return function(parser)
    local parsed = parser:run(p)
    if not parsed.parser:succeeded() then
      return noMatch(parsed.parser, parsed.parser.error)
    end
    local tokens = {}
    insertToken(tokens, parsed)
    local results = { parsed.result }
    local current = parsed

    while true do
      local afterDelim = current.parser:run(delim)
      if not afterDelim.parser:succeeded() then
        break
      end

      current = afterDelim.parser:run(p)
      if not current.parser:succeeded() then
        current = afterDelim -- rewind
        break
      end
      insertToken(tokens, current)
      table.insert(results, current.result)
    end
    return {
      tokens = tokens,
      result = results,
      parser = current.parser,
    }
  end
end

--- Fails a parser if it matches condition set by exclusionFunc
-- @param p parser to wrap
-- @param exclusionFunc if this function returns true, the parser will fail
-- @return a parser function that parses p and fails if the exclusionFunc criteria is matched
-- @usage
--local ignoreOdd = parsel.exclude(parsel.digit(), function(d)
--  return tonumber(d)%2 == 1
--end)
--local evenString = parsel.oneOrMore(ignoreOdd)
--table.concat(parsel.parse("2468").result, "")
-- -- 246
function Parsel.exclude(p, exclusionFunc)
  return function(parser)
    local parsed = parser:run(p)
    if not parsed.parser:succeeded() then
      return noMatch(parsed.parser, parsed.parser.error)
    end
    local ignore = exclusionFunc(parsed.result)
    if ignore then
      return noMatch(parser,
        string.format([[ignore condition was true after parsing "%s" at position %d]], parsed.parser.input,
          parsed.parser.pos))
    end

    return parsed
  end
end

return Parsel
