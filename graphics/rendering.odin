package graphics

import rl "vendor:raylib"

import "../ecs"

set_target_fps :: proc(fps: i32) {
    rl.SetTargetFPS(fps)
}

init_rendering :: proc () {
    rl.InitWindow(1200, 800, "ZitrusEngine")
    set_target_fps(60)



}

destroy_rendering :: proc() {
    rl.CloseWindow();
}

render :: proc() {
    
}