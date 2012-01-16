--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test basic binding with the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - simple')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/simple/include',
  doc_dir = lk.dir() .. '/tmp',
}

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.LuaBinder)
end

--[[
function should.bindClass()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  assertMatch('luaopen_Simple', res)
end

function should.bindConstructor()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  assertMatch('"new"[ ,]+Simple_Simple', res)
end

function should.bindDestructor()
  local Simple = ins:find('Simple')
  local dtor   = Simple:method('~Simple')
  local res = binder:bindClass(Simple)
  assertMatch('Simple__Simple', res)
  local res = binder:functionBody(Simple, dtor)
  assertMatch('if %(%*self%) delete %*self', res)
end

function should.bindStatic()
  local Simple = ins:find('Simple')
  local met = Simple:method('pi')
  local res = binder:bindClass(Simple)
  assertMatch('Simple_pi', res)
  local res = binder:functionBody(Simple, met)
  assertNotMatch('self', res)
  assertEqual('Simple_pi', binder:bindName(met))
end
--]]

local function makeSignature(met)
  local res = {}
  for param in met:params() do
    table.insert(res, param.lua.type)
  end
  return res
end

function should.resolveTypes()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  binder:resolveTypes(met)
  assertValueEqual({
    'number',
    'number',
  }, makeSignature(met))
  assertEqual('number, number', met.lua_signature)

  met = Simple:method('mul')
  binder:resolveTypes(met)
  assertValueEqual({
    'userdata',
  }, makeSignature(met))
  assertEqual('Simple', met.lua_signature)
end

function should.resolveReturnValue()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  binder:resolveTypes(met)
  assertEqual('number', met.return_value.lua.type)
end

function should.useArgCountWhenDefaults()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local res = binder:functionBody(Simple, met)
  assertMatch('lua_gettop%(L%)', res)
end

local function treeTest(tree)
  local res = {}
  if tree.type == 'dub.Function' then
    return tree.argsstring
  else
    for k, v in pairs(tree) do
      res[k] = treeTest(v)
    end
  end
  return res
end

function should.makeOverloadedDecisionTree()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    Simple = '(const Simple &o)',
    number = '(MyFloat v, double w=10)',
  }, treeTest(tree))
  -- need_top because we have defaults
  assertTrue(need_top)
end

function should.makeOverloadedNestedResolveTree()
  local Simple = ins:find('Simple')
  local met = Simple:method('mul')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    _ = '()',
    Simple = '(const Simple &o)',
    number = {
      _ = '(double d)',
      number = '(double d, double d2)',
    },
  }, treeTest(tree))
  assertTrue(need_top)
end

--=============================================== Overloaded

function should.haveOverloadedList()
  local Simple = ins:find('Simple')
  local met = Simple:method('mul')
  binder:resolveTypes(met)
  local res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.lua_signature)
  end
  assertValueEqual({
    'Simple',
    'number',
    'number, number',
    '',
  }, res)
end

function should.haveOverloadedListWithDefaults()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.lua_signature)
  end
  assertValueEqual({
    'number, number',
    'Simple',
  }, res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  local ins = dub.Inspector 'test/fixtures/simple/include'

  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)
  binder:bind(ins, {output_directory = tmp_path, only = {'Simple'}})
  local cpath_bak = package.cpath
  local s
  assertPass(function()
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Simple.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Simple.cpp',
      },
      includes = {
        'tmp',
        'fixtures/simple/include',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    require 'Simple'
    assertType('table', Simple)
  end, function()
    -- teardown
    package.loaded.Simple = nil
    package.cpath = cpath_bak
    if not Simple then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Simple tests

function should.buildObjectByCall()
  local s = Simple(1.4)
  assertType('userdata', s)
  assertEqual(1.4, s:value())
  assertEqual(Simple, getmetatable(s))
end

function should.buildObjectWithNew()
  local s = Simple.new(1.4)
  assertType('userdata', s)
  assertEqual(Simple, getmetatable(s))
end

function should.haveType()
  local s = Simple(1.4)
  assertEqual("Simple", s.type)
end

function should.bindNumber()
  local s = Simple(1.4)
  assertEqual(1.4, s:value())
end

function should.bindBoolean()
  assertFalse(Simple(1):isZero())
  assertTrue(Simple(0):isZero())
end

function should.bindMethodWithoutReturn()
  local s = Simple(3.4)
  s:setValue(5)
  assertEqual(5, s:value())
end

function should.raiseErrorOnMissingParam()
  assertError('Simple: number expected, got no value', function()
    Simple()
  end)
end

function should.handleDefaultValues()
  local s = Simple(2.4)
  assertEqual(14, s:add(4))
end

function should.callOverloaded()
  local s = Simple(2.4)
  local s2 = s:add(Simple(10))
  assertEqual(12.4, s2:value())
  assertEqual(0, s:mul())
  assertEqual(4.8, s:mul(2))
  assertEqual(28, s:mul(14, 2))
  assertEqual(13, s:addAll(3, 4, 6))
  assertEqual(16, s:addAll(3, 4, 6, "foo"))
end

function should.properlyHandleErrorMessagesInOverloaded()
  local s = Simple(2.4)
  assertError('addAll: string expected, got nil', function()
    s:addAll(3, 4, 6, nil)
  end)
  assertError('addAll: string expected, got boolean', function()
    s:addAll(3, 4, 6, true)
  end)
end

test.all()
