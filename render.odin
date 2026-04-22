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
FBO :: u32
RBO :: u32

Program_ID :: u32
Shader_ID :: u32

WORLD_WIDTH_UNITS :: f32(16)
WORLD_HEIGHT_UNITS :: f32(9)

Unit_2D :: distinct Vec2
Unit :: distinct f32

MIN_DEPTH :: -100
MAX_DEPTH ::  100

VERTEX_PATH :: "vertex_base.glsl"
FRAGMENT_BASIC_PATH :: "fragment_base.glsl"
// FRAGMENT_LIGHT_PATH :: "fragment_light.glsl"

Program_Basic: Program_ID
// Program_Light: Program_ID

Renderer :: struct {
    global_ambient_color: Vec3,
    global_ambient_stregth: f32,

    exe_path: String_Ref,

    window: ^sdl.Window,
    ctx: sdl.GLContext,

    window_size: Vec2Int,
    background_color: Vec4,

    frame_buffer: FBO,
    render_buffer: RBO,
    frame_buffer_texture: Texture_GL_ID,
    screen_buffer_mesh: Mesh_2D,
}

Shader_Parameter :: struct($T: typeid) {
    name: string,
    value: T,
}

Program_Data :: struct {
    id: Program_ID,
    vec3: [dynamic]Shader_Parameter(Vec3),
}

delete_program_data :: proc(data: ^Program_Data) {
    delete(data.vec3)
}

@(private)
init_renderer :: proc( exe_path: String_Ref, window_size: Vec2Int) -> bool {
    h := get_heart()
    r := &h.renderer

    r.exe_path = exe_path
    r.window_size = window_size
    
    init_sdl(r) or_return

    // Compile basic shaders
    vertex_base_shader := compile_shader(r, gl.VERTEX_SHADER, VERTEX_PATH) or_return
    fragment_base_shader := compile_shader(r, gl.FRAGMENT_SHADER, FRAGMENT_BASIC_PATH) or_return
    // fragment_light_shader := compile_shader(r, gl.FRAGMENT_SHADER, FRAGMENT_LIGHT_PATH) or_return

    Program_Basic = link_to_program(r, vertex_base_shader, fragment_base_shader) or_return
    // Program_Light = link_to_program(r, vertex_base_shader, fragment_light_shader) or_return

    gl.DeleteShader(vertex_base_shader)
    gl.DeleteShader(fragment_base_shader)
    // gl.DeleteShader(fragment_light_shader)

    // Enable depth
    gl.Enable(gl.DEPTH_TEST)

    // Turn on blending (multiply pixels by textures alpha channel)
    gl.Enable(gl.BLEND)

    // Generate another frame buffer and texture for it + render buffer
    gl.GenFramebuffers(1, &r.frame_buffer)
    gl.BindFramebuffer(gl.FRAMEBUFFER, r.frame_buffer)

    // TODO: When screen changes size - resize the texture as well
    gl.GenTextures(1, &r.frame_buffer_texture)
    gl.BindTexture(gl.TEXTURE_2D, r.frame_buffer_texture);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, window_size.x, window_size.y, 0, gl.RGB, gl.UNSIGNED_BYTE, nil);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    gl.GenRenderbuffers(1, &r.render_buffer)
    gl.BindRenderbuffer(gl.RENDERBUFFER, r.render_buffer); 
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, window_size.x, window_size.y);  
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0);

    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, r.render_buffer)

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
        fmt.println("ERROR: Framebuffer is not complete")
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        return false
    }

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // Create texture mesh
    ok: bool
    r.screen_buffer_mesh, ok = create_mesh({auto_cast window_size.x, auto_cast window_size.y})
    if !ok {
        fmt.printfln("ERROR: Cannot create mesh for frame buffer")
        return false
    }
    
    
    // Set the standard alpha blending equation (multiply what's left by the backgrounds color)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    fmt.printfln("INFO: Successfully initialized renderer", )

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
        fmt.printfln("ERROR: cannot FIND shader - %s", shader_path)
        return gl.INVALID_VALUE, false
    }
    
    shader_string := str.clone_from(shader_raw, context.temp_allocator)
    shader_cstr := str.clone_to_cstring(shader_string, context.temp_allocator)
    
    shader_id: u32
    shader_id = gl.CreateShader(shader_type)
    gl.ShaderSource(shader_id, 1, &shader_cstr, nil)
    gl.CompileShader(shader_id)

    compile_status: i32
    gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &compile_status)
    // TODO: learn why I need to check if this isn't 1, since INVALID_OPERATION is not always returned when error is present?
    if compile_status == gl.INVALID_VALUE || compile_status == gl.INVALID_OPERATION || compile_status != 1 {
        info_log: [1024 * 8]u8
        gl.GetShaderInfoLog(shader_id, len(info_log), nil, &info_log[0])
        fmt.printfln("ERROR: cannot COMPILE shader '%s':", shader_path)
        fmt.printfln("%s", info_log)
        return gl.INVALID_VALUE, false
    }

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
    gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)

    if success != 1 {
        info_log: [512]u8
        gl.GetProgramInfoLog(shader_program, len(info_log), nil, &info_log[0])
        fmt.printfln("ERROR: Cannot link program - %s", info_log)
        return 0, false
    }

    fmt.println("INFO: Program linked properly")
    return shader_program, true

}

@(private)
destroy_renderer :: proc(r: ^Renderer) {
    gl.DeleteProgram(Program_Basic)

    gl.DeleteFramebuffers(1, &heart.renderer.frame_buffer)

    // gl.DeleteProgram(Program_Light)

    sdl.GL_DestroyContext(r.ctx)
    sdl.DestroyWindow(r.window)
    sdl.Quit()
}

set_ambient_strength :: proc(s: f32) {
    r := &heart.renderer
    if s < 0 {
        fmt.printfln("WARNING: cannot set global ambient strength to value below 0. Setting to 0")
        r.global_ambient_stregth = 0
        return
    }

    if s > 1 {
        fmt.printfln("WARNING: cannot set global ambient strength to value over 1. Setting to 1")
        r.global_ambient_stregth = 1
        return
    }
    r.global_ambient_stregth = s
}

set_ambient_color :: proc(color: Vec3) {
    r := &heart.renderer
    if color.x > 1 || color.x < 0 || color.y > 1 || color.y < 0 || color.z > 1 || color.z < 0 {
        fmt.printfln("WARNING: wrong ambient color: %v ...", color)
    }
    r.global_ambient_color = color
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
    r := &heart.renderer

    gl.ClearColor(r.background_color.x, r.background_color.y, r.background_color.z, r.background_color.w)
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    pipeline_lit_entities()

    sdl.GL_SwapWindow(r.window)
}

@(private="file")
pipeline_lit_entities :: proc() {
    r := &heart.renderer

    // gl.BindFramebuffer(gl.FRAMEBUFFER, r.frame_buffer)
    // It is technically possible to attach depth and stencil to a texture
    // https://learnopengl.com/Advanced-OpenGL/Framebuffers

    camera_view := la.matrix4_look_at(
        heart.camera.position, 
        heart.camera.position + heart.camera.direction,
        heart.camera.cameraUp
    )

    view := view(Mesh_2D)
    defer destroy_view(&view)

    for e in view.entities {
        h_c := get_entity_heart(e)
        m_c, _ := get_component(e, Mesh_2D)

        // FIXME: Changing program is expensive. Filter entities based on their program to avoid switches
        gl.UseProgram(m_c.program.id)

        texture := m_c.texture

        // Model matrix
        // Set scale, rotation and position
        model_matrix := Identity_Matrix
        model_matrix *= la.matrix4_translate(h_c.position)
        model_matrix *= la.matrix4_from_quaternion(h_c.rotation)

        world_tex_w := m_c.dimensions.x
        world_tex_h := m_c.dimensions.y
        model_matrix *= la.matrix4_scale(Vec3 {world_tex_w, world_tex_h, 1})
        model_matrix *= la.matrix4_scale(h_c.scale)

        switch (m_c.flip) {
            case .None:
            case .X: model_matrix *= la.matrix4_scale(Vec3{-1,1,1})
            case .Y: model_matrix *= la.matrix4_scale(Vec3{1,-1,1})
            case .XY: model_matrix *= la.matrix4_scale(Vec3{-1,-1,1})
        }
        // View matrix
        view_matrix := camera_view

        // projection matrix
        half_w, half_h := WORLD_WIDTH_UNITS / 2, WORLD_HEIGHT_UNITS / 2

        projection_matrix := Identity_Matrix
        projection_matrix *= la.matrix_ortho3d(
            -half_w / heart.camera.close_up, half_w / heart.camera.close_up,
            -half_h / heart.camera.close_up, half_h / heart.camera.close_up,
            MIN_DEPTH, MAX_DEPTH
        )

        //aspect := f32(r.window_size.x) / f32(r.window_size.y)
        // projection_matrix = projection_matrix * la.matrix4_perspective(f32(la.to_radians(h.camera.fov)), aspect, 0.1, 100.0)

        // vieport transform in shader
        model_loc := gl.GetUniformLocation(m_c.program.id, "model")
        view_loc := gl.GetUniformLocation(m_c.program.id, "view")
        projection_loc := gl.GetUniformLocation(m_c.program.id, "projection")
        
        gl.UniformMatrix4fv(model_loc, 1, gl.FALSE, cast(^f32)&model_matrix)
        gl.UniformMatrix4fv(view_loc, 1, gl.FALSE, cast(^f32)&view_matrix)
        gl.UniformMatrix4fv(projection_loc, 1, gl.FALSE, cast(^f32)&projection_matrix)

        // Set global parameters
        loc: i32

        loc = gl.GetUniformLocation(m_c.program.id, "ambientLightColor")
        gl.Uniform3f(loc, r.global_ambient_color.x, r.global_ambient_color.y, r.global_ambient_color.z)

        loc = gl.GetUniformLocation(m_c.program.id, "ambientStrength")
        gl.Uniform1f(loc, r.global_ambient_stregth)

        // Set additional parameters defined mesh itself
        for param in m_c.program.vec3 {
            param_name_cstr := str.clone_to_cstring(param.name, context.temp_allocator)
            loc = gl.GetUniformLocation(m_c.program.id, param_name_cstr)
            gl.Uniform3f(loc, param.value.x, param.value.y, param.value.z)
        }

        free_all(context.temp_allocator)

        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, m_c.texture.texture_id);
        gl.BindVertexArray(m_c.vao)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
        //gl.DrawArrays(gl.TRIANGLES, 0, 36)
    }
}

@(private="file")
pipeline_light_entities :: proc() {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);   
}