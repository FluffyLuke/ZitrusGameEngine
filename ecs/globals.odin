package ecs

import "core:fmt"
import "core:time"


ZECS :: struct {
    // Indexes to dead entities in the "entities" list.
    free_entities: [dynamic]EntityIndex, 

    // List of all entities. May also contain dead ones.
    entities: [dynamic]EntityRecord,
    
    archetypes: map[ArchetypeMask]^Archetype,
    deletion_archetypes: map[ArchetypeMask]^Archetype, // Archetypes for dead entities, that wait to be deleted.

    systems: [dynamic]RegisteredSystem,

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

    for system in zecs.systems do delete_system(system)
    delete(zecs.systems)

    delete(zecs.archetypes)
    delete(zecs.entities)
}