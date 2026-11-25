package input

import rl "vendor:raylib"

key_pressed :: proc(key: Input_Key) -> bool {
    return rl.IsKeyDown(INPUT_TO_RAYLIB[key])
}

key_held :: proc(key: Input_Key) -> bool {
    return rl.IsKeyDown(INPUT_TO_RAYLIB[key])
}

key_released :: proc(key: Input_Key) -> bool {
    return rl.IsKeyPressed(INPUT_TO_RAYLIB[key])
}

// TODO: Do a Unity-like action system