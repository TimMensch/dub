--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'inherit' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector (inherit)')

local ins = dub.Inspector {
  doc_dir = 'test/tmp',
  INPUT   = 'test/fixtures/inherit',
}

--=============================================== TESTS

function should.listSuperClasses()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:superclasses() do
    table.insert(res, elem.name)
  end
  assertValueEqual({'GrandParent', 'Parent', 'ChildHelper'}, res)
end

function should.listSuperMethods()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:methods() do
    table.insert(res, elem.name)
  end
  assertValueEqual({'computeAge', 'name' , 'position', '_Child', '_get_', '_set_', '_cast_', 'Child', 'x', 'y'}, res)
end

function should.listSuperAttributes()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:attributes() do
    table.insert(res, elem.name)
  end
  assertValueEqual({'birth_year', 'married' , 'teeth'}, res)
end

function should.getDubInfoInHelper()
  local ChildHelper = ins:find 'ChildHelper'
  assertEqual(false, ChildHelper.dub.bind)
  assertEqual(false, ChildHelper.dub.cast)
end

test.all()



