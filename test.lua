require "autoload"
require 'dub'
require 'lfs'
require 'xml'

lk = {}
require 'lk/Dir'
require 'lk/util'

local exepath = arg[-1]

local ins = dub.Inspector()
ins:parse('test/fixtures/simple/include')

local binder = dub.LuaBinder()
local ttn = dub.LuaBinder.TYPE_TO_NATIVE
local format = string.format

ttn['qc::string'] ={
  type   = 'qc::string',

  -- Get value from Lua.
  pull   = function(name, position, prefix)
  return format('size_t %s_sz_;\nconst char *%s = %schecklstring(L, %i, &%s_sz_);',
                name, name, prefix, position, name)
  end,

  -- Push value in Lua
  push   = function(name)
    return format('lua_pushlstring(L, %s.data(), %s.length());', name, name)
  end,

  -- Cast value
  cast   = function(name)
    return format('qc::string(%s, %s_sz_)', name, name)
  end,
};

ttn.qcReal = 'number'

binder:bind(ins, {output_directory = 'bindings_path',
  only = {'Simple'}
})

--dub.LuaBinder.COMPILER = 'c:/Devel/mingw/msys/1.0/bin/sh.exe -c "PATH=/bin:/mingw/bin env PATH=/c/Users/tim/bin:.:/usr/local/bin:/mingw/bin:/bin g++.exe '
--dub.LuaBinder.QUOTE = '"'
--binder:build('lib/Simple.so', 'bindings_path', '%.cpp', '-Itest/fixtures/simple/include -I/c/Devel/LuaJIT-2.0.0-beta5/src/ ../qc/tools/host/win/lua51.dll')
--require 'Simple'
 --local s = Simple(4.5)
