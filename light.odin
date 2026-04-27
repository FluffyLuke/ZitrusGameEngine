package zitrus

import "core:fmt"

import rl "vendor:raylib"

MAX_SHADOWS :: 16
MAX_OBSTRUCTIONS :: 256

Shadow_Geometry :: struct {
    // 4 Edges of the shadow
    vertices: [4]Vec2
}

Light_Source :: struct {
    shadow_count: uint,
    // obstructions_in_radius: [MAX_OBSTRUCTIONS]Rectangle,
    shadows: [MAX_SHADOWS]Shadow_Geometry,
}

Light_Data :: struct {
    mask: rl.RenderTexture2D,
    obstructions: [dynamic]Rectangle
}

create_light_data :: proc() {
    data := &heart.lights

    // TODO: Make this resizable with screen size
    data.mask = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())

    data.obstructions = make([dynamic]Rectangle)
}

destroy_light_data :: proc() {
    data := &heart.lights

    rl.UnloadRenderTexture(data.mask)
    delete(data.obstructions)
}

Light_Obstruction_Tag :: struct {}

create_light_obstruction :: proc(pos: Rectangle, color: Vec4) {
    id := create_entity({0,0}) // Position of the entity is not used

    set_component(id, Light_Obstruction_Tag {})
    set_component(id, Region {
        area = pos,
        color = color,
    })
}

create_light :: proc(pos: Vec2) {
    id := create_entity(pos, on_delete = proc(id: Entity_ID) {
        mesh, _ := get_component(id, Mesh_2D)
        delete_mesh(mesh)
    })

    set_component(id, Light_Source {})

    mesh := create_mesh({1.5,1.5}, 0)
    mesh_set_texture(&mesh, "placeholder.png")

    set_component(id, mesh)
}

update_light :: proc(source: ^Light_Source)
draw_light_mask :: proc(source: ^Light_Source)