package zitrus

import "core:fmt"
import "core:os"
import "core:time"
import la "core:math/linalg"

import sdl "vendor:sdl3"

// https://github.com/chrischristakis/seecs/blob/master/seecs.h
// https://www.youtube.com/watch?v=yyZMoE1FAJ0
// Very helpful

Entity_ID :: Sparse_Index
TOMBSTONE :: max(Sparse_Index)

MAX_COMPONENTS :: 128
Component_Mask :: bit_set[0..<MAX_COMPONENTS]

Component_Mask_Sparse_Set :: Sparse_Set
Entity_ID_Sparse_Set :: Sparse_Set

ASSET_ROOT :: "/assets/"
SHADERS_ROOT :: "/shaders/"

Level :: struct {
    label: u32,
    // custom_data: rawptr,
    start: proc(heart: ^Zitrus_Heart),  // Initialize level
    update: proc(heart: ^Zitrus_Heart), // Update logic
    end: proc(heart: ^Zitrus_Heart)     // Deallocate stuff
}

delta_time: f64
total_time: f64
Zitrus_Heart :: struct {
    meta: struct {
        exe_path: string,
        previous_frame: time.Time
    },

    renderer: Renderer,
    asset_manager: Asset_Manager,
    input_data: Input_Data,

    camera: struct {
        position: Vec3,
        direction: Vec3,
        cameraRight: Vec3,
        cameraUp: Vec3,

        fov: f32
    },

    level_data: struct {
        should_quit: bool,
        current_level: u32,
        levels: []Level,
    },

    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid]Sparse_Set,

    next_bit_mask: int,
    component_bit: map[typeid]int,

    entity_masks: Component_Mask_Sparse_Set,
    entity_groups: map[Component_Mask]Entity_ID_Sparse_Set,
}

// This takes ownership of the "levels" slice. It should be allocated on heap
init_heart :: proc(z: ^Zitrus_Heart, levels: []Level, action_map: map[int]Input_Key) {
    z.next_id = 0
    z.next_bit_mask = 0
    z.entity_masks = new_sparse_set(Component_Mask)

    exe_path, err := os.get_executable_directory(context.allocator)

    if err != os.ERROR_NONE {
        fmt.printfln("ERROR: Cannot load executable's path: %s", err)
        os.exit(-1)
    }

    z.meta.exe_path = exe_path

    if !init_renderer(&z.renderer, z.meta.exe_path) {
        fmt.printfln("ERROR: Cannot init renderer - exiting...")
        os.exit(-1)
    }

    position: Vec3 = {0, 0, 3.0}
    target: Vec3 = {0, 0, 0}
    direction: Vec3 = (target - position)
    right: Vec3 = la.normalize(la.cross(Vec3 {0, 1, 0}, direction))
    up: Vec3 = la.cross(direction, right)

    z.camera = {
        position = position,
        direction = direction,
        cameraRight = right,
        cameraUp = up,
        fov = 45.0,
    }

    init_asset_manager(z, z.meta.exe_path)
    configurate_input(z, action_map)

    // TODO: Can cause potential problems in the future in the first frame of the game
    z.meta.previous_frame = time.now()

    // Init first level
    z.level_data.levels = levels
    z.level_data.levels[0].start(z)
}

update_heart :: proc(z: ^Zitrus_Heart) -> bool {
    // Update internal data
    now := time.now()
    diff := time.diff(z.meta.previous_frame, now)
    delta_time = time.duration_seconds(diff)
    total_time += delta_time
    z.meta.previous_frame = now

    // Check for events
    event: sdl.Event
    for sdl.PollEvent(&event){
        if event.type == .QUIT {
            z.level_data.should_quit = true
        }
        update_input_event(z, event)
        process_input_event(z, event)
    }
    update_if_held(z)
    process_input(z)

    lvl := &z.level_data
    lvl.levels[lvl.current_level].update(z)

    // Render and free memory
    render(z)
    free_all(context.temp_allocator)

    if z.level_data.should_quit {
        lvl.levels[lvl.current_level].end(z)
        asset_manager_unload_textures(z)
    }

    return z.level_data.should_quit
}

process_input_event :: proc(z: ^Zitrus_Heart, event: sdl.Event) {
    if event.type == .KEY_DOWN {
        if event.key.key == sdl.K_W {
            change_level(z, 1)
        }
    }
}

process_input :: proc(z: ^Zitrus_Heart) {
    
}

// This function also clears current image assets (deallocates them)
// and clears current entities
// it will not however clear other data allocated during "start"
Level_ID :: u32
change_level :: proc(z: ^Zitrus_Heart, next_level: Level_ID) -> bool {
    lvl := &z.level_data

    if next_level > u32(len(lvl.levels)) {
        fmt.printfln("ERROR: Cannot change level. ID passed: %v", next_level)
        return false
    }

    fmt.printfln("INFO: Changing level. ID passed: %v", next_level)

    lvl.levels[lvl.current_level].end(z)
    asset_manager_unload_textures(z)
    clear_ecs(z)

    lvl.current_level = next_level
    lvl.levels[lvl.current_level].start(z)

    return true
}

clear_ecs :: proc(z: ^Zitrus_Heart) {
    z.entity_masks.clear(&z.entity_masks)

    defer clear(&z.entity_groups)
    for s, &v in z.entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in z.component_pools {
        v.destroy_set(&v)
    }

    clear(&z.component_bit)
    clear(&z.component_pools)
}

destroy_heart :: proc(z: ^Zitrus_Heart) {
    z.entity_masks.destroy_set(&z.entity_masks)

    defer delete(z.entity_groups)
    for s, &v in z.entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in z.component_pools {
        v.destroy_set(&v)
    }

    destroy_input(z)

    delete(z.component_bit)
    delete(z.component_pools)
    delete(z.meta.exe_path)

    delete_map(z.asset_manager.image_assets)
    delete(z.level_data.levels)

    destroy_renderer(&z.renderer)
}

Entity_Heart :: struct {
    position: Vec3,
    rotation: quaternion128,
}

Entity_Alive :: struct {}
Entity_Dying :: struct {}

create_entity :: proc(z: ^Zitrus_Heart) -> (index: Entity_ID) {
    index = z.next_id
    z.next_id += 1;
    z.entity_masks.set(&z.entity_masks, index, &Component_Mask {0})

    set_component(z, index, Entity_Heart{})
    set_component(z, index, Entity_Alive{})
    return
}

destroy_entity :: proc(z: ^Zitrus_Heart, id: Entity_ID) -> bool {
    if !has_component(z, id, typeid_of(Entity_Alive)) {
        return false
    }
    
    append(&z.free_entities, id)

    for k, &set in z.component_pools {
        set.destroy_set(&set)
    }

    return true
}

register_component :: proc(z: ^Zitrus_Heart, component: $T) {
    z.component_pools[T] = new_sparse_set(T)
    z.component_bit[T] = z.next_bit_mask
    z.next_bit_mask += 1
}

get_component :: proc(z: ^Zitrus_Heart, id: Entity_ID, $T: typeid) -> (^T, bool) {
    if p, ok := z.component_pools[T]; !ok {
        return nil, false
    }
    set := &z.component_pools[T]
    component_ref: Component_Pointer = set.get(set, id)
    return (^T)(component_ref), true
}

set_component :: proc(z: ^Zitrus_Heart, id: Entity_ID, component: $T) -> ^T {
    if p, ok := z.component_pools[T]; !ok {
        register_component(z, component)
    }
    set := &z.component_pools[T]
    add_to_bitset(z, id, T)
    // FIX: find better alternative than copying component
    copy := component

    component_ref: Component_Pointer = set.set(set, id, &copy)
    return (^T)(component_ref)
}

has_component :: proc(z: ^Zitrus_Heart, id: Entity_ID, T: typeid) -> bool {
    entity_mask := (^Component_Mask)(z.entity_masks.get(&z.entity_masks, id))
    if entity_mask == nil {
        return false
    }

    c_bit, ok := z.component_bit[T]
    if !ok {
        return false
    }
    
    return (c_bit in entity_mask^)
}

add_to_bitset :: proc(z: ^Zitrus_Heart, id: Entity_ID, component_type: typeid) -> bool {
    // Get entity's bit set and remove entity from current group
    bitset_ptr := (^Component_Mask)(z.entity_masks.get(&z.entity_masks, id))
    if bitset_ptr == nil {
        return false
    }
    bitset := bitset_ptr^

    group, ok := &z.entity_groups[bitset]
    if ok {
        group.delete(group, id)
        if group.number_of_items == 0 {
            group.destroy_set(group)
            delete_key(&z.entity_groups, bitset)
        }
    }

    bit := z.component_bit[component_type]
    bitset += {bit}
    
    group, ok = &z.entity_groups[bitset]
    if !ok {
        z.entity_groups[bitset] = new_sparse_set(Entity_ID)
        group = &z.entity_groups[bitset]
    }

    id_copy := id
    group.set(group, id, &id_copy)
    z.entity_masks.set(&z.entity_masks, id, &bitset)

    return true
}
// TODO: find an alternative to long entity_id array
View :: struct {
    entities: [dynamic]Entity_ID
}

view :: proc(z: ^Zitrus_Heart, component_types: ..typeid) -> (view: View) {
    target_mask := Component_Mask {}
    for t in component_types {
        target_mask += {z.component_bit[t]}
    }
    
    matches := [dynamic]Entity_ID_Sparse_Set {}
    defer delete(matches)
    for group_mask, entities_set in z.entity_groups {
        if (group_mask & target_mask) == target_mask {
            append(&matches, entities_set)
        }
    }

    for m in matches {
        data: ^Sparse_Set_Data(Entity_ID) = (^Sparse_Set_Data(Entity_ID))(m.data)
        append(&view.entities, ..data.dense[:])
    }

    return
}

destroy_view :: proc(view: ^View) {
    delete(view.entities)
}