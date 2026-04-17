package zitrus

Zitrus_Camera :: struct {
    position: Vec3,
    direction: Vec3,
    cameraRight: Vec3,
    cameraUp: Vec3,

    close_up: f32
}

camera_set_depth :: proc(depth: f32) {
    h := get_heart()
    camera := &h.camera

    camera.position.z = depth
}

camera_set_pos :: proc(pos: Vec2) {
    h := get_heart()
    camera := &h.camera

    camera.position.x = pos.x
    camera.position.y = pos.y
}

camera_move :: proc(move_by: Vec2) {
    h := get_heart()
    camera := &h.camera

    camera.position += {move_by.x, move_by.y, 0}
}