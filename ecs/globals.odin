package ecs

import "core:fmt"

ZECS :: struct {
    // Indexes to dead entities in the "entities" list.
    free_entities: [dynamic]EntityIndex, 

    // List of all entities. May also contain dead ones.
    entities: [dynamic]EntityRecord,
    
    archetypes: map[ArchetypeMask]^Archetype,

    queries: struct {
        start: [dynamic]RegisteredQuery,
        update: [dynamic]RegisteredQuery,
        end: [dynamic]RegisteredQuery,
    },
    update: [dynamic]RegisteredQuery,

    should_close: bool,
}

zecs: ZECS = {}

game_loop :: proc() {
    when ODIN_DEBUG {
        init_debug()
    }
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

    for zecs.should_close == false {
        when ODIN_DEBUG {
            check_debug()
        }
        for query in zecs.queries.update {
            for archetype in query.archetypes {
                for chunk in archetype.chunks {
                    for e in chunk.entities {
                        query.type.(QueryStart).logic(e)
                    }
                }
            }
        }
    }

    for query in zecs.queries.end {
        for archetype in query.archetypes {
            for chunk in archetype.chunks {
                for e in chunk.entities {
                    query.type.(QueryStart).logic(e)
                }
            }
        }
    }

    when ODIN_DEBUG {
        destroy_debug()
    }
}