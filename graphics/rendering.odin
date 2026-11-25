package graphics

import la "core:math/linalg"

import rl "vendor:raylib"

import "../ecs"
import "../assets"
import "../types"

set_target_fps :: proc(fps: i32) {
    rl.SetTargetFPS(fps)
}

init_rendering :: proc () {
    rl.InitWindow(1200, 800, "ZitrusEngine")
    set_target_fps(60)

    assets.make_asset_manager(Sprite, delete_sprite)

    // Define rendering pipeline.
    ecs.add_system(ecs.InternalSystems.Render, {ecs.Query {
        {ecs.TransformComponent, SpriteComponent },
        proc(entity: ecs.Entity, delta: ecs.Time) {
            sprite := ecs.get_component(entity, SpriteComponent)
            transform := ecs.get_component(entity, ecs.TransformComponent)

            pos := transform.pos
            x, y, z := la.euler_angles_from_quaternion(transform.rotation, .XYZ)

            rl.DrawTextureEx(sprite.sprite.texture, {auto_cast pos.x, auto_cast pos.y}, x, auto_cast transform.scale.x, rl.WHITE)
        }}
    })
}

destroy_rendering :: proc() {
    rl.CloseWindow();
}

render :: proc() -> bool {
    rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)

        if render_system := ecs.get_system(ecs.InternalSystems.Render); render_system != nil {
            ecs.run_system(render_system, 0)
        }

    rl.EndDrawing()
    return rl.WindowShouldClose()
}