package zitrus

import "core:fmt"
import "core:os"
import "core:time"
import la "core:math/linalg"

import sdl "vendor:sdl3"

// https://github.com/chrischristakis/seecs/blob/master/seecs.h
// https://www.youtube.com/watch?v=yyZMoE1FAJ0
// Very helpful

// === GLOBAL VALUES ===

delta_time: f64
total_time: f64
heart: Zitrus_Heart

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
    start: proc(),  // Initialize level
    update: proc(), // Update logic
    end: proc()     // Deallocate stuff
}

Zitrus_Heart :: struct {
    meta: struct {
        exe_path: string,
        previous_frame: time.Time
    },

    renderer: Renderer,
    graphics: Graphics,
    asset_manager: Asset_Manager,
    input_data: Input_Data,

    camera: Zitrus_Camera,

    level_data: struct {
        should_quit: bool,
        current_level: u32,
        levels: []Level,
    },

    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid]Sparse_Set,

    next_bit_mask: int,
    component_to_bit: map[typeid]int,
    bit_to_component: map[int]typeid,

    entity_masks: Component_Mask_Sparse_Set,
    entity_groups: map[Component_Mask]Entity_ID_Sparse_Set,
}

// This takes ownership of the "levels" slice. It should be allocated on heap
init_heart :: proc(size: Vec2Int, levels: []Level, action_map: map[int]Input_Key, callback_groups_number: int) {
    heart.next_id = 0
    heart.next_bit_mask = 0
    heart.entity_masks = new_sparse_set(Component_Mask)

    // heart.component_pools = make(map[typeid]Sparse_Set)
    // heart.component_to_bit = make(map[typeid]int)
    // heart.bit_to_component = make(map[int]typeid)
    // heart.entity_groups = make(map[Component_Mask]Entity_ID_Sparse_Set)

    register_component(Entity_Alive)
    register_component(Entity_Dying)

    exe_path, err := os.get_executable_directory(context.allocator)

    if err != os.ERROR_NONE {
        fmt.printfln("ERROR: Cannot load executable's path: %s", err)
        os.exit(-1)
    }

    heart.meta.exe_path = exe_path

    if !init_renderer(heart.meta.exe_path, size) {
        fmt.printfln("ERROR: Cannot init renderer - exiting...")
        os.exit(-1)
    }

    position: Vec3 = {0, 0, 1}
    target: Vec3 = {0, 0, 0}
    direction: Vec3 = (target - position)
    right: Vec3 = la.normalize(la.cross(Vec3 {0, 1, 0}, direction))
    up: Vec3 = la.cross(direction, right)

    heart.camera = {
        position = position,
        direction = direction,
        cameraRight = right,
        cameraUp = up,
        fov = 45.0,
    }

    init_asset_manager(heart.meta.exe_path)
    configurate_input(action_map, callback_groups_number)

    // TODO: Can cause potential problems in the future in the first frame of the game
    heart.meta.previous_frame = time.now()

    // Init first level
    heart.level_data.levels = levels
    heart.level_data.levels[0].start()
}

get_heart :: #force_inline proc() -> ^Zitrus_Heart {
    return &heart
}

update_heart :: proc() -> bool {
    // Update internal data
    now := time.now()
    diff := time.diff(heart.meta.previous_frame, now)
    delta_time = time.duration_seconds(diff)
    total_time += delta_time
    heart.meta.previous_frame = now

    // Check for events
    event: sdl.Event
    for sdl.PollEvent(&event){
        if event.type == .QUIT {
            heart.level_data.should_quit = true
        }
        update_input_event(event)
    }
    update_if_held()

    lvl := &heart.level_data
    lvl.levels[lvl.current_level].update()

    // Render and free memory
    render()
    free_all(context.temp_allocator)

    // Delete dying entities
    v := view(Entity_Dying)
    defer destroy_view(&v)

    for e in v.entities {
        h, _ := get_component(e, Entity_Heart)
        if h.on_delete != nil do h.on_delete(e)

        append(&heart.free_entities, e)

        mask := (^Component_Mask)(heart.entity_masks.get(&heart.entity_masks, e))^
        
        for bit in mask {
            component_type: typeid = heart.bit_to_component[bit]
            remove_component(e, component_type)
        }
    }

    if heart.level_data.should_quit {
        lvl.levels[lvl.current_level].end()
        asset_manager_unload_textures(true)
    }

    return heart.level_data.should_quit
}

destroy_heart :: proc() {
    heart.entity_masks.destroy_set(&heart.entity_masks)

    defer delete(heart.entity_groups)
    for _, &v in heart.entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in heart.component_pools {
        v.destroy_set(&v)
    }

    destroy_input()
    destroy_graphics()
    destroy_asset_manager()

    delete(heart.free_entities)
    delete(heart.component_to_bit)
    delete(heart.bit_to_component)
    delete(heart.component_pools)
    
    delete(heart.meta.exe_path)
    delete(heart.level_data.levels)

    destroy_renderer(&heart.renderer)
}

// This function also clears current image assets (deallocates them)
// and clears current entities
// it will not however clear other data allocated during "start"
Level_ID :: u32
change_level :: proc(next_level: Level_ID) -> bool {
    lvl := &heart.level_data

    if next_level > u32(len(lvl.levels)) {
        fmt.printfln("ERROR: Cannot change level. ID passed: %v", next_level)
        return false
    }

    fmt.printfln("INFO: Changing level. ID passed: %v", next_level)

    lvl.levels[lvl.current_level].end()
    asset_manager_unload_textures(false)

    clear_ecs()
    delete_all_meshes()

    lvl.current_level = next_level
    lvl.levels[lvl.current_level].start()

    return true
}

clear_ecs :: proc() {
    heart.entity_masks.clear(&heart.entity_masks)

    defer clear(&heart.entity_groups)
    for s, &v in heart.entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in heart.component_pools {
        v.destroy_set(&v)
    }

    clear(&heart.component_to_bit)
    clear(&heart.component_pools)

    delete_all_meshes()
}

Entity_On_Delete :: proc(Entity_ID)
Entity_Heart :: struct {
    position: Vec3,
    scale: Vec3,
    rotation: quaternion128,

    on_delete: Entity_On_Delete,
}

Entity_Alive :: struct {}
Entity_Dying :: struct {}

create_entity :: proc(on_delete_callback: Entity_On_Delete = nil) -> (index: Entity_ID) {
    index = heart.next_id
    heart.next_id += 1;
    heart.entity_masks.set(&heart.entity_masks, index, &Component_Mask {})

    set_component(index, Entity_Heart{
        position = {0,0,0},
        scale = {1,1,1},
        rotation = 1,

        on_delete = on_delete_callback
    })
    set_component(index, Entity_Alive{})
    return
}

set_on_delete :: proc(id: Entity_ID, on_delete_callback: Entity_On_Delete) {
    h, _ := get_component(id, Entity_Heart)
    h.on_delete = on_delete_callback
}

destroy_entity :: proc(id: Entity_ID) -> bool {
    if has_component(id, typeid_of(Entity_Dying)) {
        fmt.printfln("Warning: Tried to delete entity twice")
        return false
    }

    h, _ := get_component(id, Entity_Heart)

    remove_component(id, Entity_Alive)
    set_component(id, Entity_Dying {})
    
    return true
}

register_component :: proc($T: typeid) {
    heart.component_pools[T] = new_sparse_set(T)
    heart.component_to_bit[T] = heart.next_bit_mask
    heart.bit_to_component[heart.next_bit_mask] = T
    heart.next_bit_mask += 1
}

get_component :: proc(id: Entity_ID, $T: typeid) -> (^T, bool) {
    if p, ok := heart.component_pools[T]; !ok {
        return nil, false
    }
    set := &heart.component_pools[T]
    component_ref: Item_Pointer = set.get(set, id)
    return (^T)(component_ref), true
}

set_component :: proc(id: Entity_ID, component: $T) -> ^T {
    if p, ok := heart.component_pools[T]; !ok {
        register_component(T)
    }
    set := &heart.component_pools[T]
    set_bitset(id, T, true)
    // FIX: find better alternative than copying component
    copy := component

    component_ref: Item_Pointer = set.set(set, id, &copy)
    return (^T)(component_ref)
}

remove_component :: proc(id: Entity_ID, component: typeid) -> bool {
    // There is not even a pool for this component, so entity cannot have it
    if p, ok := heart.component_pools[component]; !ok {
        return false
    }
    
    set := &heart.component_pools[component]
    set_bitset(id, component, false)

    return set.delete(set, id)
}

has_component :: proc(id: Entity_ID, T: typeid) -> bool {
    entity_mask := (^Component_Mask)(heart.entity_masks.get(&heart.entity_masks, id))
    if entity_mask == nil {
        return false
    }

    c_bit, ok := heart.component_to_bit[T]
    if !ok {
        return false
    }
    
    return (c_bit in entity_mask^)
}

set_bitset :: proc(id: Entity_ID, component_type: typeid, has_it: bool) -> bool {
    // Get entity's bit set and remove entity from current group
    bitset_ptr := (^Component_Mask)(heart.entity_masks.get(&heart.entity_masks, id))
    if bitset_ptr == nil {
        return false
    }
    bitset := bitset_ptr^

    // Delete from current group
    group, ok := &heart.entity_groups[bitset]
    if ok {
        group.delete(group, id)
        if group.number_of_items == 0 {
            group.destroy_set(group)
            delete_key(&heart.entity_groups, bitset)
        }
    }

    // Get the right bit and update bitset
    bit := heart.component_to_bit[component_type]
    if has_it {
        bitset += {bit}
    } else {
        bitset -= {bit}
    }
    

    // Get entity group (and create it if not existing)
    group, ok = &heart.entity_groups[bitset]
    if !ok {
        heart.entity_groups[bitset] = new_sparse_set(Entity_ID)
        group = &heart.entity_groups[bitset]
    }

    // Move entity to new bitset
    id_copy := id
    group.set(group, id, &id_copy)
    heart.entity_masks.set(&heart.entity_masks, id, &bitset)

    return true
}

// TODO: find an alternative to long entity_id array
View :: struct {
    entities: [dynamic]Entity_ID
}

view :: proc(component_types: ..typeid) -> (view: View) {
    target_mask := Component_Mask {}
    for t in component_types {
        target_mask += {heart.component_to_bit[t]}
    }
    
    matches := [dynamic]Entity_ID_Sparse_Set {}
    defer delete(matches)
    for group_mask, entities_set in heart.entity_groups {
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