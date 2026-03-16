package zitrus

import "core:fmt"
import "core:mem"

// https://github.com/chrischristakis/seecs/blob/master/seecs.h
// https://www.youtube.com/watch?v=yyZMoE1FAJ0
// Very helpful

Entity_ID :: Sparse_Index
TOMBSTONE :: max(Sparse_Index)

MAX_COMPONENTS :: 128
Component_Mask :: bit_set[0..<MAX_COMPONENTS]

Component_Mask_Sparse_Set :: Sparse_Set
Entity_ID_Sparse_Set :: Sparse_Set

Zitrus_Heart :: struct {
    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid]Sparse_Set,

    next_bit_mask: int,
    component_bit: map[typeid]int,

    entity_masks: Component_Mask_Sparse_Set,
    entity_groups: map[Component_Mask]Entity_ID_Sparse_Set,
}

init_heart :: proc(using heart: ^Zitrus_Heart) {
    next_id = 0
    next_bit_mask = 0
    entity_masks = new_sparse_set(Component_Mask)

    // Use make to allocate the hash table header
    // component_pools = make(map[typeid]Sparse_Set)
    // entity_groups = make(map[Component_Mask]Sparse_Set)
    
    // component_bit can also be initialized here
    // component_bit = make(map[typeid]int)
}

destroy_heart :: proc(using heart: ^Zitrus_Heart) {
    entity_masks.destroy_set(&entity_masks)

    defer delete(entity_groups)
    for s, &v in entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in component_pools {
        v.destroy_set(&v)
    }

    delete(component_bit)
    delete(component_pools)
}

Entity_Heart :: struct {
    position: Vector3,
    rotation: quaternion128,
}

Entity_Alive :: struct {

}

Entity_Dying :: struct {

}

create_entity :: proc(using heart: ^Zitrus_Heart) -> (index: Entity_ID) {
    index = next_id
    heart.next_id += 1;
    entity_masks.set(&entity_masks, index, &Component_Mask {0})

    set_component(heart, index, Entity_Alive{})
    return
}

destroy_entity :: proc(using heart: ^Zitrus_Heart, id: Entity_ID) -> bool {
    if !has_component(heart, id, typeid_of(Entity_Alive)) {
        return false
    }
    
    append(&free_entities, id)

    for k, &set in component_pools {
        set.destroy_set(&set)
    }

    return true
}

register_component :: proc(using heart: ^Zitrus_Heart, component: $T) {
    component_pools[T] = new_sparse_set(T)
    component_bit[T] = next_bit_mask
    next_bit_mask += 1
}

get_component :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, $T: typeid) -> (^T, bool) {
    if p, ok := component_pools[T]; !ok {
        return nil, false
    }
    set := &component_pools[T]
    component_ref: Component_Pointer = set.get(set, id)
    return (^T)(component_ref), true
}

set_component :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, component: $T) -> ^T {
    if p, ok := component_pools[T]; !ok {
        register_component(heart, component)
    }
    set := &component_pools[T]
    add_to_bitset(heart, id, T)
    // FIX: find better alternative than copying component
    copy := component

    component_ref: Component_Pointer = set.set(set, id, &copy)
    return (^T)(component_ref)
}

has_component :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, T: typeid) -> bool {
    entity_mask := (^Component_Mask)(entity_masks.get(&entity_masks, id))
    if entity_mask == nil {
        return false
    }

    c_bit, ok := component_bit[T]
    if !ok {
        return false
    }
    
    return (c_bit in entity_mask^)
}

add_to_bitset :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, component_type: typeid) -> bool {
    // Get entity's bit set and remove entity from current group
    bitset_ptr := (^Component_Mask)(entity_masks.get(&entity_masks, id))
    if bitset_ptr == nil {
        return false
    }
    bitset := bitset_ptr^

    group, ok := &entity_groups[bitset]
    if ok {
        group.delete(group, id)
        if group.number_of_items == 0 {
            group.destroy_set(group)
            delete_key(&entity_groups, bitset)
        }
    }

    bit := component_bit[component_type]
    bitset += {bit}
    
    group, ok = &entity_groups[bitset]
    if !ok {
        entity_groups[bitset] = new_sparse_set(Entity_ID)
        group = &entity_groups[bitset]
    }

    id_copy := id
    group.set(group, id, &id_copy)
    entity_masks.set(&entity_masks, id, &bitset)

    return true
}
// TODO: find an alternative to long entity_id array
View :: struct {
    entities: [dynamic]Entity_ID
}

view :: proc(using heart: ^Zitrus_Heart, component_types: ..typeid) -> (view: View) {
    target_mask := Component_Mask {}
    for t in component_types {
        target_mask += {component_bit[t]}
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