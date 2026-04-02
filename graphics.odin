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

Mesh_Component :: struct {
    texture: Image_Asset,
    verticies: []f32,
    indices: []u32,

    vao: VAO,
    ebo: EBO,
    vbo: VBO
}

create_mesh_component :: proc(
    z: ^Zitrus_Heart,
    verticies: []f32, 
    indices: []u32, 
    texture_id: Image_Resource_ID = ""
) -> (m_c: Mesh_Component, okay: bool = true) {
    // === Setup geometry ===
    gl.GenVertexArrays(1, &m_c.vao)
    gl.BindVertexArray(m_c.vao)

    m_c.verticies = make([]f32, len(verticies))
    m_c.indices = make([]u32, len(indices))

    copy(m_c.verticies, verticies)
    copy(m_c.indices, indices)

    gl.GenBuffers(1, &m_c.ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, m_c.ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(m_c.indices) * size_of(u32), raw_data(m_c.indices), gl.STATIC_DRAW)

    gl.GenBuffers(1, &m_c.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, m_c.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(verticies) * size_of(f32), raw_data(verticies), gl.STATIC_DRAW)

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

    m_c.texture = image_asset

    return
}

delete_mesh_component :: proc(m_c: ^Mesh_Component) {
    gl.DeleteVertexArrays(1, &m_c.vao)
    gl.DeleteBuffers(1, &m_c.ebo)
    gl.DeleteBuffers(1, &m_c.vbo)

    delete(m_c.indices)
    delete(m_c.verticies)
}