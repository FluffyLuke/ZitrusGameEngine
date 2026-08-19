package zitrus

import "core:fmt"
import la "core:math/linalg"

Entity_ID :: Sparse_Index
TOMBSTONE :: max(Sparse_Index)

Entity_On_Delete :: proc(Entity_ID)
Entity_Heart :: struct {
    position: Vec3,

    scale: Vec3,
    rotation: quaternion128,

    on_delete: Entity_On_Delete,
}

Entity_Alive :: struct {}
Entity_Dying :: struct {}

// The bigger the depth, the further away it will be from the screen
// Depth range = <0 ; RENDERING_DEPTH)
create_entity :: proc(pos: Vec3 = {0,0,0}, tags: []string = nil, on_delete: Entity_On_Delete = nil) -> (index: Entity_ID) {
    index = heart.next_id
    heart.next_id += 1;
    heart.entity_masks.set(&heart.entity_masks, index, &Component_Mask {})

    entity_heart := set_component(index, Entity_Heart{
        position = pos,
        // depth = depth,
        scale = {1,1,1},
        rotation = 1,

        on_delete = on_delete
    })

    set_component(index, Entity_Alive{})
    return
}

set_on_delete :: proc(id: Entity_ID, on_delete: Entity_On_Delete) {
    h, _ := get_component(id, Entity_Heart)
    h.on_delete = on_delete
}

destroy_entity :: proc(id: Entity_ID) -> bool {
    if has_component(id, typeid_of(Entity_Dying)) {
        fmt.printfln("[WARNING] Tried to delete entity twice")
        return false
    }

    h, _ := get_component(id, Entity_Heart)

    remove_component(id, Entity_Alive)
    set_component(id, Entity_Dying {})
    
    return true
}

get_entity_heart :: #force_inline proc(entity: Entity_ID) -> ^Entity_Heart {
    heart, _ := get_component(entity, Entity_Heart)
    return heart
}

get_position :: proc(entity: Entity_ID, position: Vec3) -> Vec3 {
    heart := get_entity_heart(entity)
    return heart.position
}

set_position :: proc(entity: Entity_ID, position: Vec3) {
    heart := get_entity_heart(entity)
    heart.position = position
}

update_position :: proc(entity: Entity_ID, position_update: Vec3) -> Vec3 {
    heart := get_entity_heart(entity)
    heart.position += position_update
    return heart.position
}

// get_rotation_2D :: proc(entity: Entity_ID, up: Vec3 = Up_Vec) -> Vec3 {
//     heart := get_entity_heart(entity)

//     return la.mul(heart.rotation, up)
// }

// set_rotation :: proc(entity: Entity_ID, rotation: Vec2) {
//     heart := get_entity_heart(entity)

//     rad := rotation * la.to_radians(f32(1.0))

//     heart.rotation = la.quaternion_angle_axis(rad.x, Vec3 {1,0,0}) \
//         * la.quaternion_angle_axis(rad.y, Vec3 {0,1,0}) \
//         * la.quaternion_angle_axis(rad.z, Vec3 {0,0,1})
// }

// update_rotation :: proc(entity: Entity_ID, rotation: Vec3) {
//     heart := get_entity_heart(entity)

//     rad := rotation * la.to_radians(f32(1.0))

//     heart.rotation *= la.quaternion_angle_axis(rad.x, Vec3 {1,0,0}) \
//         * la.quaternion_angle_axis(rad.y, Vec3 {0,1,0}) \
//         * la.quaternion_angle_axis(rad.z, Vec3 {0,0,1})
// }