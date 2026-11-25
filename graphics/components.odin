package graphics

import "core:fmt"

import rl "vendor:raylib"

import "../ecs"

Camera :: struct {
    rl_camera: rl.Camera3D,
    zoom: f32,
}

CameraProjectionType :: rl.CameraProjection

attach_camera :: proc(e: ecs.Entity, fov: f32 = 1, projection: CameraProjectionType = CameraProjectionType.PERSPECTIVE) {
    new_camera := Camera {
        rl_camera = rl.Camera {
            position = {0,0,0}, // Position should be set during the render part.
            target = {0,0,0}, // Target should be set during the render part.
            up = {0, 1, 0},
            fovy = fov,
            projection = projection
        },
        zoom = 1,
    }
    ecs.add_component(e, new_camera)
}

SpriteComponent :: struct {
    sprite: Sprite,
}

// Sprite must be loaded before this function can be used.
attach_sprite_component :: proc(e: ecs.Entity, name: string) -> bool {
    sprite := get_sprite(name)

    if sprite == nil {
        fmt.printfln("[ERROR|Graphics] Cannot create sprite component of name '%v', because sprite does not exists!", name)
        return false
    }

    ecs.add_component(e, sprite)

    return true
}