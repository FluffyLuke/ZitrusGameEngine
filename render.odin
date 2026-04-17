package zitrus

import "core:fmt"
import "core:os"
import str "core:strings"
import la "core:math/linalg"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

VBO :: u32
EBO :: u32
VAO :: u32

Program_ID :: u32
Shader_ID :: u32

PPU :: 64 // 64 pixels are 1 unit in game

MIN_DEPTH :: -100
MAX_DEPTH ::  100

BASIC_VERTEX_SHADER_PATH :: "vertex.glsl"
BASIC_FRAGMENT_SHADER_PATH :: "fragment.glsl"

Renderer :: struct {
    exe_path: String_Ref,

    window: ^sdl.Window,
    ctx: sdl.GLContext,

    window_size: Vec2Int,
    background_color: Vec4,

    basic_material: u32,
}

@(private)
init_renderer :: proc( exe_path: String_Ref, window_size: Vec2Int) -> bool {
    h := get_heart()
    r := &h.renderer

    r.exe_path = exe_path
    r.window_size = window_size
    
    init_sdl(r) or_return

    // Compile basic shaders
    vertex_shader := compile_shader(r, gl.VERTEX_SHADER, BASIC_VERTEX_SHADER_PATH) or_return
    fragment_shader := compile_shader(r, gl.FRAGMENT_SHADER, BASIC_FRAGMENT_SHADER_PATH) or_return

    r.basic_material = link_to_program(r, vertex_shader, fragment_shader) or_return
    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)

    // Enable depth
    gl.Enable(gl.DEPTH_TEST)

    // Turn on blending (multiply pixels by textures alpha channel)
    gl.Enable(gl.BLEND)
    
    // Set the standard alpha blending equation (multiply what's left by the backgrounds color)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    return true
}
@(private)
init_sdl :: proc(r: ^Renderer) -> bool {
    if !sdl.Init({.VIDEO, .AUDIO}) {
        fmt.println("ERROR: Cannot init SDL: ", sdl.GetError())
        return false
    }

    r.window = sdl.CreateWindow("Game", r.window_size.x, r.window_size.y, {.OPENGL})
    if r.window == nil {
        fmt.println("ERROR: Cannot init window: ", sdl.GetError())
        sdl.Quit();
        return false
    }

    r.ctx = sdl.GL_CreateContext(r.window)
    if r.ctx == nil {
        fmt.println("ERROR: Cannot init renderer: ", sdl.GetError())
        sdl.DestroyWindow(r.window)
        sdl.Quit()
        return false
    }

    // This "points" the gl functions to your GPU drivers via SDL
    gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
        (cast(^rawptr)p)^ = rawptr(sdl.GL_GetProcAddress(name))
    })

    return true
}

compile_shader :: proc(r: ^Renderer, shader_type: u32, shader_path: string) -> (Shader_ID, bool) {
    defer free_all(context.temp_allocator)

    path := str.concatenate({r.exe_path, SHADERS_ROOT, shader_path}, context.temp_allocator)
    shader_raw, ok_file := os.read_entire_file_from_path(path, context.temp_allocator)
    if ok_file != os.ERROR_NONE {
        fmt.printfln("ERROR: cannot FIND shader: %s", shader_path)
        return 0, false
    }
    
    shader_string := str.clone_from(shader_raw, context.temp_allocator)
    shader_cstr := str.clone_to_cstring(shader_string, context.temp_allocator)
    
    shader_id: u32
    shader_id = gl.CreateShader(shader_type)
    gl.ShaderSource(shader_id, 1, &shader_cstr, nil)
    gl.CompileShader(shader_id)

    fmt.printfln("INFO: Shader '%s' compiled properly", shader_path)

    return shader_id, true
}

link_to_program :: proc(r: ^Renderer, shaders: ..Shader_ID) -> (Program_ID, bool) {
    shader_program: u32
    shader_program = gl.CreateProgram()
    
    for s in shaders {
        gl.AttachShader(shader_program, s)
    }

    gl.LinkProgram(shader_program)

    success: i32
    info_log: [512]u8
    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)

    if success != 1 {
        gl.GetProgramInfoLog(shader_program, 512, nil, &info_log[0])
        fmt.printfln("ERROR: Cannot compile shader: %s", info_log)
        return 0, false
    }

    fmt.println("INFO: Program linked properly")
    return shader_program, true

}

@(private)
destroy_renderer :: proc(r: ^Renderer) {
    gl.DeleteProgram(r.basic_material)

    sdl.GL_DestroyContext(r.ctx)
    sdl.DestroyWindow(r.window)
    sdl.Quit()
}

set_background_color :: proc(color: Vec4) {
    h := get_heart()
    r := &h.renderer
    r.background_color = color
}

get_window_size :: proc() -> Vec2Int {
    h := get_heart()
    r := &h.renderer
    return r.window_size
}

resize_window :: proc {
    resize_window_xy,
    resize_window_vec
}

resize_window_xy :: proc(x, y: i32) {
    h := get_heart()
    r := &h.renderer
    r.window_size = {x, y}

    if r.window != nil {
        sdl.SetWindowSize(r.window, x, y)
    }
}

resize_window_vec :: proc(size: Vec2Int) {
    h := get_heart()
    r := &h.renderer
    r.window_size = size

    if r.window != nil {
        sdl.SetWindowSize(r.window, size.x, size.y)
    }
}

render :: proc() {
    h := get_heart()
    r := &h.renderer

    gl.ClearColor(r.background_color.x, r.background_color.y, r.background_color.z, r.background_color.w)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.UseProgram(r.basic_material)

    world_height: f32 = 10.0
    aspect := f32(r.window_size.x) / f32(r.window_size.y)
    world_width := world_height * aspect

    half_w, half_h := world_width / 2, world_height / 2

    camera_view := la.matrix4_look_at(
        h.camera.position, 
        h.camera.position + h.camera.direction,
        h.camera.cameraUp
    )
    view := view(Mesh_2D)
    for e in view.entities {
    
        h_c := get_entity_heart(e)
        m_c, _ := get_component(e, Mesh_2D)

        texture := m_c.texture

        // Model matrix
        // Set scale, rotation and position
        model_matrix := Identity_Matrix
        model_matrix *= la.matrix4_translate(h_c.position)

        model_matrix *= la.matrix4_from_quaternion(h_c.rotation)

        world_tex_w := m_c.dimensions.x / PPU
        world_tex_h := m_c.dimensions.y / PPU
        model_matrix *= la.matrix4_scale(Vec3 {world_tex_w, world_tex_h, 1})

        model_matrix *= la.matrix4_scale(h_c.scale)
        
        // View matrix
        view_matrix := camera_view

        // projection matrix
        projection_matrix := Identity_Matrix
        projection_matrix *= la.matrix_ortho3d(
            -half_w / h.camera.close_up, half_w / h.camera.close_up,
            -half_h / h.camera.close_up, half_h / h.camera.close_up,
            MIN_DEPTH, MAX_DEPTH
        )

        //aspect := f32(r.window_size.x) / f32(r.window_size.y)
        // projection_matrix = projection_matrix * la.matrix4_perspective(f32(la.to_radians(h.camera.fov)), aspect, 0.1, 100.0)

        // vieport transform in shader
        model_loc := gl.GetUniformLocation(r.basic_material, "model")
        view_loc := gl.GetUniformLocation(r.basic_material, "view")
        projection_loc := gl.GetUniformLocation(r.basic_material, "projection")
        
        gl.UniformMatrix4fv(model_loc, 1, gl.FALSE, cast(^f32)&model_matrix)
        gl.UniformMatrix4fv(view_loc, 1, gl.FALSE, cast(^f32)&view_matrix)
        gl.UniformMatrix4fv(projection_loc, 1, gl.FALSE, cast(^f32)&projection_matrix)

        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, m_c.texture.texture_id);
        gl.BindVertexArray(m_c.vao)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
        //gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }
    destroy_view(&view)

    sdl.GL_SwapWindow(r.window)
}