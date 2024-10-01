---@diagnostic disable: need-check-nil
local lu = require 'luaunit'
local p = require 'lua_parser'

local function assertType(tree, expected)
  lu.assertEquals(tree.type, expected)
end

local function assertIdentifier(tree, expected)
  lu.assertEquals(tree.type, "identifier")
  lu.assertEquals(tree.value, expected)
end

local function assertNumber(tree, expected)
  lu.assertEquals(tree.type, "number")
  lu.assertEquals(tree.value, expected)
end

local function assertString(tree, expected)
  lu.assertEquals(tree.type, "string")
  lu.assertEquals(tree.value, expected)
end

local function assertBool(tree, expected)
  lu.assertEquals(tree.type, "boolean")
  lu.assertEquals(tree.value, expected)
end

local function assertNilValue(tree)
  lu.assertEquals(tree.type, "nil")
  lu.assertEquals(tree.value, nil)
end

function TestDeclaration()
  local tree, err = p.parseProgramString("local x")
  lu.assertNil(err)
  if tree and tree[1] then
    assertType(tree[1], "declaration")
    lu.assertEquals(tree[1].scope, "LOCAL")
    assertIdentifier(tree[1].identifier, "x")
  else
    lu.fail("tree was nil")
  end
end

function TestAssignment()
  local tree, err = p.parseProgramString([[
    local x = 2
    y = 5
    local z = 10]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)

  assertType(tree[1], "assignment")
  lu.assertEquals(tree[1].scope, "LOCAL")
  assertIdentifier(tree[1].ident, "x")
  assertNumber(tree[1].value, 2)

  assertType(tree[2], "assignment")
  lu.assertEquals(tree[2].scope, "GLOBAL")
  assertIdentifier(tree[2].ident, "y")
  assertNumber(tree[2].value, 5)
  assertType(tree[2], "assignment")

  lu.assertEquals(tree[3].scope, "LOCAL")
  assertIdentifier(tree[3].ident, "z")
  assertNumber(tree[3].value, 10)
end

function TestPrimitives()
  local tree, err = p.parseProgramString([[
    5
    12.34
    "hello world"
    true
    false
    nil]])
  lu.assertEquals(#tree, 6)
  lu.assertNil(err)
  assertNumber(tree[1], 5)
  assertNumber(tree[2], 12.34)
  assertString(tree[3], "hello world")
  assertBool(tree[4], true)
  assertBool(tree[5], false)
  assertNilValue(tree[6])
end

os.exit(lu.LuaUnit.run())
