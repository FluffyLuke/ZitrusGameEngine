package ecs

ZECS :: struct {
    // Indexes to dead entities in the "entities" list.
    free_entities: [dynamic]EntityIndex, 

    // List of all entities. May also contain dead ones.
    entities: [dynamic]EntityRecord,
    archetypes: map[ArchetypeMask]Archetype
}

zecs: ZECS = {}