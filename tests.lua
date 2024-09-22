local lu = require 'luaunit'
local parsel = require 'parsel'

local function assertErrContains(result, err)
  lu.assertStrContains(result.parser.error, err)
  lu.assertNil(result.tok)
end

local function assertTokens(actual, toks)
  lu.assertNil(actual.parser.error)
  for i, actualTok in ipairs(actual.tokens) do
    lu.assertEquals(actualTok.match, toks[i])
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
  local result = parsel.parse("teststring", matchTestLiteral)
  assertTok(result, "test")

  local shouldFail = parsel.parse("otherstring", matchTestLiteral)
  assertErrContains(shouldFail, "otherstring did not contain test at position 1")

  result = parsel.parse("", matchTestLiteral)
  assertErrContains(result, "out of bounds")
end

function TestEither()
  local matchFirstOrSecond = parsel.either(parsel.literal("first"), parsel.literal("second"))
  local result = parsel.parse("firstsomething", matchFirstOrSecond)
  assertTok(result, "first", 1, 6)

  result = parsel.parse("secondsomething", matchFirstOrSecond)
  assertTok(result, "second", 1, 7)

  result = parsel.parse("somethingelse", matchFirstOrSecond)
  assertErrContains(result, "no parser matched somethingelse at position 1")
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
  local result = parsel.parse("abc", matchAlpha)
  assertTok(result, "a", 1, 2)

  result = parsel.parse("123", matchAlpha)
  assertErrContains(result, "123 did not contain an alphabetic letter at position 1")

  result = parsel.parse("", matchAlpha)
  assertErrContains(result, "out of bounds")
end

function TestDigit()
  local matchDigit = parsel.digit()
  local result = parsel.parse("123abc", matchDigit)
  assertTok(result, "1", 1, 2)

  result = parsel.parse("abc123", matchDigit)
  assertErrContains(result, "abc123 did not contain a digit at position 1")

  result = parsel.parse("", matchDigit)
  assertErrContains(result, "out of bounds")
end

function TestOneOrMore()
  local matchAlphaWord = parsel.oneOrMore(parsel.letter())
  local result = parsel.parse("ident", matchAlphaWord)
  assertTokens(result, { "i", "d", "e", "n", "t" })

  result = parsel.parse("i23", matchAlphaWord)
  assertTokens(result, { "i" })

  result = parsel.parse("234", matchAlphaWord)
  assertErrContains(result,
    "could not match 234 at least once at position 1: 234 did not contain an alphabetic letter at position 1")
end

function TestAny()
  local matchABC = parsel.any(parsel.literal("a"), parsel.literal("b"), parsel.literal("c"))
  local result = parsel.parse("a", matchABC)
  assertTok(result, "a")
  result = parsel.parse("b", matchABC)
  assertTok(result, "b")
  result = parsel.parse("c", matchABC)
  assertTok(result, "c")
  result = parsel.parse("d", matchABC)
  assertErrContains(result, "no parser matched d at position 1")
end

function TestSeq()
  local matchABC = parsel.seq(parsel.literal("a"), parsel.literal("b"), parsel.literal("c"))
  local result = parsel.parse("abcd", matchABC)
  assertTokens(result, { "a", "b", "c" })
  lu.assertEquals(result.parser.pos, 4)
end

function TestZeroOrMore()
  local matchAlphaWord = parsel.zeroOrMore(parsel.letter())
  local result = parsel.parse("ident", matchAlphaWord)
  assertTokens(result, { "i", "d", "e", "n", "t" })

  result = parsel.parse("i23", matchAlphaWord)
  assertTokens(result, { "i" })

  result = parsel.parse("234", matchAlphaWord)
  assertTokens(result, {})
end

os.exit(lu.LuaUnit.run())
