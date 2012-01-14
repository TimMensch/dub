--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {
  type = 'dub.MemoryStorage', 
}
local private = {}
local parse   = {}
lib.__index   = lib
dub.MemoryStorage = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
    local self = {
      -- xml definitions list
      xml_headers    = {},
      -- .h header files
      headers_list   = {},
      cache          = {},
      sorted_cache   = {},
      functions_list = {},
    }
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Prepare database

-- Parse xml directory and find header files. This will allow
-- us to find definitions as needed.
function lib:parse(xml_dir, not_lazy)
  local xml_headers = self.xml_headers
  local dir = lk.Dir(xml_dir)
  for file in dir:glob('%_8h.xml') do
    table.insert(xml_headers, {path = file, dir = xml_dir})
  end
  if not_lazy then
    private.parseAll(self)
  end
end

function lib:findByFullname(name)
  -- done
  -- split name components
  local parts = lk.split(name, '::')
  local current = self
  for i, part in ipairs(parts) do
    local child = current:findChild(self, part)
    if not child then
      return nil
    else
      current = private.resolveTypedef(self, child)
    end
  end
  return current
end

function lib:findChild(parent, name)
  -- Any element at the root of the name space
  return parent.cache[name] or private.parseHeaders(parent, name)
end

--- Return an iterator over the functions of this class/namespace.
function lib:functions(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iteratorWithSuper)
  return function()
    local ok, elem = coroutine.resume(co, parent, 'functions_list')
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the variables of this class/namespace.
function lib:variables(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iteratorWithSuper)
  return function()
    local ok, elem = coroutine.resume(co, parent, 'variables_list')
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the functions of this class/namespace.
function lib:headers(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, parent.headers_list)
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the variables of this class/namespace.
function lib:children()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, self.sorted_cache)
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the superclasses of this class.
function lib:superclasses(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  private.parseHeaders(parent)
  local co = co or coroutine.create(private.superIterator)
  return function()
    local ok, elem = coroutine.resume(co, self, parent)
    if ok then
      return elem
    end
  end
end

function lib:resolveType(name)
  -- Do we have a typedef ?
  local td = self:findByFullname(name)
  if td then
    return td.ctype
  end
end
--=============================================== PRIVATE

function private.iterator(list)
  for _, child in ipairs(list) do
    coroutine.yield(child)
  end
end

function private.iteratorWithSuper(elem, key)
  if elem.type == 'dub.Class' then
    for super in elem:superclasses() do
      for _, child in ipairs(super[key]) do
        if not child.no_inherit and
           not child.dtor and
           not child.static then
           coroutine.yield(child)
         end
      end
    end
  end
  private.iterator(elem[key])
end

-- Iterate superclass hierarchy.
function private:superIterator(base)
  for _, name in ipairs(base.super_list) do
    local super = self:findByFullname(name)
    if super then
      private.superIterator(self, super)
      coroutine.yield(super)
    end
  end
  -- Find pseudo parents
  if base.dub.super then
    local list = lk.split(base.dub.super, ',')
    private.superIterator(self, {super_list = list, dub = {}})
  end
end

function private:parseAll()
  if self.parsed_headers then
    return
  end
  for i, header in ipairs(self.xml_headers) do
    if not header.parsed then
      parse.header(self, header, true)
    end
  end
  self.parsed_headers = true
end

-- Here 'self' can be the db (root) or a class.
function private:parseHeaders(name)
  local cache = self.cache
  if self.parsed_headers then
    return cache[name] 
  end
  local elem
  -- Look in all unparsed headers
  for i, header in ipairs(self.xml_headers) do
    if not header.parsed then
      parse.header(self, header)
      if name and cache[name] then
        return cache[name]
      end
    end
  end
  self.parsed_headers = true
end

require 'lubyk'

--- Parse a header definition and return element 
-- identified by 'name' if found.
function parse:header(header, not_lazy)
  local data = xml.load(header.path):find('compounddef')
  local h_path = data:find('location').file
  local base, h_file = lk.directory(h_path)
  header.h_file = h_file
  table.insert(self.headers_list, h_file)

  self.dub = parse.dub(data) or self.dub
  parse.children(self, data, header, not_lazy)
  header.parsed = true
end

function parse:children(elem_list, header, not_lazy)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  for _, elem in ipairs(elem_list) do
    local func = parse[elem.xml]
    if func then
      local child = func(self, elem, header, not_lazy)
      if child then
        cache[child.name] = child
        table.insert(sorted_cache, child)
      end
    else
      --print('skipping', elem.xml)
    end
  end
  -- Create --get--, --set-- and ~Destructor if needed.
  if self.is_class then
    private.makeSpecialMethods(self)
  end
end

function parse:basecompoundref(elem, header)
  if elem.prot == 'public' then
    table.insert(self.super_list, elem[1])
  end
end

function parse:innernamespace(elem, header)
  return {
    type = 'dub.Namespace',
    name = elem[1]
  }
end

function parse:innerclass(elem, header, not_lazy)
  local class = dub.Class {
    -- self can be a class or db (root)
    db      = self.db or self,
    name    = elem[1],
    xml     = elem,
    xml_headers  = {
      {path = header.dir .. lk.Dir.sep .. elem.refid .. '.xml', dir = header.dir}
    },
  }
  if not_lazy then
    private.parseAll(class)
  end
  return class
end

function parse:templateparamlist(elem, header)
  -- change self from dub.Class to dub.CTemplate
  setmetatable(self, dub.CTemplate)
  self.template_params = {}
  for _, param in ipairs(elem) do
    local name = param:find('type')[1]
    name = string.gsub(name, 'class ', '')
    name = string.gsub(name, 'typename ', '')
    table.insert(self.template_params, name)
  end
end

function parse:sectiondef(elem, header)
  local kind = elem.kind
  if kind == 'public-func' or 
     kind == 'typedef' or
     kind == 'public-attrib' or
     kind == 'public-static-attrib' or
     kind == 'public-static-func' then
    parse.children(self, elem, header)
  end
end

function parse:memberdef(elem, header)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  local kind = elem.kind
  local func = parse[kind]
  if func then
    local child = func(self, elem, header)
    if child then
      cache[child.name] = child
      table.insert(sorted_cache, child)
    end
  else
    --print('skipping memberdef ', kind)
  end
end

function parse:variable(elem, header)
  local name = elem:find('name')[1]
  local child  = {
    name   = name,
    type   = 'dub.Attribute',
    ctype  = parse.type(elem),
    static = elem.static == 'yes',
  }
  self.has_variables = true
  table.insert(self.variables_list, child)
  return child
end

function parse:typedef(elem, header)
  return {
    type        = 'dub.Typedef',
    name        = elem:find('name')[1],
    ctype       = parse.type(elem),
    desc        = (elem:find('detaileddescription') or {})[1],
    xml         = elem,
    definition  = elem:find('definition')[1],
    header_file = header.h_file,
  }
end
    
parse['function'] = function(self, elem, header)
  local name  = elem:find('name')[1]
  if self.cache[name] or
     name == '~' .. self.name and self.dub.destroy == 'free' then
    -- TODO: support overloaded functions.
    return nil
  end

  local child = dub.Function {
    -- self can be a class or db (root)
    db            = self.db or self,
    parent        = self,
    name          = name,
    params_list   = parse.params(elem, header),
    return_value  = parse.retval(elem),
    definition    = elem:find('definition')[1],
    argsstring    = elem:find('argsstring')[1],
    location      = private.makeLocation(elem, header),
    desc          = (elem:find('detaileddescription') or {})[1],
    static        = elem.static == 'yes' or (self.name == name),
    xml           = elem,
    member        = self.is_class,
    dtor          = self.is_class and name == '~' .. self.name,
    ctor          = self.is_class and name == self.name,
    dub           = parse.dub(elem) or {},
  }
  if self.name == name then
    -- Constructor
    child.return_value = lib.makeType(name .. ' *')
  end

  local list = self.functions_list
  if list then
    table.insert(list, child)
  end
  return child
end

function parse.params(elem, header)
  local res = {str = elem:find('argsstring')[1]}
  local i = 0
  local has_defaults = false
  for _, param in ipairs(elem) do
    if param.xml == 'param' then
      i = i + 1
      local p = parse.param(param, i)
      table.insert(res, p)
      has_defaults = has_defaults or p.default
    end
  end
  res.has_defaults = has_defaults
  return res
end

function parse.param(elem, position)
  return {
    type     = 'dub.Param',
    name     = elem:find('declname')[1],
    position = position,
    ctype    = parse.type(elem),
    default  = (elem:find('defval') or {})[1],
  }
end

function parse.retval(elem)
  local ctype = parse.type(elem)
  if ctype and ctype.name ~= 'void' then
    return ctype
  end
end

-- Return a string like 'float' or 'MyFloat'.
function parse.type(elem)
  local ctype = elem:find('type')
  if type(ctype) == 'table' then
    ctype = private.flatten(ctype)
  end
  if ctype then
    return lib.makeType(ctype)
  end
end

-- This can be used by binders to create types on the fly.
function lib.makeType(str)
  local typename = str
  typename = string.gsub(typename, ' &', '')
  local create_name = typename
  typename = string.gsub(typename, ' %*', '')
  if typename == create_name then
    create_name = create_name .. ' '
  end
  typename = string.gsub(typename, 'const ', '')
  return {
    def   = str,
    name  = typename,
    create_name = create_name,
    ptr   = string.match(str, '%*'),
    const = string.match(str, 'const'),
    ref   = string.match(str, '&'),
  }
end

function private.makeLocation(elem, header)
  local loc  = elem:find('location')
  local file = lk.absToRel(loc.file, lfs.currentdir())
  return file .. ':' .. loc.line
end

-- self == class
function private:makeDestructor()
  if self.cache['~' .. self.name] or self.dub.destroy == 'free' then
    -- Destructor not needed.
    return
  end
  local name = self.name
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = '_' .. name,
    params_list   = {},
    return_value  = nil,
    definition    = '~' .. name,
    argsstring    = '()',
    location      = '',
    desc          = name .. ' destructor.',
    static        = false,
    xml           = nil,
    dtor          = true,
    member        = true,
  }
  table.insert(self.functions_list, child)
  self.cache['~' .. name] = child
  self.cache['_' .. name] = child
end

function private:makeSpecialMethods()
  -- Force destructor creation when needed.
  private.makeDestructor(self)
  private.makeGetAttribute(self)
  private.makeSetAttribute(self)
  if #self.super_list > 0 or self.dub.super then
    private.makeCast(self)
  end
end

-- self == class
function private:makeGetAttribute()
  if not self.has_variables or
     self.cache[self.GET_ATTR_NAME] then
    return
  end
  local name = self.GET_ATTR_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Get attributes ',
    argsstring    = '(key)',
    location      = '',
    desc          = 'Read attributes values for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_get_attr   = true,
    member        = true,
  }
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
  self.cache[child.name] = child
end

function private:makeSetAttribute()
  if not self.has_variables or
     self.cache[self.SET_ATTR_NAME] then
    return
  end
  local name = self.SET_ATTR_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Set attributes ',
    argsstring    = '(key, value)',
    location      = '',
    desc          = 'Set attributes values for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_set_attr   = true,
    member        = true,
  }
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
  self.cache[child.name] = child
end

function private:makeCast()
  if not self.has_variables or
     self.cache[self.CAST_NAME] then
    return
  end
  local name = self.CAST_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Cast ',
    argsstring    = '(class_name)',
    location      = '',
    desc          = 'Cast to superclass for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_cast       = true,
    member        = true,
  }
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
  self.cache[child.name] = child
end

function private.flatten(xml)
  if type(xml) == 'string' then
    return xml
  else
    local res = ''
    for i, e in ipairs(xml) do
      if i > 1 then
        res = res .. ' '
      end
      res = res .. private.flatten(e)
    end
    return res
  end
end

function parse.detaileddescription(self, elem, header)
  local dub = parse.dub(elem)
  if dub then
    self.dub = dub
  end
end

function parse.dub(elem)
  -- This would not work if simplesect is not the first one
  local sect = elem:find('simplesect', 'kind', 'par')
  if sect then
    if (sect:find('title') or {})[1] == 'Bindings info:' then
      local txt = sect:find('para')[1]
      -- HACK TO RECREATE NEWLINES...
      txt = string.gsub(txt, ' ([a-z]+):', '\n%1:')
      return yaml.load(txt)
    end
  end
  return nil
end

function private:resolveTypedef(elem)
  if elem.type == 'dub.Typedef' then
    -- try to resolve and make a full class
    local name, types = string.match(elem.ctype.name, '^(.*) < (.+) >$')
    if name then
      types = lk.split(types, ', ')
      local template = self:findByFullname(name)
      if template and template.type == 'dub.CTemplate' then
        local class = template:resolveTemplateParams(elem.name, types)
        self.cache[class.name] = class
        table.insert(self.sorted_cache, class)
        class.typedef = elem.definition .. ';'
        table.insert(class.headers_list, elem.header_file)
        return class
      end
    end
  end
  return elem
end
