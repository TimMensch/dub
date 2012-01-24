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

local function_ignore =
{
	-- functions that need to be blocked
	"qcDrawable::select",
	"qcDrawable::update",
	"qcDrawable::doDraw",
	"qcObject::serialize",
	"qcUnregisterSound",
	"qcPlaySound",
	"qcSoundRelease",
	"qcStreamIsPlaying",
	"qcStreamLoop",
	"qcStreamRate",
	"qcStreamStop",
	"qcStreamPause",
	"qcStreamVolume",
	"qcGetFolder",
	"qcDeleteFile",
	"qcMakeDir",
	"qcGetAssetSize",
	"qcReadAssetVector",
	"qcQueryNetworkState",
	"qcBindThread",
	"qcReleaseThread",
	"qcPlaySong",
	"qcCloseBufC",
	"qcClose",
	"qcDobCryptDecryptC",
	"qcDobCryptVerifyC",
	"qcRegisterSong",
	"qcReadAssetC",
	"qcFileExistsC"
}

local binder = dub.LuaBinder()


local ins = dub.Inspector()
ins:parse{
--	INPUT='../qc/include/qc',
	INPUT={'../qc/include/qc'},
	TEMPLATE_PATH = '../qc/bindings',
	ignore=function_ignore
}

local ttn = dub.LuaBinder.TYPE_TO_CHECK
local format = string.format

local ignore = {
-- classes that Lua doesn't need right now
	"qc2dParticleRenderer", "qc2dParticleRendererPair", "ParticleList", "qcDeferDraw",
	"qcParticleInitNullBase", "qcParticleUpdateBase", "qcParticleSystemImpl",
	"qcCommitTextures", "qcOggStream", "qcFlashPlayer",
	"qcDobCrypt", "qcFileInfo", "qcBuf," }

-- temporary ignores until the base class bug is fixed
--"qcAnimation", "qcDrawable", "qcObject", "qcSound", "qcStream" }

ttn['qcBuf'] ={
	type='qcBuf',
	pull =
		function(name, position, prefix)
			--return format([[qcBuf & %s = *((qcBuf *)dub_checksdata(L, %d, "qcBuf"));]],name,position);
			return format([[assert(false); /*qcBuf*/]],name,position);
		end,
--		qcBuf buf = *((qcBuf *)dub_checksdata(L, 1, "qcBuf"));
--		qcCloseBufC(*buf);

	push = function(name) return format([[
qcBuf __retbuf = %s;
if (__retbuf.buf)
	lua_pushlstring(L,__retbuf.buf,__retbuf.length); // push qcBuf as string
else
	lua_pushstring(L,""); // empty buf; push empty string
qcClose(__retbuf); // release out buf
]],name,name); end;
	cast = function(name) return name .. "/*qcBuf*/"; end;
};

ttn['qcFileRef'] ={
	type='qcFileRef',
	pull =
		function(name, position, prefix)
			return format([[qcFileRef & %s = *((qcBuf *)dub_checksdata(L, %d, "qcFileRef"));]],name,position);
		end,

	push = function(name) return format([[
dub_pushudata(L, new qcFileRef(%s), "qcFileRef", true); // push
]],name,name); end;
	cast = function(name) return name; end;
};

-- doesn't work!! grr...
ttn['lua_State']={
	type="lua_State",
	pull=
		function(name, position, prefix)
			if name == 'L' then
				return "/* L is already the lua_State */";
			else
				return format([[lua_State * %s = L;]],name);
			end
		end,
}

ttn['qc::string'] ={
  type   = 'qc::string',

  -- Get value from Lua.
  pull   = function(name, position, prefix)
  return format('size_t %s_sz_;\nconst char *%s = %schecklstring(L, %i, &%s_sz_);//qc::string pull\n',
                name, name, prefix, position, name)
  end,

  -- Push value in Lua
  push   =
	  function(name)
		  if name:match("%(") then
			return format('qc::string __s = %s;\nlua_pushlstring(L, __s.c_str(), __s.length());//qc::string push', name)
		  else
			return format('qc::string & __s = %s;\nlua_pushlstring(L, __s.c_str(), __s.length());//qc::string push', name)
		  end
	  end,

  -- Cast value
  cast   = function(name)
    return format('qc::string(%s, %s_sz_)', name, name)
  end,
};

ttn.lua_Number = 'number'
ttn.qcReal = 'number'

ttn.int64_t = 'number' -- number instead of "int" because a "number" holds more
ttn.uint64_t = 'number'

local destroyObjectRef=[[
if (userdata->gc)
{
	lua_getfenv(L,-1); 		// ud env
	lua_rawgeti(L,-1,2);	// ud env env[2]

	OBJECT_TYPERef * s = (OBJECT_TYPERef*)lua_touserdata(L,-1);
	delete s;

	lua_pop(L,1);			// ud env
	lua_pushnil(L);			// ud env nil
	// env[2] = nil
	lua_rawseti(L,-2,2);	// ud env
	lua_pop(L,1);			// ud
}
userdata->gc = false;
]]

local createObjectRef=[[
OBJECT_TYPERef ref( OBJECT_TYPE::create(CREATE_PARMS) );
ref->push<OBJECT_TYPE>(L);
return 1;]]

local push_template=[[
%s->push<%s>(L); // push_template
]]

local pull_template=[[
lua_pushvalue(L,%d); // ... ud
lua_rawget(L,LUA_REGISTRYINDEX); // ... smart_ud
%sRef &%s= *((%sRef*)lua_touserdata(L,-1)) ; // ... smart_ud
lua_pop(L,1); // ... ]]

--[[dub_pushudata(L, ref->get(), "OBJECT_TYPE", true);
lua_pushvalue(L,-1); // dup userdata
lua_pushlightuserdata(L,ref); // a light user data wrapper for the smart pointer
lua_rawset(L,LUA_REGISTRYINDEX);
]]

local extra_headers = {
	["qc::qcArc"]={ "qc/texture.h" },
	["qc::qcAnimation"]={ "qc/texture.h" },
	["qc::qcAtlas"]={ "qc/texturelink.h" },
	["qc::qcCurve"]={ "qc/texture.h" },
	["qc::qcStream"]={ "qc/sound.h" },
	["qc::qcDrawComponent"]={ "qc/drawable.h" },
	["qc::qcMediaStore"]={
		"qc/sound.h",
		"qc/song.h",
		"qc/texture.h",
		"qc/atlas.h",
		"qc/animation.h",
		},
};

--[[
#include "qc/drawable.h"
#include "qc/texture.h"
#include "qc/texturelink.h"

#include "qc/song.h"
#include "qc/sound.h"
#include "qc/animation.h"
#include "qc/atlas.h"
]]

local function sharedObjectDef(types)

	local b = {}

	for v,create_parms in pairs( types ) do

--        extra_headers[v]={ "qc/bind.h" };

		b[v] =
		{
			['~'..v] = { body = destroyObjectRef:gsub("OBJECT_TYPE",v)},
			serialize = { body = "(void)self; (void)tab; return 0;" },
			_set_suffix = [[
lua_getfenv(L,1); // obj key value fenv
if (lua_istable(L, -1)) {
  lua_insert(L,2); // obj fenv key value
  lua_rawset(L,2);
} else {
  luaL_error(L, KEY_EXCEPTION_MSG, key);
}
]],
			_get_suffix= [[
lua_getfenv(L,1); // obj key fenv
//if (lua_isnil(L,-1)) { lua_pop(L,1); luaL_error(L, KEY_EXCEPTION_MSG, key); }
lua_pushvalue(L,2); // obj key fenv key
lua_rawget(L,-2); // obj key fenv [result|nil]
if (lua_isnil(L,-1)) { lua_pop(L,2); luaL_error(L, KEY_EXCEPTION_MSG, key); }
lua_remove(L,-2); // obj key result
return 1;
]]
		}

		if create_parms then
			b[v].create   = { body = createObjectRef:gsub("OBJECT_TYPE",v):gsub("CREATE_PARMS",create_parms)}
		end

		ignore[#ignore+1] = "enable_shared_from_this<" ..v..">"

		ttn[v.."Ref"]=
		{
			type   = v.."Ref",

			-- Get value from Lua.
			pull   =
				function(name, position, prefix)
					return format(pull_template,position,v,name,v);
				end,

			-- Push value in Lua
			push   =
				function(name)
					return format(push_template, name, v)
				end,

			-- Cast value
			cast   =
				function(name)
					return format('%s', name)
				end,
		}

		ttn["shared_ptr< "..v.." >"]=
		{
			type   = "shared_ptr< "..v.." >",

			-- Get value from Lua.
			pull   =
				function(name, position, prefix)
					return format(pull_template,position,v,name,v);
				end,

			-- Push value in Lua
			push   =
				function(name)
					return format(push_template, name, v)
				end,

			-- Cast value
			cast   =
				function(name)
					return format('%s', name)
				end,
		}
	end

	return b;

end

local custom_bindings = sharedObjectDef{
	qcAnimation="",
	qcAnimationPlayer="animation",
	qcArc="texture,segments,radius,start,stop,*color",
	qcAtlas=false,
	qcCircleMask="*size, *center, radius, *color, triangles",
	qcCurve=false,
	qcDrawable=false,
	qcDrawComponent="d",
	qcGameObject="",
	qcGameObjectClone="target",
	qcLayer="",
	qcObject=false,
	qcObjectManager=false,
	qcParticleSystem=false,
	qcRectangle="w, h, *color",
	qcScript=false,
	qcSortedObjectManager=false,
	qcSong=false,
	qcSound=false,
	qcStream=false,
	qcTexture=false,
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

custom_bindings.qcMediaStore={}
custom_bindings.qcMediaStore.getFilesInFolder={ body=[[
qcFileListRef flr = self->getFilesInFolder(path,subdirs);
lua_newtable(L);
for (int i=0; i<(int)flr->size(); ++i)
{
	lua_pushstring( L, (*flr)[i].path.c_str() );
	lua_pushnumber( L, (*flr)[i].size );
	lua_settable( L, -3 );
}

return 1;
]] }
custom_bindings.getFilesInFolder={ body=[[
qcFileListRef flr = getFilesInFolder(path,subdirs);
lua_newtable(L);
for (int i=0; i<(int)flr->size(); ++i)
{
	lua_pushstring( L, (*flr)[i].path.c_str() );
	lua_pushnumber( L, (*flr)[i].size );
	lua_settable( L, -3 );
}

return 1;
]] }

custom_bindings.qcGameObject.m_scriptObject=
{
	get="self->m_scriptObject.push(L); return 1; /*m_scriptObject get*/",
	set="lua_pushvalue(L,3); self->m_scriptObject = qcScriptObject(L); return 0; /*m_scriptObject set*/",
}

custom_bindings.qcGameObject.addTexture=
{
	body='dub_pushudata(L, new qcDrawComponentRef(self->addTexture(texture)), "qcDrawComponentRef", true);'
}

custom_bindings.qcGameObject.bind=
{
	body='return self->bind(L);'
}
custom_bindings.qcGameObjectClone.bind=
{
	body='return self->bind(L);'
}

local output_directory = '../qc/bindings/src'
binder:bind(ins, {output_directory = output_directory,
	single_lib="qc",
	ignore=ignore,
	extra_headers = extra_headers,
	custom_bindings = custom_bindings,
--	only = { "qcRect32" }
})
--]==]

-- hack to fix qcRect32
local rect32 = lk.readall(output_directory,"qc_qcRect32.cpp")
rect32 = rect32:gsub("(%W)T(%W)","%1int32_t%2")
rect32 = rect32:gsub([[%*%*%(%(int32_t %*%)dub_checksdata_n%(L, 3, "int32_t"%)%);]],"(int32_t)lua_tonumber(L,3);")
lk.writeall(output_directory.."/qc_qcRect32.cpp",rect32,false)

local dub_h = lk.readall(output_directory,"dub/dub.h");
dub_h = dub_h:gsub('#include "dub/','#include "')
lk.writeall("../qc/include/dub/dub.h",dub_h,true)

local dir = lk.Dir(output_directory.."/dub")
-- Delete .h files
for file in dir:glob('%.h$') do
	lk.rmFile(file)
end

--[[
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
		"../qc/external/sdl/1.2.14/sdl/include",
		"../qc/external/tremor/1.0.2/Tremor",
		"../qc/external/freetype/2.3.12/freetype/include",
		"lib",
		"lib/dub/lua",
		"/c/Devel/LuaJIT-2.0.0-beta5/src/"
	},
	flags='../qc/tools/host/win/lua51.dll'
}

--require 'qc'
--local s = Simple(4.5)

--]]
