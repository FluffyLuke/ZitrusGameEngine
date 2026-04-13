package zitrus

import "core:fmt"
import la "core:math/linalg"

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

get_rotation_2D :: proc(entity: Entity_ID, up: Vec3 = Up_Vec) -> Vec3 {
    heart := get_entity_heart(entity)

    return la.mul(heart.rotation, up)
}

set_rotation :: proc(entity: Entity_ID, rotation: Vec3) {
    heart := get_entity_heart(entity)

    rad := rotation * la.to_radians(f32(1.0))

    heart.rotation = la.quaternion_angle_axis(rad.x, Vec3 {1,0,0}) \
        * la.quaternion_angle_axis(rad.y, Vec3 {0,1,0}) \
        * la.quaternion_angle_axis(rad.z, Vec3 {0,0,1})
}

update_rotation :: proc(entity: Entity_ID, rotation: Vec3) {
    heart := get_entity_heart(entity)

    rad := rotation * la.to_radians(f32(1.0))

    heart.rotation *= la.quaternion_angle_axis(rad.x, Vec3 {1,0,0}) \
        * la.quaternion_angle_axis(rad.y, Vec3 {0,1,0}) \
        * la.quaternion_angle_axis(rad.z, Vec3 {0,0,1})
}