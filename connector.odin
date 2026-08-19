package zitrus

// import "core:strconv"
// import "core:path"
// import fmt "core:fmt"
// import "base:runtime"
// import "core:c"
// import str "core:strings"

// import lua "vendor:lua/5.4"

// LUA_ROOT :: "/lua/"

// Lua_Data :: struct {
//     state: ^lua.State,
// } 

// lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> (buf: rawptr) {
// 	old_size := int(osize)
// 	new_size := int(nsize)
// 	context = (^runtime.Context)(ud)^

// 	if ptr == nil {
// 		data, err := runtime.mem_alloc(new_size)
// 		return raw_data(data) if err == .None else nil
// 	} else {
// 		if nsize > 0 {
// 			data, err := runtime.mem_resize(ptr, old_size, new_size)
// 			return raw_data(data) if err == .None else nil
// 		} else {
// 			runtime.mem_free(ptr)
// 			return
// 		}
// 	}
// }

// init_lua :: proc() -> bool {
//     _context := context
// 	defer free_all(context.temp_allocator)

//     heart.lua.state = lua.newstate(lua_allocator, &_context)
// 	L: ^lua.State = heart.lua.state
// 	lua.L_openlibs(L)

// 	// Load lua
// 	{
// 		path_log := str.concatenate({heart.meta.exe_path, LUA_ROOT, "Log.lua"}, context.temp_allocator)
// 		path_log_c := str.clone_to_cstring(path_log, context.temp_allocator)

// 		if lua.L_dofile(L, path_log_c) != i32(lua.OK) {
// 			fmt.printfln("[ERROR] Cannot load 'Log.lua' file.")
// 			return false
// 		}

// 		path_script_manager := str.concatenate({heart.meta.exe_path, LUA_ROOT, "ScriptManager.lua"}, context.temp_allocator)
// 		path_script_manager_c := str.clone_to_cstring(path_script_manager, context.temp_allocator)

// 		if lua.L_dofile(L, path_script_manager_c) != i32(lua.OK) {
// 			fmt.printfln("[ERROR] Cannot load 'ScriptManager.lua' file.")
// 			return false
// 		}
// 	}
	

// 	// Load basic functions.
	

// 	return true
// }

// destroy_lua :: proc() {
// 	lua.close(heart.lua.state)
// }

// // Functions for lua.
// @(private="file")
// c_log :: proc "c" (L: ^lua.State) -> c.int {
// 	context = runtime.default_context()

// 	argc := lua.gettop(L)
// 	if argc != 1 {
// 		return auto_cast(lua.L_error(L, "passed too many arguments to lua's logging function."));
// 	}

// 	message := lua.L_checkstring(L,  1)
// 	fmt.println(message)

// 	return auto_cast(lua.OK)
// }