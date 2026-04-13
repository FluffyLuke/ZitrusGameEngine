package zitrus

Zitrus_Camera :: struct {
    position: Vec3,
    direction: Vec3,
    cameraRight: Vec3,
    cameraUp: Vec3,

    fov: f32
}


move_camera :: proc(move_by: Vec3) {
    h := get_heart()
    camera := &h.camera

    camera.position += move_by
}