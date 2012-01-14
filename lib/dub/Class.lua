--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {
  type          = 'dub.Class',
  is_class      = true,
  SET_ATTR_NAME = '_set_',
  GET_ATTR_NAME = '_get_',
  CAST_NAME     = '_cast_',
}
local private = {}
lib.__index   = lib
dub.Class     = lib

--=============================================== dub.Class()
setmetatable(lib, {
  __call = function(lib, self)
    self.cache          = {}
    self.sorted_cache   = {}
    self.functions_list = {}
    self.variables_list = {}
    self.headers_list   = self.headers_list or {}
    self.super_list     = {}
    self.dub            = self.dub or {}
    self.xml_headers    = self.xml_headers or {}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS

--- Return a method from a given name.
function lib:method(name)
  return self.db:findChild(self, name)
end

--- Return an iterator over the methods of this class.
function lib:methods()
  return self.db:functions(self)
end

--- Return an iterator over the attributes of this class.
function lib:attributes()
  return self.db:variables(self)
end

--- Return an iterator over the headers for this class/namespace.
function lib:headers()
  return self.db:headers(self)
end

--- Return an iterator over the superclasses of this class.
function lib:superclasses()
  return self.db:superclasses(self)
end

function lib:fullname()
  if self.parent then
    return self.parent:fullname() .. '::' .. self.name
  else
    return self.name
  end
end

--=============================================== PRIVATE

