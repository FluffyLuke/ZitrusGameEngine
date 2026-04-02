package zitrus

import "core:fmt"
import str "core:strings"
import "core:os"

import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

VBO :: u32
EBO :: u32
VAO :: u32

Program_Id :: u32
Shader_Id :: u32

BASIC_VERTEX_SHADER_PATH :: "vertex.glsl"
BASIC_FRAGMENT_SHADER_PATH :: "fragment.glsl"

Renderer :: struct {
    exe_path: String_Ref,

    window: ^sdl.Window,
    ctx: sdl.GLContext,

    basic_material: u32,
}

@(private)
init_renderer :: proc(r: ^Renderer, exe_path: String_Ref) -> bool {
    r.exe_path = exe_path
    
    init_sdl(r) or_return

    // Compile basic shaders
    vertex_shader := compile_shader(r, gl.VERTEX_SHADER, BASIC_VERTEX_SHADER_PATH) or_return
    fragment_shader := compile_shader(r, gl.FRAGMENT_SHADER, BASIC_FRAGMENT_SHADER_PATH) or_return

    r.basic_material = link_to_program(r, vertex_shader, fragment_shader) or_return
    gl.DeleteShader(vertex_shader)
    gl.DeleteShader(fragment_shader)

    return true
}
@(private)
init_sdl :: proc(r: ^Renderer) -> bool {
    if !sdl.Init({.VIDEO, .AUDIO}) {
        fmt.println("ERROR: Cannot init SDL: ", sdl.GetError())
        return false
    }

    r.window = sdl.CreateWindow("Game", 640, 480, {.OPENGL})
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

compile_shader :: proc(r: ^Renderer, shader_type: u32, shader_path: string) -> (Shader_Id, bool) {
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

link_to_program :: proc(r: ^Renderer, shaders: ..Shader_Id) -> (Program_Id, bool) {
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

render :: proc(z: ^Zitrus_Heart) {
    r := &z.renderer

    gl.ClearColor(0.2, 0.2, 0.3, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    gl.UseProgram(r.basic_material)
    
    view := view(z, Mesh_Component)
    for e in view.entities {
        m_c, ok := get_component(z, e, Mesh_Component)

        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, m_c.texture.texture_id);
        gl.BindVertexArray(m_c.vao)
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
    }
    destroy_view(&view)

    sdl.GL_SwapWindow(r.window)
}