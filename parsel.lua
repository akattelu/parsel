local M = {}

local function printTable(t)
  local printTable_cache = {}

  local function sub_printTable(t2, indent)
    if (printTable_cache[tostring(t2)]) then
      print(indent .. "*" .. tostring(t2))
    else
      printTable_cache[tostring(t2)] = true
      if (type(t2) == "table") then
        for pos, val in pairs(t2) do
          if (type(val) == "table") then
            print(indent .. "[" .. pos .. "] => " .. tostring(t2) .. " {")
            sub_printTable(val, indent .. string.rep(" ", string.len(pos) + 8))
            print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
          elseif (type(val) == "string") then
            print(indent .. "[" .. pos .. '] => "' .. val .. '"')
          else
            print(indent .. "[" .. pos .. "] => " .. tostring(val))
          end
        end
      else
        print(indent .. tostring(t2))
      end
    end
  end

  if (type(t) == "table") then
    print(tostring(t) .. " {")
    sub_printTable(t, "  ")
    print("}")
  else
    sub_printTable(t, "  ")
  end
end

local function noMatch(parser, error)
  return {
    token = nil,
    parser = parser:withError(error),
    result = nil
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

function dlog(msg)
  if os.getenv("DEBUG") == "1" then
    if type(msg) == "table" then
      printTable(msg)
    else
      print(msg)
    end
  end
end

M.dlog = dlog

local function insertToken(t, result)
  if result.tokens then
    table.insert(t, result.tokens)
  elseif result.token then
    table.insert(t, result.token)
  end
end

function M.printTokens(result, prefix)
  if result.tokens then
    for _, tok in ipairs(result.tokens) do
      M.printTokens(tok, (prefix or "") .. "\t")
    end
  end
  if type(result) == "table" then
    for _, tok in ipairs(result) do
      M.printTokens(tok, (prefix or "") .. "\t")
    end
  end
  if result.match then
    print(string.format("%sMatch: %s, [%d, %d]", prefix or "", result.match, result.startPos, result.endPos))
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
        parser = parser:advance(#lit),
        result = match
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
        parser = parser:advance(1),
        result = matched,
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
        parser = parser:advance(1),
        result = matched
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
      local results = {}
      repeat
        current = next
        insertToken(tokens, current)
        table.insert(results, current.result)
        next = current.parser:run(c)
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

-- Map the result of a parser
function M.map(parserFn, mapFn)
  return function(parser)
    local after = parserFn(parser)
    after.result = mapFn(after.result)
    return after
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

-- Parse zero or more instances of combinators
function M.zeroOrMore(c)
  return function(parser)
    local result = parser:run(c)
    if result.parser:succeeded() then
      local current
      local next = result
      local tokens = {}
      local results = {}
      repeat
        current = next
        insertToken(tokens, current)
        table.insert(results, current.result)
        next = current.parser:run(c)
      until not next.parser:succeeded()
      return {
        tokens = tokens,
        parser = current.parser,
        result = results
      }
    else
      -- zero matches
      return {
        tokens = {},
        parser = parser,
        result = {}
      }
    end
  end
end

return M
