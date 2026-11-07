package ecs

import "vendor:curl"
import "core:fmt"
import "core:time"

ZECS :: struct {
    // Indexes to dead entities in the "entities" list.
    free_entities: [dynamic]EntityIndex, 

    // List of all entities. May also contain dead ones.
    entities: [dynamic]EntityRecord,
    
    archetypes: map[ArchetypeMask]^Archetype,
    deletion_archetypes: map[ArchetypeMask]^Archetype, // Archetypes for dead entities, that wait to be deleted.

    queries: struct {
        start: [dynamic]RegisteredQuery,
        update: [dynamic]RegisteredQuery,
        end: [dynamic]RegisteredQuery,
    },

    should_close: bool,
    // Used to indicate, if new archetype was created this frame.
    // Should be consumed by the game loop.
    new_archetype_created: bool,
}

zecs: ZECS = {}

delete_zecs :: proc() {
    for mask, archetype in zecs.archetypes {
        delete_archetype(archetype)
    }

    for query in zecs.queries.start do delete_query(query)
    for query in zecs.queries.update do delete_query(query)
    for query in zecs.queries.end do delete_query(query)

    delete(zecs.queries.start)
    delete(zecs.queries.update)
    delete(zecs.queries.end)

    delete(zecs.archetypes)
    delete(zecs.entities)
}

game_loop :: proc() {
    when ODIN_DEBUG {
        init_debug()
    }
    init_default_components()

    // This should run after all queries are added!
    register_queries()

    // Monstrosity
    for query in zecs.queries.start {
        for archetype in query.archetypes {
            for chunk in archetype.chunks {
                for i in 0..<chunk.count {
                    e := chunk.entities[i]
                    query.type.(QueryStart).logic(e)
                }
            }
        }
    }

    previous_time := time.now()
    for zecs.should_close == false {
        when ODIN_DEBUG {
            check_debug()
        }

        // Check if queries should be refreshed.
        if zecs.new_archetype_created {
            refresh_all_queries()
            zecs.new_archetype_created = false
        }

        current_time := time.now()
        delta_time: f64 = time.duration_seconds(time.diff(previous_time, current_time))
        previous_time = current_time

        for query in zecs.queries.update {
            for archetype in query.archetypes {
                for chunk in archetype.chunks {
                    for i in 0..<chunk.count {
                        e := chunk.entities[i]
                        query.type.(QueryUpdate).logic(e, delta_time)
                    }
                }
            }
        }

        for mask, archetype in zecs.deletion_archetypes {
            for chunk in archetype.chunks {
                for e in chunk.entities {
                    delete_entity(e)
                }
            }
        }
    }

    for query in zecs.queries.end {
        for archetype in query.archetypes {
            for chunk in archetype.chunks {
                for i in 0..<chunk.count {
                    e := chunk.entities[i]
                    query.type.(QueryEnd).logic(e)
                }
            }
        }
    }

    when ODIN_DEBUG {
        destroy_debug()
    }
}