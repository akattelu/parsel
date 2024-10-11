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
  assertType(tree, "infix_expression")
  lu.assertEquals(tree.op, op)
  assertNumber(tree.lhs, lhs)
  assertNumber(tree.rhs, rhs)
end

local function assertInfixBools(tree, lhs, op, rhs)
  lu.assertEquals(tree.op, op)
  assertBool(tree.lhs, lhs)
  assertBool(tree.rhs, rhs)
end

local function assertInfixStrings(tree, lhs, op, rhs)
  lu.assertEquals(tree.op, op)
  assertString(tree.lhs, lhs)
  assertString(tree.rhs, rhs)
end

local function assertAccessIdents(tree, lhs, rhs)
  assertType(tree, "access_expression")
  assertIdentifier(tree.lhs, lhs)
  assertIdentifier(tree.index, rhs)
end

local function assertAssignmentNumber(tree, ident, numVal, scope)
  lu.assertEquals(tree.type, "assignment")
  assertIdentifier(tree.ident, ident)
  assertNumber(tree.value, numVal)
  lu.assertEquals(tree.scope, scope or "LOCAL")
end

local function assertTableAccess(tree, baseTableName, fieldName)
  assertType(tree, 'table_access_expression')
  assertIdentifier(tree.lhs, baseTableName)
  assertType(tree.index, "access_key_string")
  lu.assertEquals(tree.index.name, fieldName)
end

local function assertTableListValues(tree, items)
  assertType(tree, "table_literal")
  lu.assertEquals(#tree.items, #items)
  for i, v in ipairs(tree.items) do
    assertType(v, "table_item")
    lu.assertEquals(v.key, i)
    lu.assertEquals(v.value.value, items[i])
  end
end

local function assertTableDictValues(tree, items)
  assertType(tree, "table_literal")
  local expectedLen = 0
  for _, _ in pairs(items) do
    expectedLen = expectedLen + 1
  end
  lu.assertEquals(#tree.items, expectedLen)
  for _, actual in pairs(tree.items) do
    assertType(actual, "table_item")
    lu.assertNotNil(actual.key)
    local expected = items[actual.key]
    lu.assertEquals(actual.value.value, expected)
  end
end

function TestIdent()
  local _, err = p.parseString("if", p.ident)
  lu.assertStrContains(err, "ignore condition was true after parsing")
end

function TestDeclaration()
  local tree, err = p.parseProgramString("local x")
  lu.assertNil(err)
  assertType(tree[1], "declaration")
  lu.assertEquals(tree[1].scope, "LOCAL")
  assertIdentifier(tree[1].identifier, "x")
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
    x
    'hello world'
    ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 8)
  assertNumber(tree[1], 5)
  assertNumber(tree[2], 12.34)
  assertString(tree[3], "hello world")
  assertBool(tree[4], true)
  assertBool(tree[5], false)
  assertNilValue(tree[6])
  assertIdentifier(tree[7], "x")
  assertString(tree[8], "hello world")
end

function TestMultilineString()
  local tree, err = p.parseProgramString("[[hello world]]")
  lu.assertNil(err)
  lu.assertEquals(#tree, 1)
  assertString(tree[1], "hello world")
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
  assertType(tree[1], "prefix_expression")

  assertBool(tree[2].rhs.rhs, true)
  lu.assertEquals(tree[2].op, "not")
  lu.assertEquals(tree[2].rhs.op, "not")
  assertType(tree[2], "prefix_expression")
  assertType(tree[2].rhs, "prefix_expression")
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
    1 + (2 + 3) + 4
    true and true
    false or true
    "hello ".."world"
    1 < 2
    2 <= 2
    2 > 1
    2 >= 2
  ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 16)
  for _, v in ipairs(tree) do
    assertType(v, "infix_expression")
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
  assertInfixBools(tree[10], true, "and", true)
  assertInfixBools(tree[11], false, "or", true)
  assertInfixStrings(tree[12], "hello ", "..", "world")
  assertInfixNumbers(tree[13], 1, "<", 2)
  assertInfixNumbers(tree[14], 2, "<=", 2)
  assertInfixNumbers(tree[15], 2, ">", 1)
  assertInfixNumbers(tree[16], 2, ">=", 2)
end

function TestIfThenStmt()
  local tree, err = p.parseProgramString([[
      if true == true then local x = 1 end
      if true == true then
        local x = 1
        local y = 2
      end
      if true then end
      ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertType(tree[1], "conditional")
  assertInfixBools(tree[1].cond, true, "==", true)
  assertAssignmentNumber(tree[1].then_block[1], "x", 1)

  assertType(tree[2], "conditional")
  assertInfixBools(tree[2].cond, true, "==", true)
  assertAssignmentNumber(tree[2].then_block[1], "x", 1)
  assertAssignmentNumber(tree[2].then_block[2], "y", 2)

  assertType(tree[3], "conditional")
  assertBool(tree[3].cond, true)
  lu.assertEquals(tree[3].then_block, {})
end

function TestIfThenElseStmt()
  local tree, err = p.parseProgramString([[
      if true == true then local x = 1 else local y = 2 end
      if true == true then
        local x = 1
        local y = 2
      else
        local z = 3
      end
      if true then else end
      ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertType(tree[1], "conditional")
  assertInfixBools(tree[1].cond, true, "==", true)
  assertAssignmentNumber(tree[1].then_block[1], "x", 1)
  assertAssignmentNumber(tree[1].else_block[1], "y", 2)

  assertType(tree[2], "conditional")
  assertInfixBools(tree[2].cond, true, "==", true)
  assertAssignmentNumber(tree[2].then_block[1], "x", 1)
  assertAssignmentNumber(tree[2].then_block[2], "y", 2)
  assertAssignmentNumber(tree[2].else_block[1], "z", 3)

  assertType(tree[3], "conditional")
  assertBool(tree[3].cond, true)
  lu.assertEquals(tree[3].then_block, {})
  lu.assertEquals(tree[3].else_block, {})
end

function TestSwitchStatement()
  local tree, err = p.parseProgramString([[
      if 1 == 2 then
        local x = 1
      elseif 2 == 3 then
        local y = 2
      elseif 3 == 4 then
        local z = 3
      else
        local n = 4
      end
      ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 1)
  assertType(tree[1], "switch")
  assertInfixNumbers(tree[1].cases[1].cond, 1, "==", 2)
  assertAssignmentNumber(tree[1].cases[1].block[1], "x", 1)
  assertInfixNumbers(tree[1].cases[2].cond, 2, "==", 3)
  assertAssignmentNumber(tree[1].cases[2].block[1], "y", 2)
  assertInfixNumbers(tree[1].cases[3].cond, 3, "==", 4)
  assertAssignmentNumber(tree[1].cases[3].block[1], "z", 3)
  assertAssignmentNumber(tree[1].else_block[1], "n", 4)
end

function TestWhileStmt()
  local tree, err = p.parseProgramString([[
      while true do 1 + 2 end

      while false do
        local x = 1
      end

      while true do end
     ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertType(tree[1], "while")
  assertBool(tree[1].cond, true)
  assertInfixNumbers(tree[1].block[1], 1, "+", 2)

  assertType(tree[2], "while")
  assertBool(tree[2].cond, false)
  assertAssignmentNumber(tree[2].block[1], "x", 1)

  assertType(tree[3], "while")
  assertBool(tree[3].cond, true)
  lu.assertEquals(tree[3].block, {})
end

function TestRepeatStmt()
  local tree, err = p.parseProgramString([[
      repeat 1 + 2 until false

      repeat
        local x = 1
      until x

      repeat until false
     ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertType(tree[1], "repeat")
  assertBool(tree[1].cond, false)
  assertInfixNumbers(tree[1].block[1], 1, "+", 2)

  assertType(tree[2], "repeat")
  assertIdentifier(tree[2].cond, 'x')
  assertAssignmentNumber(tree[2].block[1], "x", 1)

  assertType(tree[3], "repeat")
  assertBool(tree[3].cond, false)
  lu.assertEquals(tree[3].block, {})
end

function TestReturn()
  local tree, err = p.parseString([[return 1 + 2]], p.returnStmt)
  lu.assertNil(err)
  assertType(tree, "return")
  assertInfixNumbers(tree.value, 1, "+", 2)
end

function TestAnonFunctions()
  local tree, err = p.parseProgramString([[
      local w = function() end
      local x = function(arg1) end
      local y = function(arg1, arg2, arg3) end
      local z = function(...) end
  ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 4)
  for _, v in ipairs(tree) do
    assertType(v.value, 'function')
    lu.assertEquals(v.value.block, {})
    lu.assertNil(v.value.name)
  end

  lu.assertEquals(tree[1].value.args, {})
  lu.assertEquals(tree[2].value.args, { "arg1" })
  lu.assertEquals(tree[3].value.args, { "arg1", "arg2", "arg3" })
  lu.assertEquals(tree[4].value.args, { "..." })
end

function TestNamedFunction()
  local tree, err = p.parseProgramString([[
      function name(arg1) end

      function name()
        local x = 1
        local y = 1
        return 1 + 2
      end

      function name() end

      function name(arg1, arg2, arg3) end

      function name(...) end
     ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 5)
  for _, v in ipairs(tree) do
    assertType(v, 'function')
    lu.assertEquals(v.name, 'name')
    lu.assertEquals(v.scope, 'GLOBAL')
  end

  lu.assertEquals(tree[1].args, { "arg1" })
  lu.assertEquals(tree[1].block, {})

  lu.assertEquals(tree[2].args, {})
  assertAssignmentNumber(tree[2].block[1], "x", 1)
  assertAssignmentNumber(tree[2].block[2], "y", 1)
  assertType(tree[2].block[3], "return")
  assertInfixNumbers(tree[2].block[3].value, 1, "+", 2)

  lu.assertEquals(tree[3].block, {})
  lu.assertEquals(tree[3].args, {})

  lu.assertEquals(tree[4].block, {})
  lu.assertEquals(tree[4].args, { "arg1", "arg2", "arg3" })

  lu.assertEquals(tree[5].block, {})
  lu.assertEquals(tree[5].args, { "..." })
end

function TestFunctionNameWithDots()
  local tree, err = p.parseProgramString([[function name.with.dots(arg1) end]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 1)
  assertType(tree[1], 'function')
  lu.assertEquals(tree[1].name, 'name.with.dots')
  lu.assertEquals(tree[1].args, { "arg1" })
  lu.assertEquals(tree[1].block, {})
end

function TestLocalFunction()
  local tree, err = p.parseProgramString([[local function name(arg1) end]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 1)
  assertType(tree[1], 'function')
  lu.assertEquals(tree[1].name, 'name')
  lu.assertEquals(tree[1].args, { "arg1" })
  lu.assertEquals(tree[1].block, {})
  lu.assertEquals(tree[1].scope, "LOCAL")
end

function TestLineComments()
  local tree, err = p.parseProgramString([[
    --comment1
    --comment2
    local x = 4--comment3
    local y--comment4
    = 4-- comment5--comment6
-- comment7

    return 1 + 2 -- test
]])
  lu.assertNil(err)
  assertAssignmentNumber(tree[1], "x", 4)
  assertAssignmentNumber(tree[2], "y", 4)
  assertInfixNumbers(tree[3].value, 1, "+", 2)
end

function TestTableAccess()
  local tree, err = p.parseProgramString([[
  t.a
  t.b
  t.a.b.c
  (1+2).a
]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 4)

  assertTableAccess(tree[1], "t", "a")
  assertTableAccess(tree[2], "t", "b")
  assertTableAccess(tree[3].lhs.lhs, "t", "a")
  lu.assertEquals(tree[3].lhs.index.name, "b")
  lu.assertEquals(tree[3].index.name, "c")
  assertInfixNumbers(tree[4].lhs, 1, "+", 2)
  lu.assertEquals(tree[4].index.name, "a")
end

function TestTableListLiterals()
  local tree, err = p.parseProgramString([[
      {}
      { 1 }
      { 1, 2, 3 }
    ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertTableListValues(tree[1], {})
  assertTableListValues(tree[2], { 1 })
  assertTableListValues(tree[3], { 1, 2, 3 })
end

function TestTableDictLiterals()
  local tree, err = p.parseProgramString([[
      {}
      { a = 1 }
      { a = 1, b = 2, c = 3 }
    ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 3)
  assertTableDictValues(tree[1], {})
  assertTableDictValues(tree[2], { a = 1 })
  assertTableDictValues(tree[3], { a = 1, b = 2, c = 3 })
end

function TestTableRecursive()
  local tree, err = p.parseProgramString([[
      { { 1 }, { 2 } }
      { a = { b = 2 } }
    ]])
  lu.assertNil(err)
  lu.assertEquals(#tree, 2)
  assertTableListValues(tree[1].items[1].value, { 1 })
  assertTableListValues(tree[1].items[2].value, { 2 })
  assertTableDictValues(tree[2].items[1].value, { b = 2 })
end

os.exit(lu.LuaUnit.run())
