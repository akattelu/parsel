local lu = require 'luaunit'
local p = require 'lua_parser'


local function assertTree(tree, err, expected)
  print(tree, err, expected)
  lu.assertNil(err)
  lu.assertEquals(tree.type, expected.type)
end

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
    y = 5]])
  lu.assertNil(err)
  if tree then
    if tree[1] then
      assertType(tree[1], "assignment")
      lu.assertEquals(tree[1].scope, "LOCAL")
      assertIdentifier(tree[1].ident, "x")
      assertNumber(tree[1].value, 2)
    end
    if tree[1] then
      assertType(tree[1], "assignment")
      lu.assertEquals(tree[1].scope, "LOCAL")
      assertIdentifier(tree[1].ident, "x")
      assertNumber(tree[1].value, 2)
    end
  else
    lu.fail("tree was nil")
  end
end

os.exit(lu.LuaUnit.run())
