---@diagnostic disable: need-check-nil, param-type-mismatch
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

local function assertInfixNumbers(tree, lhs, op, rhs)
  lu.assertEquals(tree.op, op)
  assertNumber(tree.lhs, lhs)
  assertNumber(tree.rhs, rhs)
end

local function assertInfixBools(tree, lhs, op, rhs)
  lu.assertEquals(tree.op, op)
  assertBool(tree.lhs, lhs)
  assertBool(tree.rhs, rhs)
end

local function assertAssignmentNumber(tree, ident, numVal, scope)
  lu.assertEquals(tree.type, "assignment")
  assertIdentifier(tree.ident, ident)
  assertNumber(tree.value, numVal)
  lu.assertEquals(tree.scope, scope or "LOCAL")
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

  assertAssignmentNumber(tree[1], "x", 2)
  assertAssignmentNumber(tree[2], "y", 5, "GLOBAL")
  assertAssignmentNumber(tree[3], "z", 10)
end

function TestPrimitives()
  local tree, err = p.parseProgramString([[
    5
    12.34
    "hello world"
    true
    false
    nil
    x]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 7)
  assertNumber(tree[1], 5)
  assertNumber(tree[2], 12.34)
  assertString(tree[3], "hello world")
  assertBool(tree[4], true)
  assertBool(tree[5], false)
  assertNilValue(tree[6])
  assertIdentifier(tree[7], "x")
end

function TestParenthesized()
  local tree, err = p.parseProgramString([[
    (1)
    (12.34)
    (1 + 2)
    (1 + (2 + 3))]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 4)
  assertNumber(tree[1], 1)
  assertNumber(tree[2], 12.34)
  assertNumber(tree[3].lhs, 1)
  lu.assertEquals(tree[3].op, '+')
  assertNumber(tree[3].rhs, 2)
  assertNumber(tree[4].rhs.lhs, 2)
  lu.assertEquals(tree[4].rhs.op, '+')
  assertNumber(tree[4].rhs.rhs, 3)
end

function TestNotExpr()
  local tree, err = p.parseProgramString([[
    not true
    not not true]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 2)
  assertBool(tree[1].rhs, true)
  lu.assertEquals(tree[1].op, "not")
  lu.assertEquals(tree[1].type, "prefix_expression")

  assertBool(tree[2].rhs.rhs, true)
  lu.assertEquals(tree[2].op, "not")
  lu.assertEquals(tree[2].rhs.op, "not")
  lu.assertEquals(tree[2].type, "prefix_expression")
  lu.assertEquals(tree[2].rhs.type, "prefix_expression")
end

function TestPrefixExpression()
  local tree, err = p.parseProgramString([[-1]])
  lu.assertNil(err)
  assertNumber(tree[1].rhs, 1)
  lu.assertEquals(tree[1].op, "-")
  lu.assertEquals(tree[1].type, "prefix_expression")
end

function TestInfix()
  local tree, err = p.parseProgramString([[
    1 + 2
    3 - 4
    123 * 456
    1 / 2
    3^4
    true == true
    false ~= true
    1 + (2 + 3)
    1 + (2 + 3) + 4]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 9)
  for _, v in ipairs(tree) do
    lu.assertEquals(v.type, "infix_expression")
  end
  assertInfixNumbers(tree[1], 1, "+", 2)
  assertInfixNumbers(tree[2], 3, "-", 4)
  assertInfixNumbers(tree[3], 123, "*", 456)
  assertInfixNumbers(tree[4], 1, "/", 2)
  assertInfixNumbers(tree[5], 3, "^", 4)
  assertInfixBools(tree[6], true, "==", true)
  assertInfixBools(tree[7], false, "~=", true)
  assertNumber(tree[8].lhs, 1)
  lu.assertEquals(tree[8].op, "+")
  assertInfixNumbers(tree[8].rhs, 2, "+", 3)
  assertNumber(tree[9].lhs, 1)
  lu.assertEquals(tree[9].rhs.op, "+")
  assertInfixNumbers(tree[9].rhs.lhs, 2, "+", 3)
  assertNumber(tree[9].rhs.rhs, 4)
end

function TestIfThenStmt()
  local tree, err = p.parseProgramString([[
      if true == true then local x = 1 end

      if true == true then
        local x = 1
      end]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 2)
  lu.assertEquals(tree[1].type, "conditional")
  assertInfixBools(tree[1].cond, true, "==", true)
  assertAssignmentNumber(tree[1].then_block[1], "x", 1)

  p.dlog(tree[2])
  lu.assertEquals(tree[2].type, "conditional")
  assertInfixBools(tree[2].cond, true, "==", true)
  assertAssignmentNumber(tree[2].then_block[1], "x", 1)
end

os.exit(lu.LuaUnit.run())
