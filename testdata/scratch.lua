local Parsel = {}

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

  -- if (type(t) == "table") then
  --   print(tostring(t) .. " {")
  --   sub_printTable(t, "  ")
  --   print("}")
  -- else
  --   sub_printTable(t, "  ")
  -- end
end

-- local function noMatch(parser, error)
--   return {
--     token = nil,
--     parser = parser:withError(error),
--     result = nil
--   }
-- end


--- a result indicating an optional match
-- returned as a placeholder when an optional match did not succeed
-- @field type always "NULL"
-- @see Parsel.optional
-- Parsel.nullResult = { type = "NULL" }

-- local Token = {
--   new = function(match, startPos, endPos)
--     return {
--       match = match,
--       startPos = startPos,
--       endPos = endPos
--     }
--   end
-- }

-- local function dlog(msg)
--   if os.getenv("DEBUG") == "1" then
--     if type(msg) == "table" then
--       printTable(msg)
--     else
--       print(msg)
--     end
--   end
-- end

-- Parsel.dlog = dlog

-- local function insertToken(t, result)
--   if result.tokens then
--     table.insert(t, result.tokens)
--   elseif result.token then
--     table.insert(t, result.token)
--   end
-- end

-- Parser = {
--   new = function(input, pos, error)
--     return {
--       input = input,
--       pos = pos or 1,
--       error = error or nil,
--       advance = function(self, amt)
--         return Parser.new(self.input, self.pos + amt, self.error)
--       end,
--       withError = function(self, err)
--         return Parser.new(self.input, self.pos, err)
--       end,
--       run = function(self, parser)
--         return parser(self)
--       end,
--       print = function(self)
--         print(string.format("Parser { input: %s, pos: %d, error: %s }", self.input, self.pos, self.error))
--       end,
--       succeeded = function(self)
--         return not self.error
--       end,
--       inBounds = function(self)
--         return self.pos <= #self.input
--       end
--     }
--   end,
-- }

--- Entry point to parsing a string
-- @param input the string to match
-- @param parser to use on the string
-- @return the result returned by the parser
-- function Parsel.parse(input, parser)
--   local p = Parser.new(input)
--   return p:run(parser)
-- end

--- Map the result of a parser
-- @param base parser to run and map the result of
-- @param mapFn function to apply to the result of the parser operation
-- @return a new parser function with a mapped result
-- function Parsel.map(base, mapFn)
--   return function(parser)
--     local after = base(parser)
--     if after.parser:succeeded() then
--       after.result = mapFn(after.result)
--     end
--     return after
--   end
-- end

--- Base parsers
-- @section parsers

--- Parse any string literal
-- @param lit the literal to match
-- @return a parser function matching the literal
-- function Parsel.literal(lit)
--   return function(parser)
--     if not parser:inBounds() then return noMatch(parser, "out of bounds") end
--     local match = string.sub(parser.input, parser.pos, parser.pos + #lit - 1)
--     if lit == match then
--       return {
--         token = Token.new(match, parser.pos, parser.pos + #lit),
--         parser = parser:advance(#lit),
--         result = match
--       }
--     end
--     return noMatch(parser, string.format("%s did not contain %s at position %d", parser.input, lit, parser.pos))
--   end
-- end

--- Parse any alphabetic letter
-- @return a parser function
-- function Parsel.letter()
--   return function(parser)
--     if not parser:inBounds() then return noMatch(parser, "out of bounds") end
--     local matched = string.match(string.sub(parser.input, parser.pos, parser.pos), "%a")
--     if matched then
--       return {
--         token = Token.new(matched, parser.pos, parser.pos),
--         parser = parser:advance(1),
--         result = matched,
--       }
--     end
--     return noMatch(parser,
--       string.format("%s did not contain an alphabetic letter at position %d", parser.input, parser.pos))
--   end
-- end

--- Parse any digit
-- @return a parser function
-- function Parsel.digit()
--   return function(parser)
--     if not parser:inBounds() then return noMatch(parser, "out of bounds") end
--     local matched = string.match(string.sub(parser.input, parser.pos, parser.pos), "%d")
--     if matched then
--       return {
--         token = Token.new(matched, parser.pos, parser.pos),
--         parser = parser:advance(1),
--         result = matched
--       }
--     end
--     return noMatch(parser,
--       string.format("%s did not contain a digit at position %d", parser.input, parser.pos))
--   end
-- end

--- Match any single character
-- @return a parser function that matches any character
-- function Parsel.char()
--   return function(parser)
--     if not parser:inBounds() then return noMatch(parser, "out of bounds") end
--     local match = string.sub(parser.input, parser.pos, parser.pos)
--     return {
--       token = Token.new(match, parser.pos, parser.pos),
--       parser = parser:advance(1),
--       result = match
--     }
--   end
-- end

--- Match anything but the specified literal single character
-- @param char character to exclude
-- @return a parser function that matches any character besides char
-- function Parsel.charExcept(char)
--   return function(parser)
--     if not parser:inBounds() then return noMatch(parser, "out of bounds") end
--     local match = string.sub(parser.input, parser.pos, parser.pos)
--     if match ~= char then
--       return {
--         token = Token.new(match, parser.pos, parser.pos),
--         parser = parser:advance(1),
--         result = match
--       }
--     else
--       return noMatch(parser, string.format("%s matched %s at position %d", parser.input, char, parser.pos))
--     end
--   end
-- end

--- Match single newline char
-- @return a parser function that matches a newline character
-- function Parsel.newline()
--   return Parsel.literal("\n")
-- end

--- Match whitespace
-- Matches at least one tab, space, or newline and consumes it
-- @return a parser function
-- function Parsel.whitespace()
--   return Parsel.oneOrMore(Parsel.any(Parsel.literal(" "), Parsel.literal("\t"), Parsel.newline()))
-- end

--- Match optional whitespace
-- Optionally matches and consumes spaces, tabs and newlines
-- @return a parser function
-- function Parsel.optionalWhitespace()
--   return Parsel.optional(Parsel.oneOrMore(Parsel.any(Parsel.literal(" "), Parsel.literal("\t"), Parsel.newline())))
-- end

--- Match any literal passed in, succeeds with the match
-- @param ... a sequence of literals to try in order
-- @return a parser function that matches any of the literals
-- function Parsel.anyLiteral(...)
--   local literalParsers = {}
--   for _, l in ipairs(table.pack(...)) do
--     table.insert(literalParsers, Parsel.literal(l))
--   end
--   return Parsel.any(table.unpack(literalParsers))
-- end

--- Match the parsers string until the specified literal is found
-- @param literal the literal to match until
-- @return a parser function matched until right before the literal is found or end of string
-- @usage
--local untilEnd = parsel.untilLiteral('end')
--parsel.parse("if then end").result
-- -- "if then "
-- function Parsel.untilLiteral(literal)
--   return function(parser)
--     local start = parser.pos
--     local stride = #literal - 1
--     local strEnd = #parser.input - stride

--     for i = start, strEnd, 1 do
--       local slice = string.sub(parser.input, i, i + stride)
--       if slice == literal then
--         local capture = string.sub(parser.input, start, i - 1)
--         return {
--           token = Token.new(capture, start, i - 1),
--           result = capture,
--           parser = parser:advance(i - start)
--         }
--       end
--     end

--     local inputLen = #parser.input
--     local capture = string.sub(parser.input, start, inputLen)
--     return {
--       token = Token.new(capture, start, inputLen),
--       parser = parser:advance(inputLen - start),
--       result = capture
--     }
--   end
-- end
