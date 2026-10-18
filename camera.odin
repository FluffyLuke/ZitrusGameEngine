package zitrus

import "core:fmt"
import "core:slice"

import rl "vendor:raylib"

Color :: distinct [4]u8
C_BLACK :: Color {0,0,0,255}

World_Camera :: struct{
    mode: Camera_Mode,
    background_color: rl.Color,
}

Camera_Mode :: union {
    Camera_Mode2D,
    Camera_Mode3D,
}

Camera_Mode2D :: struct {
    using camera: rl.Camera2D
}

Camera_Mode3D :: struct {
    fov: f32,
    using camera: rl.Camera3D
}

init_camera :: proc() {
    register_component(World_Camera, proc(id: Entity_ID, camera: ^World_Camera) {
        r := &heart.renderer
        index, found := slice.linear_search(r.registered_cameras[:][:], id)
        unordered_remove(&r.registered_cameras, index)

        if len(r.registered_cameras) == 0 {
            fmt.println("[WARNING] No more cameras found.")
            return;
        }

        if r.main_camera_entity == id {
            r.main_camera_entity = r.registered_cameras[0]
        }
    })
}

set_background_color :: proc(camera: ^World_Camera, color: Vec4Int) {
    camera.background_color = { auto_cast color.x, auto_cast color.y, auto_cast color.z, auto_cast color.a}
}

new_camera :: proc(
    is_2D: bool = true,
    
    bg_color: Color = C_BLACK,
    zoom: f32 = 1.0,
) {
    create_entity("Camera")

    camera := World_Camera {
        background_color = auto_cast bg_color,
    }

    set_component(entity, camera)

    if is_2D {
        m := Camera_Mode2D {}
        m.zoom = zoom
        m.target = {0, 0}
        m.offset = { f32(rl.GetScreenWidth()) / 2.0, f32(rl.GetScreenHeight()) / 2.0 }
        m.rotation = 0.0
    } else {
        fmt.println("[ERROR] 3D Mode not implemented.")
    }

    set_component(entity, camera)
    append(&heart.renderer.registered_cameras, entity)
}

update_camera :: proc (entity: Entity_ID, camera: ^World_Camera) {
    h_c := get_entity_heart(entity)
    switch &mode in camera.mode {
        case Camera_Mode2D: {
            mode.target = Vec2 { h_c.global_position.x, h_c.global_position.y } 
            mode.offset = { f32(rl.GetScreenWidth()) / 2.0, f32(rl.GetScreenHeight()) / 2.0 }
            mode.rotation = quaternion_to_vec3(h_c.global_rotation).z
        }
        case Camera_Mode3D: {
            fmt.println("[ERROR] 3D Mode not implemented.")
        }
    }
}

// Set new position for camera in game units
// camera_set_pos :: proc(pos: Vec2) {
//     h := get_heart()
//     camera := &h.renderer.camera

//     // Get unit system scale factor
//     unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

//     // Translate position in game units to raylib's
//     pos_scaled := Vec2 {
//         pos.x * unit_scale_x,
//         pos.y * unit_scale_y * -1, // Raylib's Y axis in inverted
//     }

//     camera.target = pos_scaled
// }

// Move camera by XY game units
// camera_move :: proc(move_by: Vec2) -> Vec2 {
//     h := get_heart()
//     camera := &h.renderer.camera

//     // Get unit system scale factor
//     unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

//     // Translate moveby in game units to raylib's
//     move_by_scaled := Vec2 {
//         move_by.x * unit_scale_x,
//         move_by.y * unit_scale_y * -1, // Raylib's Y axis in inverted
//     }

//     camera.target += move_by_scaled

//     return camera.target
// }