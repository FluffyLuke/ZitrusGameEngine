package zitrus

set_position :: proc(z: ^Zitrus_Heart, entity: Entity_ID, position: Vec3) {
    heart, _ := get_component(z, entity, Entity_Heart)
    heart.position = position
}

update_position :: proc(z: ^Zitrus_Heart, entity: Entity_ID, position_update: Vec3) {
    heart, _ := get_component(z, entity, Entity_Heart)
    heart.position += position_update
}