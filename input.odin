package zitrus

import "libs:zitrus"
import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

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
INPUT_TO_RAYLIB := [Input_Key]rl.KeyboardKey {
    // Letters
    .A = .A, .B = .B, .C = .C, .D = .D, .E = .E,
    .F = .F, .G = .G, .H = .H, .I = .I, .J = .J,
    .K = .K, .L = .L, .M = .M, .N = .N, .O = .O,
    .P = .P, .Q = .Q, .R = .R, .S = .S, .T = .T,
    .U = .U, .V = .V, .W = .W, .X = .X, .Y = .Y, .Z = .Z,

    // Numbers
    .Num0 = .ZERO, .Num1 = .ONE, .Num2 = .TWO, .Num3 = .THREE, .Num4 = .FOUR,
    .Num5 = .FIVE, .Num6 = .SIX, .Num7 = .SEVEN, .Num8 = .EIGHT, .Num9 = .NINE,

    // Function Keys
    .F1 = .F1, .F2 = .F2, .F3 = .F3, .F4 = .F4, 
    .F5 = .F5, .F6 = .F6, .F7 = .F7, .F8 = .F8,
    .F9 = .F9, .F10 = .F10, .F11 = .F11, .F12 = .F12,

    // Navigation & Controls
    .Space     = .SPACE,
    .Escape    = .ESCAPE,
    .Enter     = .ENTER,
    .Tab       = .TAB,
    .Backspace = .BACKSPACE,
    .Insert    = .INSERT,
    .Delete    = .DELETE,
    .Right     = .RIGHT,
    .Left      = .LEFT,
    .Down      = .DOWN,
    .Up        = .UP,
    .Page_Up   = .PAGE_UP,
    .Page_Down = .PAGE_DOWN,
    .Home      = .HOME,
    .End       = .END,

    // Locks and System
    .Caps_Lock    = .CAPS_LOCK,
    .Scroll_Lock  = .SCROLL_LOCK,
    .Num_Lock     = .NUM_LOCK,
    .Print_Screen = .PRINT_SCREEN,
    .Pause        = .PAUSE,

    // Symbols
    .Grave         = .GRAVE,
    .Minus         = .MINUS,
    .Equals        = .EQUAL,
    .Left_Bracket  = .LEFT_BRACKET,
    .Right_Bracket = .RIGHT_BRACKET,
    .Backslash     = .BACKSLASH,
    .Semicolon     = .SEMICOLON,
    .Apostrophe    = .APOSTROPHE,
    .Comma         = .COMMA,
    .Period        = .PERIOD,
    .Slash         = .SLASH,

    // Modifiers
    .L_Shift   = .LEFT_SHIFT,
    .R_Shift   = .RIGHT_SHIFT,
    .L_Control = .LEFT_CONTROL,
    .R_Control = .RIGHT_CONTROL,
    .L_Alt     = .LEFT_ALT,
    .R_Alt     = .RIGHT_ALT,
    .L_GUI     = .LEFT_SUPER,
    .R_GUI     = .RIGHT_SUPER,
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
    rl_to_action_map: map[rl.KeyboardKey][dynamic]Action_ID,

    callback_groups: [dynamic][dynamic]Callback_Group_Pair,
}

configurate_input :: proc(actions: map[Action_ID]Input_Key, callback_groups_number: int) {
    h := get_heart()

    input := &h.input_data

    resize(&input.action_map, len(actions))
    for id, key in actions {
        sdl_key := INPUT_TO_RAYLIB[key]

        input.action_map[id] = {
            key = key
        }
        
        if !(sdl_key in input.rl_to_action_map) {
            input.rl_to_action_map[sdl_key] = make([dynamic]Action_ID)
        }
        
        list := &input.rl_to_action_map[sdl_key]
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
            fmt.printfln("[WARNING] Cannot add callback '%v' - already exist", callback_id)
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
        fmt.printfln("[WARNING] Cannot remove callback '%v' - does not exist", callback_id)
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
        fmt.printfln("[WARNING] Cannot remove callback '%v' from group '%v' - not in group", callback_id, group_id)
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
            fmt.printfln("[WARNING] Cannot add callback '%v' - already exist", c.id)
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
        fmt.printfln("[WARNING] Cannot remove callback '%v' - does not exist", callback_id)
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
        fmt.printfln("[WARNING] Cannot remove callback '%v' from group '%v' - not in group", callback_id, group_id)
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
update_input :: proc() {
    h := get_heart()
    input := &h.input_data

    // Do callbacks
    for &action in input.action_map {
        raylib_key := INPUT_TO_RAYLIB[action.key]

        if rl.IsKeyPressed(raylib_key) {
            for callback in action.on_press {
                if !callback.enabled do continue
                callback.callback(callback.data)
            }
        }

        if rl.IsKeyReleased(raylib_key) {
            for callback in action.on_release {
                if !callback.enabled do continue
                callback.callback(callback.data)
            }
        }

        action.is_held = rl.IsKeyDown(raylib_key)
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
    for _, list in input.rl_to_action_map {
        delete(list)
    }
    delete_map(input.rl_to_action_map)

    for g in input.callback_groups {
        delete(g)
    }
    delete(input.callback_groups)
}

// === Common functions ===

toggle_debug_callback :: proc(rawptr) {
    heart.renderer.debug_mode = !heart.renderer.debug_mode

    if heart.renderer.debug_mode {
        fmt.println("DEBUG: debug mode turned on")
    } else {
        fmt.println("DEBUG: debug mode turned off")
    }
}