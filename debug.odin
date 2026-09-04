package zitrus

import "core:fmt"
import "core:os"
import str "core:strings"
import s "core:sync"
import t "core:thread"

when ODIN_DEBUG 
{


Print_Command :: struct {}

Debug_Command :: union {
    Print_Command,
}

Debug_Data :: struct {
    mutex: s.Mutex,
    thread: ^t.Thread,
    commands: [dynamic]Debug_Command,
}

debug: Debug_Data

init_debug :: proc() {
    debug.thread = t.create_and_start(debug_thread)
}

check_debug :: proc() {
    s.lock(&debug.mutex)
    defer s.unlock(&debug.mutex)

    for c in debug.commands {
        switch data in c {
            case Print_Command: {
                command_print(data)
            }
        }
    }
    clear(&debug.commands)
}

destroy_debug :: proc() {
    t.terminate(debug.thread, 1)
    delete(debug.commands)
}

@(private="file")
debug_thread :: proc() {
    for {
        buf: [256]byte
        n, err := os.read(os.stdin, buf[:])

        if err == nil {
            // Convert the raw bytes to a string and trim the invisible newline character (\n)
            input := str.trim_space(string(buf[:n]))

            switch input {
                case "print", "p", "print all": {
                    append_command(Print_Command {})
                }
                case: {
                    fmt.printfln("[INPUT|ERROR] Unknown command '%v'", input)
                }
            }
        }
    }
}

@(private="file")
append_command :: proc(c: Debug_Command) {
    if s.guard(&debug.mutex) {
        append(&debug.commands, c)
    }
}

/////////////////////////////////////////////////////////////
// COMMANDS - They should be only run when mutex is locked //
/////////////////////////////////////////////////////////////

@(private="file")
command_print :: proc(data: Print_Command) {
    v := view(Entity_Heart)

    fmt.printfln("[INPUT|INFO] Here are all of the entities:")
    for e in v.entities {
        h_c := get_entity_heart(e)

        parent_id_str := h_c.parent != TOMBSTONE ? fmt.aprint(h_c.parent) : str.clone("None")

        fmt.printf("- Name: '%v'", h_c.name)
        fmt.printf(" | ID: %v", e)
        fmt.printf(" | ParentID: %v", parent_id_str)
        fmt.printf(" | Pos(L/G): %v / %v", h_c.local_position, h_c.global_position)

        euler_global := quaternion_to_vec3(h_c.global_rotation)
        euler_local := quaternion_to_vec3(h_c.local_rotation) 
        fmt.printf(" | Rotation(L/G): %v / %v", euler_local, euler_global)
        fmt.printf("\n")
    }
}

}