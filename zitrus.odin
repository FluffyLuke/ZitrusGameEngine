package zitrus

import "ecs"

start_engine := proc() {
    ecs.game_loop()
    ecs.delete_zecs()
}