package zitrus

import "core:fmt"
import fp "core:path/filepath"
import str "core:strings"

Entity_Properties_NilRef :: ""
Entity_Properties_Ref :: string
Entity_Default_Properties :: struct {
    parent: Entity_Properties_Ref,

    position: Vec3,
    scale: Vec3,
    rotation: quaternion128,

    tags: [dynamic]string,
    values: struct {
        vec2: map[string]Vec2,
        ints: map[string]i64,
        floats: map[string]f64,
        strings: map[string]string,
    }
}

Level_ID :: distinct string
Level :: struct {
    label: Level_ID,
    entities: map[Entity_Properties_Ref]Entity_Default_Properties,

    start: proc(self: ^Level),
    update: proc(self: ^Level, delta_time: f64),
    end: proc(self: ^Level),
}

Level_Data :: struct {
    should_quit: bool,
    current_level: Level_ID,
    levels: map[Level_ID]Level,
}

init_levels :: proc(levels: map[Level_ID]Level, first_level: Level_ID) {
    // First level in list should also be the first level to be started
    heart.level_data.levels = levels
    heart.level_data.current_level = first_level
}

set_level_execution :: proc(
    data: map[Level_ID]Level, 
    level_id: Level_ID,
    start: proc(self: ^Level) = proc(self: ^Level) {},
    update: proc(self: ^Level, delta_time: f64) = proc(self: ^Level, delta_time: f64) {},
    end: proc(self: ^Level) = proc(self: ^Level) {},
) -> bool {
    lvl, ok := &data[level_id]
    if !ok {
        fmt.printfln("[ERROR] Cannot find level with id '%v'. Execution functions will not be set.", level_id)
        return false
    }
    
    lvl.start = start
    lvl.update = update
    lvl.end = end

    return true
}

destroy_levels :: proc() {
    for id, l in heart.level_data.levels {
        delete_string(auto_cast l.label)

        for ref_id, e in l.entities {
            defer delete_string(ref_id)
            for t in e.tags do delete_string(t)
            delete(e.tags)

            for k in e.values.vec2 do delete_string(k)
            for k in e.values.ints do delete_string(k)
            for k in e.values.floats do delete_string(k)

            for k, v in e.values.strings {
                delete_string(k)
                delete_string(v)
            }

            delete_map(e.values.vec2)
            delete_map(e.values.ints)
            delete_map(e.values.floats)
            delete_map(e.values.strings)
        }
        delete_map(l.entities)
    }

    delete_map(heart.level_data.levels)
}

// This function also clears current image assets (deallocates them)
// and clears current entities
// it will not however clear other data allocated during "start"
change_level :: proc(next_level: Level_ID) -> bool {
    lvl_data := &heart.level_data

    if next_level not_in lvl_data.levels {
        fmt.printfln("[ERROR] Cannot change level. ID does not exist: '%v'", next_level)
        return false
    }
    fmt.printfln("[INFO] Changing level. ID passed: '%v'", next_level)

    old_level := &lvl_data.levels[lvl_data.current_level]
    old_level.end(old_level)
    asset_manager_unload_textures(false)

    clear_ecs()
    destroy_all_meshes()

    lvl_data.current_level = lvl_data.levels[next_level].label
    new_level := &lvl_data.levels[lvl_data.current_level]
    load_new_level(new_level)
    lvl_data.levels[lvl_data.current_level].start(new_level)

    return true
}

load_new_level :: proc(lvl: ^Level) {
    defer free_all(context.temp_allocator)
    fmt.printfln("[INFO] Loading level '%v'", lvl.label)
    load_all_textures(str.concatenate({"levels/", auto_cast lvl.label}, context.temp_allocator))
    create_entities(lvl)
    lvl.start(lvl)
}

@(private="file")
create_entities :: proc(lvl: ^Level) {
    // Used to translate external editor's IDs to internal IDs
    entity_data_tuple :: struct {id: Entity_ID, properties: Entity_Default_Properties}
    ref_to_entity := map[Entity_Properties_Ref]entity_data_tuple {}
    defer delete_map(ref_to_entity)

    for ref_id, &e in lvl.entities {
        // Create basic entity
        entity_id := create_entity(local_pos = e.position, tags = e.tags[:])
        for t in e.tags {
            set_tag(entity_id, t)
        }

        // Map IDs
        ref_to_entity[ref_id] = { entity_id, e }

        // Check if it has "_Texture" meta value
        add_texture: if value := get_entity_value(e.values.strings, "_Texture"); value != nil {
            texture_size: Unit2 = {1,1} // Default size
            depth: uint = 0 // Default depth
            if v := get_entity_value(e.values.vec2, "_Texture_Size"); v != nil {
                texture_size = v.(Vec2)
            }

            mesh := create_mesh(texture_size, depth)

            image_id := Image_Resource_ID(value.(string))
            if ok := mesh_set_texture(&mesh, image_id); !ok {
                fmt.printfln("[Warning] Cannot create mesh component.")
                destroy_mesh(&mesh)
                break add_texture
            }
            destroy_mesh(&mesh)
            set_component(entity_id, mesh)
        }

        add_collider_2D: if value := get_entity_value(e.values.vec2, "_Collider2D"); value != nil {
            collider := Collider_2D {
                size = {1,1}, // Default size
                origin = {0,0}, // Default origin
            }

            if v := get_entity_value(e.values.vec2, "_Collider2D_Size"); v != nil {
                collider.size = auto_cast v.(Vec2)
            }

            if v := get_entity_value(e.values.vec2, "_Collider2D_Origin"); v != nil {
                collider.origin = auto_cast v.(Vec2)
            }

            set_component(entity_id, collider)
        }
    }

    // Resolve dependencies
    for ref_id, &t in ref_to_entity {
        entity := t.id
        properties := &t.properties

        if parent_tuple, ok := ref_to_entity[properties.parent]; ok {
            set_parent(parent_tuple.id, entity)
        } else {
            fmt.printfln("[ERROR] Cannot find parent of id '%v'", properties.parent)
        }
    }
}

// Helper functions
get_entity_value :: proc {
    get_entity_value_vec2,
    get_entity_value_float,
    get_entity_value_int,
    get_entity_value_string,
}

get_entity_value_vec2 :: proc(e: map[string]Vec2, value_id: string) -> Maybe(Vec2) {
    for k, v in e {
        if k == value_id do return v
    }
    return nil
}

get_entity_value_float :: proc(e: map[string]f64, value_id: string) -> Maybe(f64) {
    for k, v in e {
        if k == value_id do return v
    }
    return nil
}

get_entity_value_int :: proc(e: map[string]i64, value_id: string) -> Maybe(i64) {
    for k, v in e{
        if k == value_id do return v
    }
    return nil
}

get_entity_value_string :: proc(e: map[string]string, value_id: string) -> Maybe(string) {
    for k, v in e {
        if k == value_id do return v
    }
    return nil
}