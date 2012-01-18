require "autoload"
require 'dub'
require 'lfs'
require 'xml'

lk = {}
require 'lk/Dir'
require 'lk/util'


function __dump(e,indent,map,maxdepth)

	if maxdepth==0 then
		return
	end

	maxdepth = maxdepth -1

  if type(e) ~= 'table' then
    print('['..tostring(e)..']')
    return
  end

	if map[e] then
    print( string.rep(" ",indent) .."Reference to "..tostring(e))
		return
	end

	map[e]=true

	if indent > 70 then
    io.write( string.rep(" ",indent) .. ">>too deep" )
		return
	end

	print( string.rep(" ",indent) .. '['..tostring(e)..']')

  if e[0] then
    print("e[0]->")
    __dump(e[0],indent+2,map,maxdepth)
  end

  for k,v in pairs(e) do
		if k~='parent' then

			io.write( string.rep(" ",indent) )
			io.write(k .. "->");
			if type(v)=='table' then
				io.write("\n");
				__dump(v,indent+2,map,maxdepth)
			else
				io.write(tostring(v).."\n")
			end

		end
  end
end

function dump(e,maxdepth)

	indent = indent or 0
	maxdepth = maxdepth or -1

	local map = {}
	__dump(e,0,map,maxdepth)
end

local exepath = arg[-1]

local ins = dub.Inspector()
ins:parse{
--	INPUT='../qc/include/qc',
	INPUT='../qc/include/qc',
	TEMPLATE_PATH = '../qc/bindings'
}

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
ttn.int8_t = 'number'
ttn.uint8_t = 'number'
ttn.int16_t = 'number'
ttn.uint16_t = 'number'
ttn.int32_t = 'number'
ttn.uint32_t = 'number'


binder:bind(ins, {output_directory = 'bindings_path',
  --[[only = {
		'qcVec2',
		'qc::Rect',
		'qcObject',
		'qcObjectManager',
		'qcSortedObjectManager',
		'qcGameObject',
		'qcTransform',
		}]]--
})

--dub.LuaBinder.COMPILER = 'c:/Devel/mingw/msys/1.0/bin/sh.exe -c "PATH=/bin:/mingw/bin env PATH=/c/Users/tim/bin:.:/usr/local/bin:/mingw/bin:/bin g++.exe '
--dub.LuaBinder.QUOTE = '"'
--binder:build('lib/Simple.so', 'bindings_path', '%.cpp', '-Itest/fixtures/simple/include -I/c/Devel/LuaJIT-2.0.0-beta5/src/ ../qc/tools/host/win/lua51.dll')
--require 'Simple'
 --local s = Simple(4.5)
