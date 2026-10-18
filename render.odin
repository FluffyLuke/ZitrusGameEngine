package zitrus

import "core:fmt"
import "core:os"
import la "core:math/linalg"
import str "core:strings"
import "core:slice"

import rl "vendor:raylib"

WINDOW_NAME :: "Game"
RENDERING_DEPTH :: 50

Renderer :: struct {
    main_camera_entity: Entity_ID,
    registered_cameras: [dynamic]Entity_ID,

    depth_buckets: [RENDERING_DEPTH][dynamic]Entity_ID,
    debug_mode: bool,
}

WINDOW_UNIT_HEIGHT :: 9
WINDOW_UNIT_WIDTH :: 16

Unit :: f32
Unit2 :: [2]Unit

init_renderer :: proc(window_size: Vec2Int) {
    rl.InitWindow(window_size.x, window_size.y, WINDOW_NAME)
    rl.SetTargetFPS(60)

    renderer := &heart.renderer

    for &bucket in renderer.depth_buckets {
        bucket = make([dynamic]Entity_ID)
    }
}

destroy_renderer :: proc() {
    renderer := &heart.renderer

    delete(renderer.registered_cameras)

    for &bucket in renderer.depth_buckets {
        delete(bucket)
    }

    rl.CloseWindow()
}

debug_mode :: proc(enabled: bool) {
    if enabled {
        fmt.println("[INFO] Enabling debug mode.")
    } else {
        fmt.println("[INFO] Disasbling debug mode.")
    }
    heart.renderer.debug_mode = enabled
}

render :: proc() {
    r := &heart.renderer

    // Clear buckets
    for &bucket in r.depth_buckets {
        clear(&bucket)
    }

    entity_view := view(Mesh_2D)
    defer destroy_view(&entity_view)

    for e in entity_view.entities {
        h_c := get_entity_heart(e)
        m_c, _ := get_component(e, Mesh_2D)
        
        current_bucket := &r.depth_buckets[m_c.depth]
        append(current_bucket, e)
    }

    camera_view := view(World_Camera)
    defer destroy_view(&camera_view)
    
    for c in camera_view.entities {
        camera, _ := get_component(c, World_Camera)
        update_camera(c, camera)

        rl.BeginDrawing()
            rl.ClearBackground(camera.background_color);
            switch &mode in camera.mode {
                case Camera_Mode2D: render_2D(camera, &mode)
                case Camera_Mode3D: fmt.println("[ERROR] 3D Mode not implemented.")
            }
        rl.EndDrawing()
    }
}

COLLIDER2D_DEBUG_COLOR :: rl.Color {255, 0, 0, 90}

render_2D :: proc(camera: ^World_Camera, mode: ^Camera_Mode2D) {
    r := &heart.renderer

    rl.BeginMode2D(mode.camera)
    #reverse for bucket in r.depth_buckets {
        for e in bucket {
            h_c := get_entity_heart(e)
            mesh, _ := get_component(e, Mesh_2D)

            // Get unit system scale factor
            unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

            dest := rl.Rectangle {
                x = h_c.global_position.x * h_c.global_scale.x * unit_scale_x,
                y = h_c.global_position.y * h_c.global_scale.y * unit_scale_y * -1, // RAYLIB has inverted Y axis
                width = mesh.dimensions.x * h_c.global_scale.x * unit_scale_x,
                height = mesh.dimensions.y * h_c.global_scale.y * unit_scale_y,
            }

            origin := rl.Vector2 {
                (mesh.dimensions.x * h_c.global_scale.x * unit_scale_x) / 2.0,
                (mesh.dimensions.y * h_c.global_scale.y * unit_scale_y) / 2.0,
            }

            src := rl_convert_rectangle(auto_cast mesh.image.src)
            if src.width == 0 || src.height == 0 {
                src = rl.Rectangle {
                    x = 0, 
                    y = 0, 
                    width = f32(mesh.image.src.width), 
                    height = f32(mesh.image.src.height),
                }
            }

            if mesh.flip == .X || mesh.flip == .XY do src.width *= -1
            if mesh.flip == .Y || mesh.flip == .XY do src.height *= -1

            pitch, yaw, roll := la.euler_angles_from_quaternion(h_c.global_rotation, .ZYX)
            rotation := Vec3 {roll, yaw, pitch} / la.to_radians(f32(1.0))

            rl.DrawTexturePro(
                mesh.image.asset, 
                src,
                dest,
                origin,
                rotation.z,
                rl.WHITE,
            )
        }
    }
    if r.debug_mode do render_debug()
    rl.EndMode2D()
}

@(private="file")
render_debug :: proc() {
    view := view(Collider_2D)
    defer destroy_view(&view)

    for e in view.entities {
        h_c := get_entity_heart(e)
        collider, _ := get_component(e, Collider_2D)

        // Get unit system scale factor
        unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

        dest := rl.Rectangle {
            x = h_c.global_position.x * h_c.global_scale.x * unit_scale_x,
            y = h_c.global_position.y * h_c.global_scale.y * unit_scale_y * -1, // RAYLIB has inverted Y axis
            width = collider.size.x * h_c.global_scale.x * unit_scale_x,
            height = collider.size.y * h_c.global_scale.y * unit_scale_y,
        }

        origin := rl.Vector2 {
            ((collider.x / h_c.global_scale.x) * unit_scale_x) / 2.0,
            ((collider.y / h_c.global_scale.y) * unit_scale_y) / 2.0,
        }

        pitch, yaw, roll := la.euler_angles_from_quaternion(h_c.global_rotation, .ZYX)
        rotation := Vec3 {roll, yaw, pitch} / la.to_radians(f32(1.0))

        color := COLLIDER2D_DEBUG_COLOR
        rl.DrawRectanglePro(dest, origin, rotation.z, {auto_cast color.x, auto_cast color.y, auto_cast color.z, color.w})
    }
}