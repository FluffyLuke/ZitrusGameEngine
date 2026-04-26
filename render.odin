package zitrus

import "core:fmt"
import "core:os"
import str "core:strings"
import "core:slice"

import rl "vendor:raylib"

WINDOW_NAME :: "Game"
RENDERING_DEPTH :: 50

Renderer :: struct {
    depth_buckets: [RENDERING_DEPTH][dynamic]Entity_ID,

    camera: rl.Camera2D,
    background_color: rl.Color,
}

WINDOW_UNIT_HEIGHT :: 9
WINDOW_UNIT_WIDTH :: 16

Unit2 :: distinct [2]f32
Unit :: distinct f32

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

    for &bucket in renderer.depth_buckets {
        delete(bucket)
    }

    rl.CloseWindow()
}

render :: proc() {
    r := &heart.renderer

    // Clear buckets
    for &bucket in r.depth_buckets {
        clear(&bucket)
    }

    view := view(Mesh_2D)
    defer destroy_view(&view)

    for e in view.entities {
        h_c := get_entity_heart(e)
        m_c, _ := get_component(e, Mesh_2D)
        
        current_bucket := &r.depth_buckets[m_c.depth]
        append(current_bucket, e)
    }

    rl.BeginDrawing()
        rl.ClearBackground(r.background_color);

        rl.BeginMode2D(r.camera)
            
        #reverse for bucket in r.depth_buckets {
            for e in bucket {
                h_c := get_entity_heart(e)
                mesh, _ := get_component(e, Mesh_2D)

                // Get unit system scale factor
                unit_scale_x, unit_scale_y := f32(rl.GetScreenWidth()) / WINDOW_UNIT_WIDTH, f32(rl.GetScreenHeight()) / WINDOW_UNIT_HEIGHT

                dest := rl.Rectangle {
                    x = h_c.position.x * h_c.scale.x * unit_scale_x,
                    y = h_c.position.y * h_c.scale.y * unit_scale_y * -1, // RAYLIB has inverted Y axis
                    width = mesh.dimensions.x * h_c.scale.x * unit_scale_x,
                    height = mesh.dimensions.y * h_c.scale.y * unit_scale_y,
                }

                origin := rl.Vector2 {
                    (mesh.dimensions.x * h_c.scale.x * unit_scale_x) / 2.0,
                    (mesh.dimensions.y * h_c.scale.y * unit_scale_y) / 2.0,
                }

                src := rl_convert_rectangle(auto_cast mesh.src)
                if src.width == 0 || src.height == 0 {
                    src = rl.Rectangle {
                        x = 0, 
                        y = 0, 
                        width = f32(mesh.image.width), 
                        height = f32(mesh.image.height),
                    }
                }

                if mesh.flip == .X || mesh.flip == .XY do src.width *= -1
                if mesh.flip == .Y || mesh.flip == .XY do src.height *= -1

                rl.DrawTexturePro(
                    mesh.image, 
                    src,
                    dest,
                    origin,
                    0,
                    rl.WHITE,
                )
            }
        }

        rl.EndMode2D()
    rl.EndDrawing()
}

set_background_color :: proc(color: Vec4Int) {
    heart.renderer.background_color = { auto_cast color.x, auto_cast color.y, auto_cast color.z, auto_cast color.a}
}