package zitrus

import rl "vendor:raylib"

init_camera :: proc() {
    r := &heart.renderer
    r.camera.zoom = 1.0 
    r.camera.target = {0, 0}
    r.camera.offset = { f32(rl.GetScreenWidth()) / 2.0, f32(rl.GetScreenHeight()) / 2.0 }
    r.camera.rotation = 0.0
}

// Set new position for camera in game units
camera_set_pos :: proc(pos: Vec2) {
    h := get_heart()
    camera := &h.renderer.camera

    // Get unit system scale factor
    unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

    // Translate position in game units to raylib's
    pos_scaled := Vec2 {
        pos.x * unit_scale_x,
        pos.y * unit_scale_y * -1, // Raylib's Y axis in inverted
    }

    camera.target = pos_scaled
}

// Move camera by XY game units
camera_move :: proc(move_by: Vec2) -> Vec2 {
    h := get_heart()
    camera := &h.renderer.camera

    // Get unit system scale factor
    unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

    // Translate moveby in game units to raylib's
    move_by_scaled := Vec2 {
        move_by.x * unit_scale_x,
        move_by.y * unit_scale_y * -1, // Raylib's Y axis in inverted
    }

    camera.target += move_by_scaled

    return camera.target
}