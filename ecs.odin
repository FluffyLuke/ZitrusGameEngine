package zitrus

import "core:fmt"
import "core:os"
import "core:time"
import "base:runtime"

import rl "vendor:raylib"

// https://github.com/chrischristakis/seecs/blob/master/seecs.h
// https://www.youtube.com/watch?v=yyZMoE1FAJ0
// Very helpful

// === GLOBAL VALUES ===

delta_time: f64
total_time: f64
heart: Zitrus_Heart

MAX_COMPONENTS :: 128
Component_Mask :: bit_set[0..<MAX_COMPONENTS]
Component_Cleanup :: proc(entity: Entity_ID, component_ptr: rawptr)
Component_Cleanup_Default :: proc(entity: Entity_ID, component_ptr: rawptr) {}

Component_Mask_Sparse_Set :: Sparse_Set
Entity_ID_Sparse_Set :: Sparse_Set

ASSET_ROOT :: "/assets/"
SHADERS_ROOT :: "/shaders/"

Zitrus_Heart :: struct {
    meta: struct {
        exe_path: string,
        previous_frame: time.Time
    },

    renderer: Renderer,
    graphics: Graphics,
    // lights: Light_Data,

    asset_manager: Asset_Manager,
    input_data: Input_Data,

    level_data: Level_Data,
    cache: map[typeid]rawptr,
    
    // === Entities ===

    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid](Sparse_Set),

    next_bit_mask: int,
    component_to_bit: map[typeid]int,
    bit_to_component: map[int]typeid,

    entity_masks: Component_Mask_Sparse_Set,
    entity_groups: map[Component_Mask]Entity_ID_Sparse_Set,

    tags: Tag_Data,
}

// This takes ownership of the "levels" slice. It should be allocated on heap
init_heart :: proc(size: Vec2Int, levels: map[Level_ID]Level, first_level: Level_ID, action_map: map[int]Input_Key, callback_groups_number: int) {
    exe_path, err := os.get_executable_directory(context.allocator)
    if err != os.ERROR_NONE {
        fmt.printfln("[ERROR] Cannot load executable's path: %s", err)
        os.exit(-1)
    }
    heart.meta.exe_path = exe_path
    
    heart.next_id = 0
    heart.next_bit_mask = 0
    heart.entity_masks = new_sparse_set(Component_Mask, cleanup = Component_Cleanup_Default)

    // heart.component_pools = make(map[typeid]Sparse_Set)
    // heart.component_to_bit = make(map[typeid]int)
    // heart.bit_to_component = make(map[int]typeid)
    // heart.entity_groups = make(map[Component_Mask]Entity_ID_Sparse_Set)

    register_component(Entity_Alive, auto_cast Component_Cleanup_Default)
    register_component(Entity_Dying, auto_cast Component_Cleanup_Default)

    init_renderer(size)
    init_tags()
    init_camera()
    init_asset_manager(heart.meta.exe_path)
    configurate_input(action_map, callback_groups_number)

    heart.cache = make(map[typeid]rawptr)

    // TODO: Can cause potential problems in the future in the first frame of the game
    heart.meta.previous_frame = time.now()

    // Init first level
    init_levels(levels, first_level)
}

update_heart :: proc() -> bool {
    // Update time
    {
        now := time.now()
        diff := time.diff(heart.meta.previous_frame, now)
        delta_time = time.duration_seconds(diff)
        total_time += delta_time
        heart.meta.previous_frame = now
    }

    // Update input and game
    update_input()
    lvl := &heart.level_data
    current_level := &lvl.levels[lvl.current_level]
    current_level.update(current_level, delta_time)

    // Render and free memory
    render()
    free_all(context.temp_allocator)

    // Delete dying entities
    {
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
    }

    heart.level_data.should_quit = rl.WindowShouldClose()
    if heart.level_data.should_quit {
        current_level.end(current_level)
        asset_manager_unload_textures(true)
    }

    return heart.level_data.should_quit
}

destroy_heart :: proc() {
    // TODO: make this in dev build only
    // TODO: this can slow down the exit process, but will avoid all memory sanatizer errors
    // TODO: when entity has resources to delete

    // Destroy ECS
    {
        view := view(Entity_Heart)
        defer destroy_view(&view)
        for e in view.entities {
            h := get_entity_heart(e)
            if h.on_delete != nil {
                h.on_delete(e)
            } 
        }

        heart.entity_masks.destroy_set(&heart.entity_masks)

        defer delete(heart.entity_groups)
        for _, &v in heart.entity_groups {
            v.destroy_set(&v)
        }

        for _, &v in heart.component_pools {
            v.destroy_set(&v)
        }

        delete(heart.free_entities)
        delete(heart.component_to_bit)
        delete(heart.bit_to_component)
        delete(heart.component_pools)
        
        delete(heart.meta.exe_path)
    }

    destroy_tags()

    // Destroy cache
    {
        for k, v in heart.cache {
            free(v)
        }
        delete_map(heart.cache)
    }

    // Free rest of the resources
    destroy_levels()
    destroy_input()
    destroy_graphics()
    destroy_asset_manager()
    destroy_renderer()
}

get_heart :: #force_inline proc() -> ^Zitrus_Heart {
    return &heart
}

start_game_loop :: proc() {
    load_new_level(&heart.level_data.levels[heart.level_data.current_level])
    for !update_heart() {}
}

cache_add :: proc(item: $T) {
    heart.cache[T] = new_clone(item)
}

cache_get :: proc($T: typeid) -> (^T, bool) {
    item_raw, ok := heart.cache[T]
    return (^T)(item_raw), ok
}

cache_remove :: proc(item: $T) -> bool {
    item, ok := heart.cache[T]
    if !ok do return false
    free(item)
    delete_key(&heart.cache, T)
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

    destroy_all_meshes()
}

set_component_cleanup :: proc($T: typeid, cleanup_func: proc(id: Entity_ID, comp: ^T)) {
    if p, ok := heart.component_pools[T]; !ok {
        register_component(T)
    }
    set := &heart.component_pools[T]
    set.cleanup = cleanup
}

register_component :: proc($T: typeid, cleanup_func: proc(id: Entity_ID, comp: ^T)) {
    final_cleanup: Component_Cleanup = Component_Cleanup_Default

    if cleanup_func != nil {
        final_cleanup = transmute(Component_Cleanup)cleanup_func
    }

    heart.component_pools[T] = new_sparse_set(T, cleanup = final_cleanup)
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
        register_component(T, auto_cast Component_Cleanup_Default)
    }
    set := &heart.component_pools[T]
    set_bitset(id, T, true)
    // FIXME: find better alternative than copying component
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
        heart.entity_groups[bitset] = new_sparse_set(Entity_ID, cleanup = Component_Cleanup_Default)
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

view :: proc {
    view_components,
    view_tags_indexes,
    view_tags_strings,
}

view_components :: proc(component_types: ..typeid) -> (view: View) {
    target_mask := Component_Mask {}
    for t in component_types {
        mask, ok := heart.component_to_bit[t]
        if ok do target_mask += {mask}
    }
    if target_mask == {} do return
    
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