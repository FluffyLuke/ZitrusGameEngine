package zitrus

Zitrus_Camera :: struct {
    position: Vec3,
    direction: Vec3,
    cameraRight: Vec3,
    cameraUp: Vec3,

    fov: f32
}


move_camera :: proc(z: ^Zitrus_Heart, move_by: Vec3) {
    camera := &z.camera

    camera.position += move_by
}