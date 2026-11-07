package ecs

import "core:fmt"
import "core:os"
import "core:mem"

Time :: f64

QueryStart :: struct {
    logic: proc(e: Entity),
}

QueryUpdate :: struct {
    logic: proc(e: Entity, delta_time: Time),
}

QueryEnd :: struct {
    logic: proc(e: Entity),
}

SystemType :: union {
    QueryStart,
    QueryUpdate,
    QueryEnd,
}


RegisteredQuery :: struct {
    type: SystemType,

    archetypes: [dynamic]^Archetype,
    component_ids: []ComponentID,
}


QueryPendingRegistration :: struct {
    type: SystemType,
    component_types: []typeid,
}

@(private="file")
query_registration_queue := [dynamic]QueryPendingRegistration {}

add_query_start :: proc(component_types: []typeid, query: proc(e: Entity)) {
    copied_types := make([]typeid, len(component_types))
    copy(copied_types, component_types)
    
    append(&query_registration_queue, QueryPendingRegistration {
        type = QueryStart {
            logic = query
        },
        component_types = copied_types,
    })
}

// Delta time is in seconds.
add_query_update :: proc(component_types: []typeid, query: proc(e: Entity, delta_time: Time)) {
    copied_types := make([]typeid, len(component_types))
    copy(copied_types, component_types)
    
    append(&query_registration_queue, QueryPendingRegistration {
        type = QueryUpdate {
            logic = query
        },
        component_types = copied_types,
    })
}

add_query_end :: proc(component_types: []typeid, query: proc(e: Entity)) {
    copied_types := make([]typeid, len(component_types))
    copy(copied_types, component_types)
    
    append(&query_registration_queue, QueryPendingRegistration {
        type = QueryEnd {
            logic = query
        },
        component_types = copied_types,
    })
}

// Archetypes may be created or deleted on the fly.
// This requires the queries to be reconnected when this happens.
reconnect_query :: proc(query: ^RegisteredQuery) {
    clear(&query.archetypes)
    for mask, archetype in zecs.archetypes {
        if components_in_mask(mask, query.component_ids) {
            append(&query.archetypes, archetype)
        }
    }
}

refresh_all_queries :: proc() {
    for &q in zecs.queries.start {
        reconnect_query(&q)
    }
    for &q in zecs.queries.update {
        reconnect_query(&q)
    }
    for &q in zecs.queries.end {
        reconnect_query(&q)
    }
}

// Consume all queries pending registration.
// This procedure should run only once.
@(private="package")
register_queries :: proc() {
    // First, create all possible archetypes.
    for q in query_registration_queue {
        get_or_create_archetype(..q.component_types)
    }

    // Attach archetypes to queries.
    for q in query_registration_queue {
        defer delete(q.component_types) // This list won't be useful anymore.

        // Get list of components used in each query (useful metadata).
        component_ids := make([]ComponentID, len(q.component_types))
        for c_t, i in q.component_types {
            component_id, _ := get_component_id_typeid(c_t)
            component_ids[i] = component_id
        }

        // Create the actual query.
        query := RegisteredQuery {
            type = q.type,
            component_ids = component_ids
        }

        // Find archetypes, that have specified components.
        reconnect_query(&query)

        // Append the query
        switch t in q.type {
            case QueryStart: append(&zecs.queries.start, query)
            case QueryUpdate: append(&zecs.queries.update, query)
            case QueryEnd: append(&zecs.queries.end, query)
        }
    }

    delete(query_registration_queue)
}

delete_query :: proc(query: RegisteredQuery) {
    delete(query.archetypes)
    delete(query.component_ids)
}
