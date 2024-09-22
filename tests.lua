local lu = require 'luaunit'
local parsel = require 'parsel'

local function assertErrContains(result, err)
  lu.assertStrContains(result.parser.error, err)
  lu.assertNil(result.tok)
end


local function assertTok(actual, match, startPos, endPos)
  lu.assertNil(actual.parser.error)
  if startPos and endPos then
    lu.assertEquals(actual.token, parsel.token.new(match, startPos, endPos))
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
end

function TestEither()
  local matchFirstOrSecond = parsel.either(parsel.literal("first"), parsel.literal("second"))
  local result = parsel.parse("firstsomething", matchFirstOrSecond)
  assertTok(result, "first", 1, 6)

  result = parsel.parse("secondsomething", matchFirstOrSecond)
  assertTok(result, "second", 1, 7)

  result = parsel.parse("somethingelse", matchFirstOrSecond)
  assertErrContains(result, "neither parser found a match")
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
end

os.exit(lu.LuaUnit.run())
