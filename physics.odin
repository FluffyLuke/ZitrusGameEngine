package zitrus

Collider_2D :: struct {
    origin: Vec2,
    size: Vec2,
}

init_physics :: proc() {
    register_component(Collider_2D, auto_cast Component_Cleanup_Default)
}

destroy_physics :: proc() {

}