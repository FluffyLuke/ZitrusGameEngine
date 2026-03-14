package zitrus

import "core:fmt"

// https://github.com/chrischristakis/seecs/blob/master/seecs.h
// https://www.youtube.com/watch?v=yyZMoE1FAJ0
// Very helpful

Entity_ID :: Sparse_Index
TOMBSTONE :: max(Sparse_Index)

MAX_COMPONENTS :: 128
Component_Mask :: bit_set[0..<MAX_COMPONENTS]

Zitrus_Heart :: struct {
    next_id: Entity_ID,
    free_entities: [dynamic]Entity_ID,
    component_pools: map[typeid]any,

    next_bit_mask: int,
    component_bit: map[typeid]int,

    // FIX: Change these to sparse set in the future?
    entity_masks: Sparse_Set(Component_Mask),
    entity_groups: map[Component_Mask]Sparse_Set(Entity_ID)
}

init_heart :: proc(using heart: ^Zitrus_Heart) {
    next_id = 0
    next_bit_mask = 0
    component_pools = {}
    entity_groups = {}
}

destroy_heart :: proc(using heart: ^Zitrus_Heart) {
    delete(component_bit)
    delete(component_pools)
    destroy_sparse_set(&entity_masks)
    for k, &v in entity_groups {
        destroy_sparse_set(&v)
    }
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
    sparse_set_insert(&entity_masks, index, Component_Mask {0})

    set_component(heart, index, Entity_Alive{})
    return
}

destroy_entity :: proc(using heart: ^Zitrus_Heart, id: Entity_ID) -> bool {
    if !has_component(heart, id, typeid_of(Entity_Alive)) {
        return false
    }
    
    append(&free_entities, id)

    for k, v in component_pools {
        v.clean_up
        set := &component_pools[k].(Sparse_Set(k))
    }

    return true
}

register_component :: proc(using heart: ^Zitrus_Heart, component: $T) {
    component_pools[T] = Sparse_Set(T) {}
    component_bit[T] = next_bit_mask
    next_bit_mask += 1
}

set_component :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, component: $T) -> ^T {
    if p, ok := component_pools[T]; !ok {
        register_component(heart, component)
        component_pools[T] = new(Sparse_Set(T))^
    }
    set := &component_pools[T].(Sparse_Set(T))
    add_to_bitset(heart, id, T)
    return sparse_set_insert(set, id, component)
}

has_component :: proc(using heart: ^Zitrus_Heart, id: Entity_ID, T: typeid) -> bool {
    entity_mask := sparse_set_get(&entity_masks, id)
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
    bitset := sparse_set_get(&entity_masks, id)
    if bitset == nil {
        fmt.eprintfln("Cannot find bitset of type: \"%s\"", component_type)
        return false
    }
    group := &entity_groups[bitset^]
    sparse_set_delete(group, id)

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