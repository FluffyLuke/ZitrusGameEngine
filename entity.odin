package zitrus

import "core:fmt"
import "core:slice"
import str "core:strings"
import la "core:math/linalg"

Entity_ID :: Sparse_Index
TOMBSTONE :: max(Sparse_Index)

default_entity_name :: proc() -> string {
    return str.clone("Lemon")
}

Entity_On_Delete :: proc(Entity_ID)
Entity_Heart :: struct {
    name: string,
    parent: Entity_ID,
    children: [dynamic]Entity_ID,

    local_position, global_position: Vec3,
    local_scale, global_scale: Vec3,
    local_rotation, global_rotation: quaternion128,

    on_delete: Entity_On_Delete,
}

// TODO: Convert these structs to tags
Entity_Alive :: struct {}
Entity_Dying :: struct {}
Entity_NoParent :: struct {}

init_entities :: proc() {
    register_component(Entity_Heart, proc(id: Entity_ID, heart: ^Entity_Heart) {
        destroy_entity_heart(id, heart)
    })
}

// The bigger the depth, the further away it will be from the screen
// Depth range = <0 ; RENDERING_DEPTH)
create_entity :: proc(
    name: string,
    local_pos: Vec3 = {0,0,0},
    local_scale: Vec3 = {1,1,1},
    local_rotation: quaternion128 = quaternion128(1+0i+0j+0k),
    tags: []string = nil,
    parent: Entity_ID = TOMBSTONE,
    on_delete: Entity_On_Delete = nil
) -> (index: Entity_ID) {
    index = heart.next_id
    heart.next_id += 1;
    heart.entity_masks.set(&heart.entity_masks, index, &Component_Mask {})

    entity_heart := set_component(index, Entity_Heart{
        name = name,
        parent = TOMBSTONE,
        on_delete = on_delete
        // Set rotation, scale and position down below by dedicated functions
    })

    if parent != TOMBSTONE {
        set_parent(parent, index)
    }

    set_position_local(index, local_pos)
    set_scale_local(index, local_scale)
    set_rotation_local(index, local_rotation)

    set_component(index, Entity_Alive{})

    for t in tags {
        set_tag(index, t)
    }

    return
}

// Deletion of entity heart should only happen, when the whole entity is being destroyed.
// This is because entity cannot work properly without this component.
@(private="file")
destroy_entity_heart :: proc(e: Entity_ID, entity_heart: ^Entity_Heart) {
    delete_string(entity_heart.name)

    // Remove parent from dying entity
    set_parent(TOMBSTONE, e)
    for c in entity_heart.children {
        set_parent(TOMBSTONE, c)
    }

    delete(entity_heart.children)
}

// This function is used to MARK the entity for deletion
// ECS will later call proper cleanup function
destroy_entity :: proc(id: Entity_ID) -> bool {
    if has_component(id, typeid_of(Entity_Dying)) {
        fmt.printfln("[WARNING] Tried to delete entity twice")
        return false
    }

    entity_heart := get_entity_heart(id)

    remove_component(id, Entity_Alive)
    set_component(id, Entity_Dying {})

    for c in entity_heart.children {
        destroy_entity(c)
    }
    
    return true
}

@(private="package")
clear_entities :: proc() {
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
entity_exists :: proc(id: Entity_ID) -> bool {
    if c, exists := get_component(id, Entity_Heart); !exists {
        return false
    }

    if is_dying := has_component(id, Entity_Dying); is_dying {
        return false
    }

    return true
}

get_entity_heart :: #force_inline proc(entity: Entity_ID) -> ^Entity_Heart {
    heart, _ := get_component(entity, Entity_Heart)
    return heart
}

set_on_delete :: proc(id: Entity_ID, on_delete: Entity_On_Delete) {
    h, _ := get_component(id, Entity_Heart)
    h.on_delete = on_delete
}

get_parent :: proc(id: Entity_ID) -> Entity_ID {
    return get_entity_heart(id).parent
}

set_parent :: proc(parent: Entity_ID, child: Entity_ID) -> bool {
    if !entity_exists(child) {
        fmt.println("[WARNING] Cannot assign child entity of id '%v', as it does not exist.", child)
        return false
    }

    child_heart := get_entity_heart(child)

    if child_heart.parent == parent && parent != TOMBSTONE {
        old_parent_heart := get_entity_heart(child_heart.parent)
        fmt.println("[WARNING] Child '%v' already has the parent '%v.'", child_heart.name, old_parent_heart.name)
    }

    // Remove child from its current parent
    if child_heart.parent != TOMBSTONE {
        old_parent_heart := get_entity_heart(child_heart.parent)
        index, found := slice.linear_search(old_parent_heart.children[:], child)
        if found {
            unordered_remove(&old_parent_heart.children, index)
        } else {
            fmt.printfln("[ERROR] Could not find child '%v' to remove from parent '%v'?", child_heart.name, old_parent_heart.name)
            return false
        }
    }

    // Check if parent is nil (this means entity does not have a parent)
    if parent == TOMBSTONE {
        child_heart.parent = TOMBSTONE
        return true
    }

    new_parent_heart := get_entity_heart(parent)
    append(&new_parent_heart.children, child)
    child_heart.parent = parent

    // Recalculate transform
    update_transform_recursive(child)

    return true
}

get_position_local :: proc(entity: Entity_ID) -> Vec3 {
    heart := get_entity_heart(entity)
    return heart.local_position
}

get_position_global :: proc(entity: Entity_ID) -> Vec3 {
    heart := get_entity_heart(entity)
    return heart.global_position
}

set_position_local :: proc(entity: Entity_ID, new_local_position: Vec3) {
    heart := get_entity_heart(entity)

    // Gets global position without the local offset
    global_parent_pos: Vec3 = {0,0,0}
    global_parent_scale: Vec3 = {1,1,1}
    global_parent_rot := quaternion128(1+0i+0j+0k) // Identity quaternion (No rotation)
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_pos = get_position_global(parent)
        global_parent_scale = get_scale_global(parent)
        global_parent_rot = get_rotation_global(parent)
    }

    heart.local_position = new_local_position // Set new local position
    
    scaled_offset := new_local_position * global_parent_scale // 1) Scale the local offset
    rotated_offset := la.mul(global_parent_rot, scaled_offset) // 2) Rotate the offset around the parent
    heart.global_position = global_parent_pos + rotated_offset // 3) Apply to parent position

    for c in heart.children {
        // Update each child. 
        // Pass simply the same local position as before, but this time parent was updated.
        update_transform_recursive(c)
    }
}

update_position_local :: proc(entity: Entity_ID, update_pos: Vec3) -> Vec3 {
    heart := get_entity_heart(entity)
    current_pos := heart.local_position
    set_position_local(entity, current_pos + update_pos)
    return heart.local_position
}

set_position_global :: proc(entity: Entity_ID, new_global_position: Vec3) {
    heart := get_entity_heart(entity)

    // Gets global position without the local offset
    global_parent_pos: Vec3 = {0,0,0}
    global_parent_scale: Vec3 = {1,1,1}
    global_parent_rot := quaternion128(1+0i+0j+0k) // Identity quaternion (No rotation)
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_pos = get_position_global(parent)
        global_parent_scale = get_scale_global(parent)
        global_parent_rot = get_rotation_global(parent)
    }
    
    // 1) Find the distance from the parent
    global_offset := new_global_position - global_parent_pos

    // 2) Un-rotate the offset
    inverse_rot := conj(global_parent_rot)
    unrotated_offset := la.mul(inverse_rot, global_offset)

    // 3) Un-scale the offset
    heart.local_position = unrotated_offset / global_parent_scale
    heart.global_position = new_global_position

    for c in heart.children {
        // Update each child. 
        // Pass simply the same local position as before, but this time parent was updated.
        update_transform_recursive(c)
    }
}

get_scale_local :: proc(entity: Entity_ID) -> Vec3 {
    return get_entity_heart(entity).local_scale
}

get_scale_global :: proc(entity: Entity_ID) -> Vec3 {
    return get_entity_heart(entity).global_scale
}

set_scale_local :: proc(entity: Entity_ID, new_local_scale: Vec3) {
    heart := get_entity_heart(entity)
    
    global_parent_scale := Vec3 {1,1,1}
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_scale = get_scale_global(parent)

        if global_parent_scale.x == 0 do global_parent_scale.x = 0.00001
        if global_parent_scale.y == 0 do global_parent_scale.y = 0.00001
        if global_parent_scale.z == 0 do global_parent_scale.z = 0.00001
    }

    heart.local_scale = new_local_scale
    heart.global_scale = global_parent_scale * new_local_scale

    for c in heart.children {
        update_transform_recursive(c)
    }
}

set_scale_global :: proc(entity: Entity_ID, new_global_scale: Vec3) {
    heart := get_entity_heart(entity)
    
    global_parent_scale := Vec3 {1,1,1}
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_scale = get_scale_global(parent)

        if global_parent_scale.x == 0 do global_parent_scale.x = 0.00001
        if global_parent_scale.y == 0 do global_parent_scale.y = 0.00001
        if global_parent_scale.z == 0 do global_parent_scale.z = 0.00001
    }

    heart.global_scale = new_global_scale
    heart.local_scale = new_global_scale / global_parent_scale

    for c in heart.children {
        update_transform_recursive(c)
    }
}

get_rotation_local :: proc(entity: Entity_ID) -> quaternion128 {
    return get_entity_heart(entity).local_rotation
}

get_rotation_global :: proc(entity: Entity_ID) -> quaternion128 {
    return get_entity_heart(entity).global_rotation
}

set_rotation_local :: proc(entity: Entity_ID, new_local_rotation: quaternion128) {
    heart := get_entity_heart(entity)
    
    global_parent_rotation := quaternion128(1+0i+0j+0k)
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_rotation = get_rotation_global(parent)
    }

    heart.local_rotation = new_local_rotation
    heart.global_rotation = global_parent_rotation * new_local_rotation

    for c in heart.children {
        update_transform_recursive(c)
    }
}

set_rotation_global :: proc(entity: Entity_ID, new_global_rotation: quaternion128) {
    heart := get_entity_heart(entity)
    
    global_parent_rotation := quaternion128(1+0i+0j+0k)
    if parent := get_parent(entity); parent != TOMBSTONE {
        global_parent_rotation = get_rotation_global(parent)
    }

    heart.global_rotation = new_global_rotation
    // Cannot divide for some reason - inverse global parent rotation
    heart.local_rotation = conj(global_parent_rotation) * new_global_rotation

    for c in heart.children {
        update_transform_recursive(c)
    }
}

update_rotation_local :: proc(entity: Entity_ID, new_local_rotation: quaternion128) {
    heart := get_entity_heart(entity)

    set_rotation_local(entity, heart.local_rotation * new_local_rotation)
}

update_rotation_global :: proc(entity: Entity_ID, new_global_rotation: quaternion128) {
    heart := get_entity_heart(entity)

    set_rotation_local(entity, heart.global_rotation * new_global_rotation)
}

@(private="file")
update_transform_recursive :: proc(entity: Entity_ID) {
    heart := get_entity_heart(entity)
    
    parent := get_parent(entity)
    parent_pos := get_position_global(parent)
    parent_scale := get_scale_global(parent)
    parent_rot := get_rotation_global(parent)
    
    // Update global position based on parent
    scaled_offset := heart.local_position * parent_scale
    rotated_offset := la.mul(conj(parent_rot), scaled_offset) // Invert the value
    heart.global_position = parent_pos + rotated_offset

    // Update global scale
    heart.global_scale = parent_scale * heart.local_scale

    // Update global rotation
    heart.global_rotation = parent_rot * heart.local_rotation

    for c in heart.children {
        update_transform_recursive(c)
    }
}