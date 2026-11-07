package ecs

import "core:fmt"
import "core:os"
import str "core:strings"
import s "core:sync"
import t "core:thread"

Exit_Command :: struct {}
Print_Archetypes_Command :: struct {}
Print_Components_Command :: struct {}

Debug_Command :: union {
    Exit_Command,
    Print_Archetypes_Command,
    Print_Components_Command,
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
            case Exit_Command: {
                command_exit()
            }
            case Print_Archetypes_Command: {
                command_print_archetypes()
            }
            case Print_Components_Command: {
                command_print_components()
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
                case "exit", "e":
                    append_command(Exit_Command {})
                case "print_archetypes", "p_e":
                    append_command(Print_Archetypes_Command {})
                case "print_components", "p_c":
                    append_command(Print_Components_Command {})
                case: {
                    fmt.printfln("[INPUT|ERROR] Unknown command '%v'", input)
                }
            }
        }
        free_all(context.temp_allocator)
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
command_exit :: proc() {
    zecs.should_close = true;
}

@(private="file")
command_print_components :: proc() {
    fmt.printfln("[DEBUG] Printing all components...")
    for type, id in get_component_map() {
        fmt.printfln("Type: '%v', ID: '%v'", type, id)
    }
}

@(private="file")
command_print_archetypes :: proc() {
    fmt.printfln("[DEBUG] Printing all archetypes...")
    for mask, archetype in zecs.archetypes {
        fmt.printfln("Archetype of mask '%v'", mask)
        component_types := [dynamic]typeid {}
        for c in archetype.component_metadata {
            append(&component_types, get_component_type(c.id))
        }
        defer delete(component_types)

        fmt.printfln("- Components: %v", component_types[:])
        fmt.printfln("- Chunk Capacity: '%v'", archetype.chunk_capacity)
        fmt.printfln("- Chunk count: %v", len(archetype.chunks))
        for c in archetype.chunks {
            fmt.printfln("    - Entity count: %v", c.count)
        }
    }
}

