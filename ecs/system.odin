package ecs

import "core:fmt"
import "core:os"
import "core:slice"
import "core:mem"
import "base:intrinsics"

Time :: f64

Query :: struct {
    component_types: []typeid,
    logic: proc(e: Entity, delta_time: Time),
}

ParsedQuery :: struct {
    logic: proc(e: Entity, delta_time: Time),

    archetypes: [dynamic]^Archetype,
    component_ids: []ComponentID,
}

@(private="file")
system_registration_queue := map[int][dynamic]SystemPendingRegistration {}

// Archetypes may be created or deleted on the fly.
// This requires the queries to be reconnected when this happens.
reconnect_query :: proc(query: ^ParsedQuery) {
    clear(&query.archetypes)
    for mask, archetype in zecs.archetypes {
        if components_in_mask(mask, query.component_ids) {
            append(&query.archetypes, archetype)
        }
    }
}

refresh_all_systems :: proc() {
    for &s in zecs.systems {
        for &q in s.queries {
            reconnect_query(&q)
        }
    }
}


SystemPendingRegistration :: struct {
    index: int,
    queries: []Query
}

RegisteredSystem :: struct {
    index: int,
    queries: []ParsedQuery
}

// Last X systems are reserved for internal use and should not be overwritten by the end user.
INTERNAL_SYSTEMS_NUM :: 100
INTERNAL_SYSTEMS_START :: max(int) - INTERNAL_SYSTEMS_NUM

InternalSystems :: enum {
    Start = INTERNAL_SYSTEMS_START,
    Update,
    Render,
    Finish,
}

add_system :: proc(group: $T, queries: []Query) {
    #assert(intrinsics.type_is_enum(T), "Group must be of enum type!")

    cloned_queries := make([]Query, len(queries))
    for q, i in queries {
        cloned_queries[i] = q
        cloned_queries[i].component_types = slice.clone(q.component_types)
    }

    new_system := SystemPendingRegistration {
        index = int(group),
        queries = cloned_queries,
    }
    // fmt.printfln("[DEBUG] new system %v", new_system)

    list := &system_registration_queue[new_system.index]
    if list == nil {
        system_registration_queue[new_system.index] = [dynamic]SystemPendingRegistration {}
        list = &system_registration_queue[new_system.index]
    }
    
    append(list, new_system)
    // fmt.printfln("[DEBUG] queue %v", system_registration_queue)
}

@(private="file")
index_to_system := map[int]^RegisteredSystem {}

// Consume all systems pending registration.
// This procedure should run only once.
register_systems :: proc() {
    // Check for overlapping systems.
    // ie. - merge them.
    systems_merged := [dynamic]SystemPendingRegistration {}
    defer {
        for s in systems_merged {
            delete(s.queries)
        }
        delete(systems_merged)
    }

    for index, systems in system_registration_queue {
        empty, _ := make([]Query, 0)
        merged_system := SystemPendingRegistration {
            index = index,
            queries = empty
        }
        for s in systems {
            previous := merged_system.queries
            merged_queries, _ := slice.concatenate([][]Query{merged_system.queries, s.queries})
            merged_system.queries = merged_queries
            delete(previous)
            delete(s.queries)
        }
        append(&systems_merged, merged_system)
    }

    systems_unordered := [dynamic]RegisteredSystem {}
    // This loop initializes all systems.
    for s in systems_merged {
        // First, create all possible archetypes.
        for q in s.queries {
            get_or_create_archetype(..q.component_types)
        }

        query_list := [dynamic]ParsedQuery {}
        defer delete(query_list)

        // Attach archetypes to queries.
        for q in s.queries {
            defer delete(q.component_types) // This list won't be useful anymore.

            // Get list of components used in each query (useful metadata).
            component_ids := make([]ComponentID, len(q.component_types))
            for c_t, i in q.component_types {
                component_id, _ := get_component_id_typeid(c_t)
                component_ids[i] = component_id
            }

            // Create the actual query.
            query := ParsedQuery {
                logic = q.logic,
                component_ids = component_ids
            }

            // Find archetypes, that have specified components.
            reconnect_query(&query)

            // Append the query
            append(&query_list, query)
        }

        registered_system := RegisteredSystem {
            index = s.index,
            queries = slice.clone(query_list[:])
        }

        append(&systems_unordered, registered_system)
    }

    // Now we need to put them in order.
    slice.sort_by(systems_unordered[:], proc(i, j: RegisteredSystem) -> bool {
        return i.index < j.index
    })

    zecs.systems = systems_unordered
    for s in zecs.systems {
        // Since this map stores a pointer, it is guaranteed that new systems won't be added and address of them won't change.
        index_to_system[s.index] = &systems_unordered[len(systems_unordered)-1]
    }

    for k, v in system_registration_queue {
        delete(v)
    }
    delete(system_registration_queue)
}

delete_system :: proc(system: RegisteredSystem) {
    defer delete(system.queries)
    for q in system.queries {
        delete(q.archetypes)
        delete(q.component_ids)
    }
}

get_system :: proc(group: $T) -> ^RegisteredSystem {
    #assert(intrinsics.type_is_enum(T), "Group must be of enum type!")
    
    s, ok := index_to_system[int(group)]
    if !ok {
        fmt.printfln("[WARNING|System] Cannot find system called '%v'", group)
        return nil
    }
    return s
}

run_system :: proc(system: ^RegisteredSystem, delta_time: Time) {
    for query in system.queries {
        for archetype in query.archetypes {
            for chunk in archetype.chunks {
                for i in 0..<chunk.count {
                    e := chunk.entities[i]
                    query.logic(e, delta_time)
                }
            }
        }
    }
}