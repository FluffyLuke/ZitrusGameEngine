package ecs

// This package contains default entities

@(private="package")
init_default_components :: proc() {
    init_timer()
}

///////////
// Delete //
///////////

DeleteComponent :: struct {}

///////////
// Timer //
///////////

TimerComponent :: struct {
    t: Time,
    timeout: Time,
    counting: bool,
}

// Basic tag component
TimeoutComponent :: struct {}

@(private="file")
init_timer :: proc() {
    register_component(TimerComponent)
    add_query_update({TimerComponent}, proc(entity: Entity, delta: Time) {
        timer := get_component(entity, TimerComponent)

        if !timer.counting do return;

        timer.t += delta
        
        if timer.timeout <= timer.t {
            add_component(entity, TimeoutComponent {})
            timer.counting = false
        }
    })
}

attach_timer :: proc(e: Entity, timeout: Time, start_counting := false) -> ^TimerComponent {
    return add_component(e, TimerComponent {
        t = 0,
        timeout = timeout,
        counting = start_counting,
    })
}

start_timer :: proc(timer: ^TimerComponent) { timer.counting = true }
stop_timer :: proc(timer: ^TimerComponent) { timer.counting = false }