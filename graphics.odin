package zitrus

import img "core:image"
import fmt "core:fmt"

import rl "vendor:raylib"

Image_Resource_ID :: distinct string

Image_Asset_Metadata_Single :: struct {
    id: string              `json:"id"`,
    type: string            `json:"type"`,
    shot: Rectangle         `json:"shot"`,
}

Image_Asset_Metadata_Multiple :: struct {
    id: string              `json:"id"`,
    type: string            `json:"type"`,
    shots: [32]Rectangle    `json:"shots"`,
}

Image_Single :: struct {
    shot: Rectangle,
}

Image_Multiple :: struct {
    shots: [32]Rectangle
}

Image_Asset :: struct {
    asset_id: Image_Resource_ID,
    using texture: rl.Texture2D,

    // type: union {
    //     Image_Single,
    //     Image_Multiple
    // }
}

Mesh_Flip :: enum {
    None,
    X,
    Y,
    XY,
}

Mesh_ID :: distinct u64
@(private="file")
next_mesh_id: Mesh_ID = 0

Image_Source :: distinct Rectangle

Mesh_2D :: struct {
    id: Mesh_ID,
    depth: uint,

    image: Image_Asset,
    src: Image_Source,

    dimensions: Unit2,
    flip: Mesh_Flip,
}

Graphics :: struct {
    meshes: map[Mesh_ID]Mesh_2D,
}

create_graphics :: proc() {
    heart.graphics.meshes = make(map[Mesh_ID]Mesh_2D)
}

destroy_graphics :: proc() {
    delete_all_meshes()
    delete(heart.graphics.meshes)
}

create_mesh :: proc(
    size: Unit2,
    depth: uint
) -> (mesh: Mesh_2D) {
    current_id := next_mesh_id
    next_mesh_id += 1
    

    real_depth := depth
    if depth >= RENDERING_DEPTH {
        fmt.printfln("WARNING: Depth '%v' is too great. Setting it to biggest value possible - %v", depth, RENDERING_DEPTH - 1)
        real_depth = RENDERING_DEPTH - 1
    }

    mesh = {
        id = next_mesh_id,
        depth = real_depth,
        dimensions = size,
    }

    return
}

delete_mesh :: proc(mesh: ^Mesh_2D) {
    h := get_heart()
    g := &h.graphics

    delete_key(&g.meshes, mesh.id)
}

delete_all_meshes :: proc() {
    h := get_heart()
    g := &h.graphics

    clear(&g.meshes)
}

mesh_set_texture :: proc(mesh: ^Mesh_2D, texture_id: Image_Resource_ID, src: Image_Source = {}) -> bool {
    if texture_id == "" {
        return false
    }

    image_asset, ok := get_texture(texture_id)

    if !ok {
        fmt.println("ERROR: Cannot find texture for mesh")
        return false
    }

    proper_src := src
    if src == {} {
        proper_src = {
            x = 0,
            y = 0,
            width = auto_cast image_asset.width,
            height = auto_cast image_asset.height,
        }
    }

    mesh.image = image_asset
    mesh.src = proper_src

    return true
}

// mesh_set_parameter_vec4 :: proc(mesh: ^Mesh_2D, name: string, value: Vec3) {
//     append(&mesh.program.vec3, Shader_Parameter(Vec3) {name, value})
// }

// mesh_delete_parameter_vec4 :: proc(mesh: ^Mesh_2D, name: string) -> bool {
//     index: int = -1
//     for v, i in mesh.program.vec3 {
//         if v.name == name {
//             index = i
//             break
//         }
//     }
//     if index != -1 {
//         unordered_remove(&mesh.program.vec3, index)
//         return true
//     }
//     return false
// }