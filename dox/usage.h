/**
 * @page dub_usage Dub Usage
 *
 * @subsection dub_class_overrides Class Overrides
 *
 * @subsubsection dub_destroy_free POD Class Optimization/Destructor Disabling
 *
 * @paragraph dub_destroy_free_1 Dub Command
 * \@dub destroy: 'free'
 *
 * @paragraph dub_destroy_free_1 Inspector Command
 * @code
 * local a = inspector.find("classname");
 * a.dub = { init:"luaInit" }
 * @endcode
 *
 * @subsubsection dub_class_init Post-Creation Init
 *
 * @paragraph dub_class_init_1 Dub Command
 * @code
 * \@dub init: 'luaInit'
 * @endcode
 *
 * @paragraph dub_class_init_2 Inspector Command
 * @code
 * local a = inspector.find("classname");
 * a.dub = { init:"luaInit" }
 * @endcode
 *
 * @paragraph dub_class_init_3 Inspector Command
 * Causes Dub to call luaInit function after creating an instance of classname.
 * The luaInit function has the form:
 *
 * @code
 * int luaInit( lua_State * L );
 * @endcode
 *
 * This function can be used to do extra post-construction initialization for a
 * class.
 */
