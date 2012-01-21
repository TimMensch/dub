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

function dumpvalue(e,maxdepth)

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

local ignore = {
-- classes that Lua doesn't need right now
"qc2dParticleRenderer", "qc2dParticleRendererPair", "ParticleList",
-- temporary ignores until the base class bug is fixed
"qcAnimation", "qcDrawable", "qcObject", "qcSound", "qcStream" }

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

local destroyObjectRef=[[
if (userdata->gc)
{
	// do I need two copies? I'm not sure if it's Kosher to let lua_rawset at the
	// end pop one of the original parameters from the stack.

	lua_pushvalue(L,-1); // ud ud
	lua_pushvalue(L,-1); // ud ud ud

	// look up userdata in registry to get smart pointer for this object
	lua_rawget(L,LUA_REGISTRYINDEX); // ud ud smart_ud

	OBJECT_TYPERef * s = (OBJECT_TYPERef*)lua_touserdata(L,-1);
	lua_pop(L,1); // ud ud
	lua_pushnil(L); // ud ud nil

	// clear reference in registry
	lua_rawset(L,LUA_REGISTRYINDEX);

	delete s;
}
userdata->gc = false;
]]

local createObjectRef=[[

OBJECT_TYPERef * ref = new OBJECT_TYPERef(OBJECT_TYPE::create(CREATE_PARMS));

dub_pushudata(L, ref->get(), "OBJECT_TYPE", true);
lua_pushvalue(L,-1); // dup userdata
lua_pushlightuserdata(L,ref); // a light user data wrapper for the smart pointer
lua_rawset(L,LUA_REGISTRYINDEX);
return 1;
]]

--[[
static int qcGameObject_create(lua_State *L) {
  try {
	dub_pushudata(L, new qcGameObjectRef(qcGameObject::create()), "qcGameObjectRef", true);
	return 1;
  } catch (std::exception &e) {
	lua_pushfstring(L, "qc.qcGameObject.create: %s", e.what());
  } catch (...) {
	lua_pushfstring(L, "qc.qcGameObject.create: Unknown exception");
  }
  return lua_error(L);
}
--]]

local function sharedObjectDef(types)

	local b = {}

	for v,create_parms in pairs( types ) do

		b[v] =
		{
			['~'..v] = { body = destroyObjectRef:gsub("OBJECT_TYPE",v)},
			serialize = { body = "(void)self; (void)tab; return 0;" }
		}

		if create_parms then
			b[v].create   = { body = createObjectRef:gsub("OBJECT_TYPE",v):gsub("CREATE_PARMS",create_parms)}
		end

		ignore[#ignore+1] = "enable_shared_from_this<" ..v..">"
	end

	return b;

end

local custom_bindings = sharedObjectDef{
	qcAnimation="animation",
	qcAnimationPlayer="animation",
	qcArc="texture,segments,radius,start,stop,*color",
	qcAtlas=false,
	qcGameObject="",
	qcGameObjectClone="target",
	qcCircleMask="*size, *center, radius, *color, triangles",
	qcCurve=false,
	qcDeferDraw="animation",
	qcDrawable="animation",
	qcDrawComponent="animation",
	qcLayer="animation",
	qcObject="animation",
	qcObjectManager="animation",
	qcParticleSystem="animation",
	qcRectangle="animation",
	qcScript="animation",
	qcSortedObjectManager="animation",
	qcSong="animation",
	qcSound="animation",
	qcStream="animation",
	qcTexture="animation",
	qcTextureLink=false
}

custom_bindings.qcCurve.setTexture={ body=[[
self->setTexture(texture);
]] }

custom_bindings.qcAtlas.getFrameNames={ body=[[
std::vector<const char*> frameNames = self->getFrameNames();
lua_newtable(L);
for (unsigned int i=0; i<frameNames.size(); ++i)
{
	lua_pushstring(L,frameNames[i]);
	lua_rawseti(L,-2,i+1);
}
return 1;
]] }

binder:bind(ins, {output_directory = 'bindings_path',
	single_lib="qc",
	ignore=ignore,
	custom_bindings = custom_bindings

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

dub.LuaBinder.COMPILER = 'c:/Devel/mingw/msys/1.0/bin/sh.exe -c "PATH=/bin:/mingw/bin env PATH=/c/Users/tim/bin:.:/usr/local/bin:/mingw/bin:/bin g++.exe '
dub.LuaBinder.QUOTE = '"'

local files = {}

local path = lk.Dir("bindings_path")
for k in path:glob('.*') do
	files[#files+1]=k
end

binder:build{
	output='qc.dll',
	inputs = files,
	includes={
		"test/fixtures/simple/include",
		"../qc/include",
		"../qc/external/bstrlib/2010_05_12/bstrlib",
		"../qc/external/ustl/1.4",
		"../qc/external/boost/1.46.1",
		"lib",
		"lib/dub/lua",
		"/c/Devel/LuaJIT-2.0.0-beta5/src/"
	},
	flags='../qc/tools/host/win/lua51.dll'
}

--require 'qc'
--local s = Simple(4.5)
