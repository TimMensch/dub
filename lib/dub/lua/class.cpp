/**
 *
 * MACHINE GENERATED FILE. DO NOT EDIT.
 *
 * Bindings for class {{class.name}}
 *
 * This file has been generated by dub {{dub.version}}.
 */
#include "dub.h"
{% for h in class:headers() do %}
#include "{{h.path}}"
{% end %}

{% for method in class:methods() do %}
/** {{method:fullname()}}
 * {{method.location}}
 */
static int {{class.name}}_{{method.name}}(lua_State *L) {
  try {
    {| self:functionBody(class, method) |}
  } catch (std::exception &e) {
    lua_pushfstring(L, "{{method.name}}: %s", e.what());
  } catch (...) {
    lua_pushfstring(L, "{{method.name}}: Unknown exception");
  }
  return lua_error(L);
}

{% end %}

/* ====================================== Methods registration */

static const struct luaL_Reg {{class.name}}_member_methods[] = {
{% for method in class:methods() do 
  if not method.static then %}
  {"{{method.name}}", {{string.format('%20s', class.name .. '_' .. method.name)}}},
{% end; end %}
  {NULL,            NULL},
};

static const struct luaL_Reg {{class.name}}_namespace_methods[] = {
{% for method in class:methods() do 
  if method.static then %}
  {"{{method.name}}", {{string.format('%20s', class.name .. '_' .. method.name)}}},
{% end; end %}
  {NULL,            NULL},
};

#ifdef DUB_LUA_LOAD
// These bindings are part of a larger library.
int luaload_{{class.name}}(lua_State *L)
#else
extern "C" int luaopen_{{class.name}}(lua_State *L)
#endif
{
  // Create the metatable which will contain all the member methods
  luaL_newmetatable(L, "{{self:libName(class)}}");

  // metatable.__index = metatable (find methods in the table itself)
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  // register member methods
  luaL_register(L, NULL, {{ class.name }}_member_methods);
  // save meta-table in {{self:libName(class)}}_
  {% if class.parent then %}
  register_mt(L, "{{self:libName(class.parent)}}", "{{class.name}}");
  // register class methods in {{parent.name}}
  luaL_register(L, "{{self:libName(class.parent)}}", {{class.name}}_namespace_methods);
  {% else %}
  register_mt(L, "_G", "{{class.name}}");
  // register class methods
  luaL_register(L, "_G", {{class.name}}_namespace_methods);
{% end %}
  return 1;
}
