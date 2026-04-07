package zitrus

import img "core:image"
import fmt "core:fmt"

import sdl "vendor:sdl3"
import gl "vendor:OpenGL"

Image_Resource_ID :: distinct string
Texture_GL_Id :: u32

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
    id: Image_Resource_ID,
    dimensions: Vec2,
    texture_id: Texture_GL_Id,
    type: union {
        Image_Single,
        Image_Multiple
    }
}

Mesh :: struct {
    texture: Image_Asset,
    vertices: []f32,
    indices: []u32,

    scale: Vec3,

    vao: VAO,
    ebo: EBO,
    vbo: VBO
}

create_texture_mesh :: proc(
    z: ^Zitrus_Heart, 
    texture_id: Image_Resource_ID,
    scale: Vec3 = {1,1,1}
) -> (mesh: Mesh, okay: bool = true) {
    // === Setup geometry ===
    gl.GenVertexArrays(1, &mesh.vao)
    gl.BindVertexArray(mesh.vao)

    mesh.vertices = []f32 {
         0.5,  0.5, 0, 1.0, 0.0,
         0.5, -0.5, 0, 1.0, 1.0,
        -0.5, -0.5, 0, 0.0, 1.0,
        -0.5,  0.5, 0, 0.0, 0.0
    }
    mesh.indices = []u32 {
        0, 1, 3,
        1, 2, 3
    }
    mesh.scale = scale

    gl.GenBuffers(1, &mesh.ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(mesh.indices) * size_of(u32), raw_data(mesh.indices), gl.STATIC_DRAW)

    gl.GenBuffers(1, &mesh.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(mesh.vertices) * size_of(f32), raw_data(mesh.vertices), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1);

    // Unbind all of the stuff
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    // === Setup texture ===
    if texture_id == "" {
        okay = false
        return
    }

    image_asset, ok := z.asset_manager.image_assets[texture_id]

    if !ok {
        fmt.printfln("ERROR: cannot find texure in asset manager of id: %s", texture_id)
        okay = false
        return
    }


    mesh.texture = image_asset

    return
}

delete_mesh :: proc(mesh: ^Mesh) {
    gl.DeleteVertexArrays(1, &mesh.vao)
    gl.DeleteBuffers(1, &mesh.ebo)
    gl.DeleteBuffers(1, &mesh.vbo)

    // delete(mesh.indices)
    // delete(mesh.vertices)
}