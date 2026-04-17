package zitrus

import "libs:zitrus"
import "core:fmt"
import "core:mem"

import sdl "vendor:sdl3"


Action_ID :: int
Callback_Group :: int

Callback_ID :: string

Input_Key :: enum {
    // Letters
    A, B, C, D, E, F, G, H, I, J, K, L, M, 
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    // Numbers
    Num0, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,

    // Function Keys
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,

    // Symbols & Punctuation
    Space, Escape, Enter, Tab, Backspace, Insert, Delete,
    Right, Left, Down, Up,
    Page_Up, Page_Down, Home, End,
    Caps_Lock, Scroll_Lock, Num_Lock, Print_Screen, Pause,

    // Special Characters
    Grave, Minus, Equals, Left_Bracket, Right_Bracket, Backslash,
    Semicolon, Apostrophe, Comma, Period, Slash,

    // Modifiers
    L_Shift, R_Shift, L_Control, R_Control, L_Alt, R_Alt, L_GUI, R_GUI,
}

@(private="file")
INPUT_TO_SDL := [Input_Key]sdl.Keycode {
    // Letters
    .A = sdl.K_A, .B = sdl.K_B, .C = sdl.K_C, .D = sdl.K_D, .E = sdl.K_E,
    .F = sdl.K_F, .G = sdl.K_G, .H = sdl.K_H, .I = sdl.K_I, .J = sdl.K_J,
    .K = sdl.K_K, .L = sdl.K_L, .M = sdl.K_M, .N = sdl.K_N, .O = sdl.K_O,
    .P = sdl.K_P, .Q = sdl.K_Q, .R = sdl.K_R, .S = sdl.K_S, .T = sdl.K_T,
    .U = sdl.K_U, .V = sdl.K_V, .W = sdl.K_W, .X = sdl.K_X, .Y = sdl.K_Y, .Z = sdl.K_Z,

    // Numbers
    .Num0 = sdl.K_0, .Num1 = sdl.K_1, .Num2 = sdl.K_2, .Num3 = sdl.K_3, .Num4 = sdl.K_4,
    .Num5 = sdl.K_5, .Num6 = sdl.K_6, .Num7 = sdl.K_7, .Num8 = sdl.K_8, .Num9 = sdl.K_9,

    // Function Keys
    .F1 = sdl.K_F1, .F2 = sdl.K_F2, .F3 = sdl.K_F3, .F4 = sdl.K_F4, 
    .F5 = sdl.K_F5, .F6 = sdl.K_F6, .F7 = sdl.K_F7, .F8 = sdl.K_F8,
    .F9 = sdl.K_F9, .F10 = sdl.K_F10, .F11 = sdl.K_F11, .F12 = sdl.K_F12,

    // Navigation & Controls
    .Space     = sdl.K_SPACE,
    .Escape    = sdl.K_ESCAPE,
    .Enter     = sdl.K_RETURN,
    .Tab       = sdl.K_TAB,
    .Backspace = sdl.K_BACKSPACE,
    .Insert    = sdl.K_INSERT,
    .Delete    = sdl.K_DELETE,
    .Right     = sdl.K_RIGHT,
    .Left      = sdl.K_LEFT,
    .Down      = sdl.K_DOWN,
    .Up        = sdl.K_UP,
    .Page_Up   = sdl.K_PAGEUP,
    .Page_Down = sdl.K_PAGEDOWN,
    .Home      = sdl.K_HOME,
    .End       = sdl.K_END,

    // Locks and System
    .Caps_Lock    = sdl.K_CAPSLOCK,
    .Scroll_Lock  = sdl.K_SCROLLLOCK,
    .Num_Lock     = sdl.K_NUMLOCKCLEAR,
    .Print_Screen = sdl.K_PRINTSCREEN,
    .Pause        = sdl.K_PAUSE,

    // Symbols
    .Grave         = sdl.K_GRAVE,
    .Minus         = sdl.K_MINUS,
    .Equals        = sdl.K_EQUALS,
    .Left_Bracket  = sdl.K_LEFTBRACKET,
    .Right_Bracket = sdl.K_RIGHTBRACKET,
    .Backslash     = sdl.K_BACKSLASH,
    .Semicolon     = sdl.K_SEMICOLON,
    .Apostrophe    = sdl.K_APOSTROPHE,
    .Comma         = sdl.K_COMMA,
    .Period        = sdl.K_PERIOD,
    .Slash         = sdl.K_SLASH,

    // Modifiers
    .L_Shift   = sdl.K_LSHIFT,
    .R_Shift   = sdl.K_RSHIFT,
    .L_Control = sdl.K_LCTRL,
    .R_Control = sdl.K_RCTRL,
    .L_Alt     = sdl.K_LALT,
    .R_Alt     = sdl.K_RALT,
    .L_GUI     = sdl.K_LGUI,
    .R_GUI     = sdl.K_RGUI,
}

Input_Callback :: struct {
    group: Callback_Group,
    id: string,
    data: rawptr,
    callback: proc(rawptr),

    enabled: bool,
}

Input_Action :: struct {
    key: Input_Key,
    is_held: bool,
    on_press: [dynamic]Input_Callback,
    on_release: [dynamic]Input_Callback,
}

Callback_Group_Pair :: struct{
    action_id: Action_ID, 
    callback_id: Callback_ID
}


Input_Data :: struct {
    // User must create an enum with list of actions
    // Each action (enum value) will be an index to this array
    action_map: [dynamic]Input_Action,
    sdl_to_action_map: map[sdl.Keycode][dynamic]Action_ID,

    callback_groups: [dynamic][dynamic]Callback_Group_Pair,
}

configurate_input :: proc(actions: map[Action_ID]Input_Key, callback_groups_number: int) {
    h := get_heart()

    input := &h.input_data

    resize(&input.action_map, len(actions))
    for id, key in actions {
        sdl_key := INPUT_TO_SDL[key]

        input.action_map[id] = {
            key = key
        }
        
        if !(sdl_key in input.sdl_to_action_map) {
            input.sdl_to_action_map[sdl_key] = make([dynamic]Action_ID)
        }
        
        list := &input.sdl_to_action_map[sdl_key]
        append(list, id)
    }

    resize(&input.callback_groups, callback_groups_number)
    for i in 0..<callback_groups_number {
        input.callback_groups[i] = make([dynamic]Callback_Group_Pair)
    }
}

get_action :: #force_inline proc(action_id: Action_ID) -> ^Input_Action {
    h := get_heart()
    return &h.input_data.action_map[action_id]
}

add_on_press_callback :: proc(action_id: Action_ID, callback_id: Callback_ID, group: Callback_Group, data: rawptr, callback: proc(rawptr)) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    for c in current_action.on_press {
        if c.id == callback_id {
            fmt.printfln("WARNING: Cannot add callback '%v' - already exist", callback_id)
            return
        }
    }

    append(&current_action.on_press, Input_Callback {group, callback_id, data, callback, true})
    append(&input.callback_groups[group], Callback_Group_Pair {action_id, callback_id})
}

enable_on_press_callback :: proc(action_id: Action_ID, callback_id: Callback_ID, enable: bool) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    for &callback, i in current_action.on_press {
        if callback.id == callback_id {
            callback.enabled = enable
            break
        }
    }
}

remove_on_press_callback :: proc(action_id: Action_ID, callback_id: Callback_ID) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    index_to_remove: int = -1
    
    for callback, i in current_action.on_press {
        if callback.id == callback_id {
            index_to_remove = i
            break
        }
    }

    if index_to_remove == -1 {
        fmt.printfln("WARNING: Cannot remove callback '%v' - does not exist", callback_id)
        return
    }

    callback_ref := &current_action.on_press[index_to_remove]
    group_id := callback_ref.group
    group := &input.callback_groups[callback_ref.group]

    if callback_ref.data != nil {
        free(callback_ref.data)
    }
    unordered_remove(&current_action.on_press, index_to_remove)

    index_group_to_remove: int = -1
    
    for callback, i in group {
        if callback.callback_id == callback_id {
            index_group_to_remove = i
            break
        }
    }

    if index_group_to_remove == -1 {
        fmt.printfln("WARNING: Cannot remove callback '%v' from group '%v' - not in group", callback_id, group_id)
        return
    }

    unordered_remove(group, index_group_to_remove)
}

add_on_release_callback :: proc(action_id: Action_ID, callback_id: Callback_ID, group: Callback_Group, data: rawptr, callback: proc(rawptr)) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    for c in current_action.on_release {
        if c.id == callback_id {
            fmt.printfln("WARNING: Cannot add callback '%v' - already exist", c.id)
            return
        }
    }

    append(&current_action.on_release, Input_Callback {group, callback_id, data, callback, true})
    append(&input.callback_groups[group], Callback_Group_Pair {action_id, callback_id})
}

enable_on_release_callback  :: proc(action_id: Action_ID, callback_id: Callback_ID, enable: bool) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    for &callback, i in current_action.on_release {
        if callback.id == callback_id {
            callback.enabled = enable
            break
        }
    }
}

remove_on_release_callback :: proc(action_id: Action_ID, callback_id: Callback_ID) {
    h := get_heart()
    input := &h.input_data

    current_action := &input.action_map[action_id]

    index_to_remove: int = -1

    for callback, i in current_action.on_release {
        if callback.id == callback_id {
            index_to_remove = i
            break
        }
    }

    if index_to_remove == -1 {
        fmt.printfln("WARNING: Cannot remove callback '%v' - does not exist", callback_id)
        return
    }

    callback_ref := &current_action.on_release[index_to_remove]
    group_id := callback_ref.group
    group := &input.callback_groups[callback_ref.group]

    if callback_ref.data != nil {
        free(callback_ref.data)
    }
    unordered_remove(&current_action.on_release, index_to_remove)

    index_group_to_remove: int = -1

    for callback, i in group {
        if callback.callback_id == callback_id {
            index_group_to_remove = i
            break
        }
    }

    if index_group_to_remove == -1 {
        fmt.printfln("WARNING: Cannot remove callback '%v' from group '%v' - not in group", callback_id, group_id)
        return
    }

    unordered_remove(group, index_group_to_remove)
}

input_group_enable :: proc(group: Callback_Group, enable: bool) {
    h := get_heart()
    input := &h.input_data

    for pair in input.callback_groups[group] {
        current_action := &input.action_map[pair.action_id]
        
        for &c in current_action.on_press {
            if c.group != group do continue
            c.enabled = enable
        }

        for &c in current_action.on_release {
            if c.group != group do continue
            c.enabled = enable
        }
    }
}

@(private)
update_if_held :: proc() {
    h := get_heart()
    input := &h.input_data

    state_ptr := sdl.GetKeyboardState(nil)
    for key_code, list in input.sdl_to_action_map {
        scancode := sdl.GetScancodeFromKey(key_code, nil) 
        is_pressed := state_ptr[scancode]

        for action_id in list {
            input.action_map[action_id].is_held = is_pressed
        }
    }
}

@(private)
update_input_event :: proc(event: sdl.Event) {
    h := get_heart()
    input := &h.input_data
    if event.type == .KEY_DOWN {
        actions, ok := input.sdl_to_action_map[event.key.key]
        if !ok {
            return
        }

        for action_id in actions {
            current_action := &input.action_map[action_id]
            for callback in current_action.on_press {
                if !callback.enabled do continue
                callback.callback(callback.data)
            }
        }
    }

    if event.type == .KEY_UP {
        actions, ok := input.sdl_to_action_map[event.key.key]
        if !ok {
            return
        }

        for action_id in actions {
            current_action := &input.action_map[action_id]
            for callback in current_action.on_release {
                if !callback.enabled do continue
                callback.callback(callback.data)
            }
        }
    }
}

@(private)
destroy_input :: proc() {
    h := get_heart()
    input := &h.input_data

    for action in input.action_map {
        for callback in action.on_press {
            if callback.data != nil {
                free(callback.data)
            }
        }
        for callback in action.on_release {
            if callback.data != nil {
                free(callback.data)
            }
        }
        delete(action.on_press)
        delete(action.on_release)
    }
    delete(input.action_map)
    for _, list in input.sdl_to_action_map {
        delete(list)
    }
    delete_map(input.sdl_to_action_map)

    for g in input.callback_groups {
        delete(g)
    }
    delete(input.callback_groups)
}