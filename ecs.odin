package zitrus

import "core:fmt"

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

    component_pools = {}
    entity_groups = {}
}

destroy_heart :: proc(using heart: ^Zitrus_Heart) {
    entity_masks.destroy_set(&entity_masks)

    for _, &v in entity_groups {
        v.destroy_set(&v)
    }

    for _, &v in component_pools {
        v.destroy_set(&v)
    }

    delete(component_bit)
    delete(component_pools)
}

Entity_Heart :: struct {
    pos: Vector3,
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
    bitset := (^Component_Mask)(entity_masks.get(&entity_masks, id))
    if bitset == nil {
        fmt.eprintfln("Cannot find bitset of type: \"%s\"", component_type)
        return false
    }

    group, ok := &entity_groups[bitset^]
    if ok {
        group.delete(&group, id)
    }

    bit := component_bit[component_type]

    return true
}

query :: proc(using heart: Zitrus_Heart, e: Entity_ID, $T: typeid) -> ^T {
    if p, ok = component_pools[T]; ok {
        component_pools[T] = make(map[typeid]any) 
    }
}

Transform_Component :: struct {
    position: Vector3,
    rotation: quaternion128,
}

// Query :: struct {
//     ids: [4096]Entity
//     components: []
// }