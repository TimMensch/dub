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
	"qcDobCrypt", "qcFileInfo", "qcBuf",

-- temporary ignores until the base class bug is fixed
"qcAnimation", "qcDrawable", "qcObject", "qcSound", "qcStream" }

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
  return format('size_t %s_sz_;\nconst char *%s = %schecklstring(L, %i, &%s_sz_);//qc::string pull',
                name, name, prefix, position, name)
  end,

  -- Push value in Lua
  push   =
	  function(name)
		return format('lua_pushlstring(L, %s.c_str(), %s.length());//qc::string push', name, name)
	  end,

  -- Cast value
  cast   = function(name)
    return format('qc::string(%s, %s_sz_)/*cast*/', name, name)
  end,
};

ttn.qcReal = 'number'
ttn.lua_Number = 'number'

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

		ttn[v.."Ref"]=
		{
			type   = v.."Ref",

			-- Get value from Lua.
			pull   =
				function(name, position, prefix)
					return format([[
lua_pushvalue(L,%d); // ... ud
lua_rawget(L,LUA_REGISTRYINDEX); // ... smart_ud
%sRef &%s= *((%sRef*)lua_touserdata(L,-1)) ; // ... smart_ud
lua_pop(L,1); // ... ]],position,v,name,v);
				end,

			-- Push value in Lua
			push   =
				function(name)
					return format([[
%s->push(L); //
]], name, name)
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
	qcAnimation="animation",
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
for (int i=0; i<flr->size(); ++i)
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
for (int i=0; i<flr->size(); ++i)
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
	custom_bindings = custom_bindings,
--	only = { "qcRect32" }
})
--]==]

-- hack to fix qcRect32
local rect32 = lk.readall(output_directory,"qc_qcRect32.cpp")
rect32 = rect32:gsub("(%W)T(%W)","%1int32_t%2")
rect32 = rect32:gsub([[%*%*%(%(int32_t %*%)dub_checksdata_n%(L, 3, "int32_t"%)%);]],"(int32_t)lua_tonumber(L,3);")
lk.writeall(output_directory.."/qc_qcRect32.cpp",rect32,false)

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
