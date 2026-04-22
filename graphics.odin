package zitrus

import img "core:image"
import fmt "core:fmt"

import sdl "vendor:sdl3"
import gl "vendor:OpenGL"

Image_Resource_ID :: distinct string
Texture_GL_ID :: u32

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
    texture_id: Texture_GL_ID,
    using single: Image_Single,
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

Mesh_2D :: struct {
    id: Mesh_ID,
    texture: Image_Asset,

    dimensions: Unit_2D,
    flip: Mesh_Flip,

    vao: VAO,
    ebo: EBO,
    vbo: VBO,

    program: Program_Data,
}

Graphics :: struct {
    meshes: map[Mesh_ID]Mesh_2D,
}

destroy_graphics :: proc() {
    h := get_heart()
    delete_all_meshes()
    delete(h.graphics.meshes)
}

create_mesh :: proc(
    size: Unit_2D,
    src: Image_Source = {}
) -> (mesh: Mesh_2D, okay: bool = true) {
    // Set default program
    mesh.program.id = Program_Basic

    // === Setup geometry ===
    gl.GenVertexArrays(1, &mesh.vao)
    gl.BindVertexArray(mesh.vao)

    vertices: [20]f32
    if src != {} {
        vertices = [20]f32 {
            0.5,  0.5, 0, src.x_max, src.y_min,
            0.5, -0.5, 0, src.x_max, src.y_max,
            -0.5, -0.5, 0, src.x_min, src.y_max,
            -0.5,  0.5, 0, src.x_min, src.y_min
        }
    } else {
        vertices = [20]f32 {
            0.5,  0.5, 0, 1, 0,
            0.5, -0.5, 0, 1, 1,
            -0.5, -0.5, 0, 0, 1,
            -0.5,  0.5, 0, 0, 0
        }
    }

    indices := [6]u32 {
        0, 1, 3,
        1, 2, 3
    }

    gl.GenBuffers(1, &mesh.ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(&indices), gl.STATIC_DRAW)

    gl.GenBuffers(1, &mesh.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(&vertices), gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
    gl.EnableVertexAttribArray(1);

    // Unbind all of the stuff
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    mesh.dimensions = size

    return
}

Image_Source :: struct {
    x_min: f32,
    x_max: f32,
    y_min: f32,
    y_max: f32,
}

// Translates rectangle that holds pixels to values between 0 and 1
rectangle_to_image_source :: proc(src: Rectangle, dim: Vec2) -> Image_Source {
    return {
        x_min = src.x / dim.x,
        x_max = (src.x + src.width) / dim.x,
        y_min = src.y / dim.y,
        y_max = (src.y + src.height) / dim.y,
    }
}

mesh_swap_texture :: proc(mesh: ^Mesh_2D, texture_id: Image_Resource_ID) -> bool {
    if texture_id == "" {
        return false
    }

    image_asset, ok := get_texture(texture_id)

    if !ok {
        fmt.println("ERROR: Cannot find texture for mesh")
        return false
    }
    mesh.texture = image_asset
    return true
}

mesh_set_texture :: proc(mesh: ^Mesh_2D, texture_id: Image_Resource_ID, src: Image_Source = {}) -> bool {
    // === Setup texture ===
    if texture_id == "" {
        return false
    }

    image_asset, ok := get_texture(texture_id)

    if !ok {
        fmt.println("ERROR: Cannot find texture for mesh")
        return false
    }
    mesh.texture = image_asset
    gl.BindVertexArray(mesh.vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.DeleteBuffers(1, &mesh.vbo)

    dim := image_asset.dimensions

    vertices: [20]f32
    if src != {} {
        vertices = [20]f32 {
            0.5,  0.5, 0, src.x_max, src.y_min,
            0.5, -0.5, 0, src.x_max, src.y_max,
            -0.5, -0.5, 0, src.x_min, src.y_max,
            -0.5,  0.5, 0, src.x_min, src.y_min
        }
    } else {
        vertices = [20]f32 {
            0.5,  0.5, 0, 1, 0,
            0.5, -0.5, 0, 1, 1,
            -0.5, -0.5, 0, 0, 1,
            -0.5,  0.5, 0, 0, 0
        }
    }

    gl.GenBuffers(1, &mesh.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(&vertices), gl.STATIC_DRAW)

    // Unbind all of the stuff
    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    return true
}

mesh_set_program :: proc(mesh: ^Mesh_2D, program: Program_ID) {
    mesh.program.id = program
}

mesh_set_parameter_vec4 :: proc(mesh: ^Mesh_2D, name: string, value: Vec3) {
    append(&mesh.program.vec3, Shader_Parameter(Vec3) {name, value})
}

mesh_delete_parameter_vec4 :: proc(mesh: ^Mesh_2D, name: string) -> bool {
    index: int = -1
    for v, i in mesh.program.vec3 {
        if v.name == name {
            index = i
            break
        }
    }
    if index != -1 {
        unordered_remove(&mesh.program.vec3, index)
        return true
    }
    return false
}

delete_mesh :: proc(mesh: ^Mesh_2D) {
    h := get_heart()
    g := &h.graphics

    gl.DeleteVertexArrays(1, &mesh.vao)
    gl.DeleteBuffers(1, &mesh.ebo)
    gl.DeleteBuffers(1, &mesh.vbo)

    delete_program_data(&mesh.program)

    delete_key(&g.meshes, mesh.id)

    // delete(mesh.indices)
    // delete(mesh.vertices)
}

delete_all_meshes :: proc() {
    h := get_heart()
    g := &h.graphics

    for _, &mesh in g.meshes {
        gl.DeleteVertexArrays(1, &mesh.vao)
        gl.DeleteBuffers(1, &mesh.ebo)
        gl.DeleteBuffers(1, &mesh.vbo)
    }
    clear(&g.meshes)
}