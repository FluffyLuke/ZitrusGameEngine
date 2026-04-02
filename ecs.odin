package zitrus

import "core:fmt"
import "core:os"
import "core:time"

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

delta_time: f64

Zitrus_Heart :: struct {
    meta: struct {
        exe_path: string,
        previous_frame: time.Time
    },

    renderer: Renderer,
    asset_manager: Asset_Manager,

    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid]Sparse_Set,

    next_bit_mask: int,
    component_bit: map[typeid]int,

    entity_masks: Component_Mask_Sparse_Set,
    entity_groups: map[Component_Mask]Entity_ID_Sparse_Set,
}

init_heart :: proc(z: ^Zitrus_Heart) {
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

    init_asset_manager(&z.asset_manager, z.meta.exe_path)

    // TODO: Can cause potential problems in the future in the first frame of the game
    z.meta.previous_frame = time.now()
}

update_heart :: proc(z: ^Zitrus_Heart) {
    now := time.now()
    diff := time.diff(z.meta.previous_frame, now)
    delta_time = time.duration_seconds(diff)
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

    delete(z.component_bit)
    delete(z.component_pools)
    delete(z.meta.exe_path)

    delete_map(z.asset_manager.image_assets)

    destroy_renderer(&z.renderer)
}

Entity_Heart :: struct {
    position: Vec3,
    rotation: quaternion128,
}

Entity_Alive :: struct {

}

Entity_Dying :: struct {

}

create_entity :: proc(z: ^Zitrus_Heart) -> (index: Entity_ID) {
    index = z.next_id
    z.next_id += 1;
    z.entity_masks.set(&z.entity_masks, index, &Component_Mask {0})

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