local lu = require 'luaunit'
local parsel = require 'parsel'

local function assertResult(parsed, actual)
  lu.assertEquals(parsed.result, actual)
  lu.assertNil(parsed.parser.error)
end

local function assertErrContains(result, err)
  lu.assertStrContains(result.parser.error, err)
  lu.assertNil(result.tok)
end

local function assertTokens(actual, toks)
  lu.assertNil(actual.parser.error)
  for i, actualTok in ipairs(actual.tokens) do
    if actualTok == parsel.nullResult then
      lu.assertEquals(actualTok, toks[i])
    else
      lu.assertEquals(actualTok.match, toks[i])
    end
  end
  lu.assertEquals(#actual.tokens, #toks)
end

local function assertTok(actual, match, startPos, endPos)
  lu.assertNil(actual.parser.error)
  if startPos and endPos then
    lu.assertEquals(actual.token.match, match)
    lu.assertEquals(actual.token.startPos, startPos)
    lu.assertEquals(actual.token.endPos, endPos)
  else
    lu.assertEquals(actual.token.match, match)
  end
end

function TestStringLiteral()
  local matchTestLiteral = parsel.literal("test")
  local parsed = parsel.parse("teststring", matchTestLiteral)
  assertTok(parsed, "test")
  assertResult(parsed, "test")

  local matchTestEqual = parsel.literal("=")
  parsed = parsel.parse("===", matchTestEqual)
  assertTok(parsed, "=")
  assertResult(parsed, "=")

  local shouldFail = parsel.parse("otherstring", matchTestLiteral)
  assertErrContains(shouldFail, "otherstring did not contain test at position 1")

  parsed = parsel.parse("", matchTestLiteral)
  assertErrContains(parsed, "out of bounds")

  local testLiteralMapUpper = parsel.map(parsel.literal("teststring"), function(match) return string.upper(match) end)
  parsed = parsel.parse("teststring", testLiteralMapUpper)
  assertResult(parsed, "TESTSTRING")
end

function TestEither()
  local matchFirstOrSecond = parsel.either(parsel.literal("first"), parsel.literal("second"))
  local parsed = parsel.parse("firstsomething", matchFirstOrSecond)
  assertTok(parsed, "first", 1, 6)
  assertResult(parsed, "first")

  parsed = parsel.parse("secondsomething", matchFirstOrSecond)
  assertTok(parsed, "second", 1, 7)
  assertResult(parsed, "second")

  parsed = parsel.parse("somethingelse", matchFirstOrSecond)
  assertErrContains(parsed, "no parser matched somethingelse at position 1")

  parsed = parsel.parse(" ", parsel.either(parsel.letter(), parsel.digit()))
  assertErrContains(parsed, "no parser matched   at position 1")
end

function TestNumber()
  local match100 = parsel.number(100)
  local result = parsel.parse("100things", match100)
  assertTok(result, "100")

  result = parsel.parse('hundredthings', match100)
  assertErrContains(result, "hundredthings did not contain 100 at position 1")

  lu.assertErrorMsgContains("non-number passed to parsel.number", parsel.number, "hello world")
end

function TestLetter()
  local matchAlpha = parsel.letter()
  local parsed = parsel.parse("abc", matchAlpha)
  assertTok(parsed, "a", 1, 1)
  assertResult(parsed, "a")

  parsed = parsel.parse("123", matchAlpha)
  assertErrContains(parsed, "123 did not contain an alphabetic letter at position 1")
  parsed = parsel.parse(" ", matchAlpha)
  assertErrContains(parsed, "  did not contain an alphabetic letter at position 1")

  parsed = parsel.parse("", matchAlpha)
  assertErrContains(parsed, "out of bounds")

  local matchAlphaMapNode = parsel.map(matchAlpha,
    (function(letter) return { type = "letter", value = string.upper(letter) } end))
  parsed = parsel.parse("a", matchAlphaMapNode)
  assertResult(parsed, { type = "letter", value = "A" })
end

function TestDigit()
  local matchDigit = parsel.digit()
  local parsed = parsel.parse("123abc", matchDigit)
  assertTok(parsed, "1", 1, 1)
  assertResult(parsed, "1")

  parsed = parsel.parse("abc123", matchDigit)
  assertErrContains(parsed, "abc123 did not contain a digit at position 1")
  parsed = parsel.parse(" ", matchDigit)
  assertErrContains(parsed, "  did not contain a digit at position 1")

  parsed = parsel.parse("", matchDigit)
  assertErrContains(parsed, "out of bounds")

  local mapParse = parsel.map(matchDigit, function(digit) return tonumber(digit) end)
  parsed = parsel.parse("8", mapParse)
  assertResult(parsed, 8)
end

function TestOneOrMore()
  local matchAlphaWord = parsel.oneOrMore(parsel.letter())
  local result = parsel.parse("ident", matchAlphaWord)
  assertTokens(result, { "i", "d", "e", "n", "t" })
  assertTokens(result, { "i", "d", "e", "n", "t" })

  result = parsel.parse("i23", matchAlphaWord)
  assertTokens(result, { "i" })

  result = parsel.parse("234", matchAlphaWord)
  assertErrContains(result,
    "could not match 234 at least once at position 1: 234 did not contain an alphabetic letter at position 1")

  local mapJoin = parsel.map(matchAlphaWord, function(tokens) return table.concat(tokens, "") end)
  local parsed = parsel.parse("ident", mapJoin)
  assertResult(parsed, "ident")

  local identParser = parsel.map(
    parsel.zeroOrMore(parsel.letter()), function(tokens)
      return table.concat(tokens, "")
    end)
  assertResult(parsel.parse('local i2', identParser), "local")
end

function TestAny()
  local matchABC = parsel.any(parsel.literal("a"), parsel.literal("b"), parsel.literal("c"))
  local result = parsel.parse("a", matchABC)
  assertTok(result, "a")
  result = parsel.parse("b", matchABC)
  assertTok(result, "b")
  assertResult(result, "b")
  result = parsel.parse("c", matchABC)
  assertTok(result, "c")
  assertResult(result, "c")
  result = parsel.parse("d", matchABC)
  assertErrContains(result, "no parser matched d at position 1")
end

function TestSeq()
  local matchABC = parsel.seq(parsel.literal("a"), parsel.literal("b"), parsel.literal("c"))
  local result = parsel.parse("abcd", matchABC)
  assertTokens(result, { "a", "b", "c" })
  assertResult(result, { "a", "b", "c" })
  lu.assertEquals(result.parser.pos, 4)

  local matchLettersThenDigits = parsel.seq(parsel.literal("$"),
    parsel.seq(parsel.digit(), parsel.digit(), parsel.literal("."), parsel.digit(), parsel.digit()))
  result = parsel.parse("$12.34", matchLettersThenDigits)
  lu.assertEquals(result.tokens[1].match, "$")
  local subTokens = result.tokens[2]
  local expected = { "1", "2", ".", "3", "4" }
  for i, tok in ipairs(subTokens) do
    lu.assertEquals(tok.match, expected[i])
  end

  local parsed = parsel.parse("$12.34",
    parsel.map(matchLettersThenDigits, function(results) return tonumber(table.concat(results[2], "")) end))
  assertResult(parsed, 12.34)
end

function TestZeroOrMore()
  local matchAlphaWord = parsel.zeroOrMore(parsel.letter())
  local result = parsel.parse("ident", matchAlphaWord)
  assertTokens(result, { "i", "d", "e", "n", "t" })
  assertResult(result, { "i", "d", "e", "n", "t" })

  result = parsel.parse("i23", matchAlphaWord)
  assertTokens(result, { "i" })

  result = parsel.parse("234", matchAlphaWord)
  assertTokens(result, {})

  local mapJoin = parsel.map(matchAlphaWord, function(tokens) return table.concat(tokens, "") end)
  local parsed = parsel.parse("ident23432", mapJoin)
  assertResult(parsed, "ident")

  local identParser = parsel.map(
    parsel.zeroOrMore(parsel.letter()), function(tokens)
      return table.concat(tokens, "")
    end)
  assertResult(parsel.parse('local i2', identParser), "local")
end

function TestOptional()
  local matchOptionalDigit = parsel.seq(parsel.letter(), parsel.optional(parsel.digit()), parsel.letter())
  local parsed = parsel.parse("a1b", matchOptionalDigit)
  assertTokens(parsed, { "a", "1", "b" })
  assertResult(parsed, { "a", "1", "b" })

  parsed = parsel.parse("ab", matchOptionalDigit)
  assertTokens(parsed, { "a", parsel.nullResult, "b" })
  assertResult(parsed, { "a", parsel.nullResult, "b" })
end

function TestChar()
  local matchChar = parsel.char()
  local parsed = parsel.parse("123abc", matchChar)
  assertTok(parsed, "1", 1, 1)
  assertResult(parsed, "1")
  parsed = parsel.parse("abc", matchChar)
  assertTok(parsed, "a", 1, 1)
  assertResult(parsed, "a")

  parsed = parsel.parse("", matchChar)
  assertErrContains(parsed, "out of bounds")

  local mapParse = parsel.map(matchChar, function(digit) return tonumber(digit) end)
  parsed = parsel.parse("8", mapParse)
  assertResult(parsed, 8)
end

os.exit(lu.LuaUnit.run())
