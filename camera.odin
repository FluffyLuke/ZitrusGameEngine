package zitrus

import rl "vendor:raylib"

init_camera :: proc() {
    r := &heart.renderer
    r.camera.zoom = 1.0 
    r.camera.target = {0, 0}
    r.camera.offset = { f32(rl.GetScreenWidth()) / 2.0, f32(rl.GetScreenHeight()) / 2.0 }
    r.camera.rotation = 0.0
}

camera_set_pos :: proc(pos: Vec2) {
    h := get_heart()
    camera := &h.renderer.camera

    camera.target = pos
}

camera_move :: proc(move_by: Vec2) -> Vec2 {
    h := get_heart()
    camera := &h.renderer.camera

    camera.target += move_by

    return camera.target
}