/**
 *
 * MACHINE GENERATED FILE. DO NOT EDIT.
 *
 * Bindings for library {{lib_name}}
 *
 * This file has been generated by dub {{dub.version}}.
 */
#include "dub/dub.h"
{% for header in lib:constHeaders() do %}
#include "{{self:header(header)}}"
{% end %}

extern "C" {
{% for _, class in ipairs(classes) do %}
int luaopen_{{self:openName(class)}}(lua_State *L);
{% end %}
}

{% if lib.has_constants then %}
// --=============================================== CONSTANTS
static const struct dub_const_Reg {{lib_name}}_const[] = {
{% for const in lib:constants() do %}
  { {{string.format('%-15s, %-20s', '"'.. self:constName(const) ..'"', const)}} },
{% end %}
  { NULL, NULL},
};
{% end %}

extern "C" int luaopen_{{lib_name}}(lua_State *L) {
{% for _, class in ipairs(classes) do %}
  luaopen_{{self:openName(class)}}(L);
{% end %}

{% if lib.has_constants or lib.has_functions then %}
  // Create the table which will contain all the constants
  lua_getfield(L, LUA_GLOBALSINDEX, "{{lib_name}}");
  if (lua_isnil(L, -1)) {
    // no global table called {{lib_name}}
    lua_pop(L, 1);
    lua_newtable(L);
    // <lib>
    lua_pushvalue(L, -1);
    // <lib> <lib>
    // _G.{{lib_name}} = <lib>
    lua_setglobal(L, "{{lib_name}}");
    // <lib>
  }
  // <lib>
{% end %}
{% if lib.has_constants then %}
  // register global constants
  dub_register_const(L, {{lib_name}}_const);
{% end %}
  return 0;
}
