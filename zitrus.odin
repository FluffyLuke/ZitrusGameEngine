package zitrus

import "core:fmt"
import "core:time"

import "ecs"
import "assets"
import "graphics"

init_engine := proc() {
    // Init everything
    ecs.init_default_components()
    graphics.init_rendering()
}

start_engine := proc() {
    game_loop()
    ecs.delete_zecs()
}

game_loop :: proc() {
    when ODIN_DEBUG {
        init_debug()
    }
    
    // This should run after all queries are added!
    ecs.register_systems()

    // Start system
    {
        if start_system := ecs.get_system(ecs.InternalSystems.Start); start_system != nil {
            ecs.run_system(start_system, 0)
        }
    }

    internal_systems_used := 0
    for i_s in ecs.InternalSystems {
        if ecs.get_system(i_s) != nil do internal_systems_used += 1
    }

    previous_time := time.now()
    for ecs.zecs.should_close == false {
        when ODIN_DEBUG {
            check_debug()
        }

        // Check if queries should be refreshed.
        if ecs.zecs.new_archetype_created {
            ecs.refresh_all_systems()
            ecs.zecs.new_archetype_created = false
        }

        current_time := time.now()
        delta_time: f64 = time.duration_seconds(time.diff(previous_time, current_time))
        previous_time = current_time

        // General update
        if generic_update := ecs.get_system(ecs.InternalSystems.Update); generic_update != nil {
            ecs.run_system(generic_update, delta_time)
        }

        // User defined systems
        for i in 0..< len(ecs.zecs.systems) - internal_systems_used {
            // This loop should omit all internal systems.
            // They will be run by different parts of the engine.
            system := &ecs.zecs.systems[i]
            ecs.run_system(system, delta_time)
        }

        // Render the game.
        ecs.zecs.should_close = graphics.render()

        // Delete dead entities.
        for mask, archetype in ecs.zecs.deletion_archetypes {
            for chunk in archetype.chunks {
                for e in chunk.entities {
                    ecs.delete_entity(e)
                }
            }
        }
    }

    // Finish system
    {
        if finish_system := ecs.get_system(ecs.InternalSystems.Finish); finish_system != nil {
            ecs.run_system(finish_system, 0)
        }
    }

    // Deinit
    {
        graphics.destroy_rendering()
    }

    //assets.clear_all_managers()
    assets.delete_all_managers()

    when ODIN_DEBUG {
        destroy_debug()
    }
}