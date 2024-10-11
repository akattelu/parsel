local p = require 'lua_parser'

local function printTable(t)
  local function printTableIndent(t2, indent)
    if (type(t2) == "table") then
      for pos, val in pairs(t2) do
        if (type(val) == "table") then
          if type(pos) == "string" then
            print(indent .. '"' .. pos .. '": ' .. "{")
          else
            print(indent .. pos .. ': ' .. "{")
          end
          printTableIndent(val, indent .. "  ")
          print(indent .. "}")
        elseif (type(val) == "string") then
          print(indent .. '"' .. pos .. '": "' .. val .. '"')
        else
          print(indent .. pos .. ": " .. tostring(val))
        end
      end
    else
      print(indent .. tostring(t2))
    end
  end

  if (type(t) == "table") then
    print("{")
    printTableIndent(t, "")
    print("}")
  else
    printTableIndent(t, "")
  end
end

local file = io.open("testdata/scratch.lua", "r")
local contents
if file then
  contents = file:read("*a")
end
local tree, err = p.parse(contents)
if err then
  print(err)
  os.exit(1)
end
printTable(tree)
os.exit(0)
