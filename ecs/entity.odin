package ecs;

import "core:fmt"
import "core:os"

// Left 32 bits are used for marking generation
// Right 32 bits are the index
// gen   idx
// 0101|1100
Entity :: distinct u64

EntityGeneration :: distinct u32
EntityIndex :: distinct u32

EntityRecord :: struct {
    generation: EntityGeneration,
    archetype: Maybe(ArchetypeMask),
    chunk: int,
    chunk_index: int, // used to tell if entity is dead
}

//////////////////
// ID functions //
//////////////////

get_entity_record :: proc {
    get_entity_record_index,
    get_entity_record_whole,
}
get_entity_record_index :: proc(e: EntityIndex) -> ^EntityRecord { return &zecs.entities[e] }
get_entity_record_whole :: proc(e: Entity) -> ^EntityRecord { return &zecs.entities[get_index(e)]; }

split_entity :: proc(e: Entity) -> (EntityGeneration, EntityIndex) {
    return get_generation(e), get_index(e);
}

get_index :: proc(e: Entity) -> EntityIndex {
    return auto_cast u32(e)
}

get_generation :: proc(e: Entity) -> EntityGeneration {
    return auto_cast auto_cast u32(e >> 32)
}

zip_entity :: proc(i: EntityIndex, g: EntityGeneration) -> Entity {
    entity: Entity = auto_cast g
    entity = entity << 32
    entity += auto_cast i
    return entity
}

//////////////////////
// Entity functions //
//////////////////////

create_entity :: proc() -> Entity {
    // Get next free entity if exists.
    if len(zecs.free_entities) > 0 {
        e: EntityIndex = zecs.free_entities[0]
        unordered_remove(&zecs.free_entities, 0)
        entity_record := get_entity_record(e);

        entity_record.archetype = nil // clear archetype
        entity_record.generation += 1 // increment generation
        entity_record.chunk = -1
        entity_record.chunk_index = -1

        return zip_entity(e, entity_record.generation)
    }

    // Too many entities, abort.
    if len(zecs.free_entities) == int(max(u32) - 1) {
        fmt.printfln("[ERROR] Cannot create new entity. Aborting...")
        os.exit(-1)
    }

    // Create new entity.
    next_index: Entity = auto_cast len(zecs.entities) // No need to set generation, as it is 0.
    entity_record := EntityRecord {
        generation = 0,
        archetype = nil,
        chunk = -1,
        chunk_index = -1,
    }
    append(&zecs.entities, entity_record)
    return next_index
}

add_component :: proc(e: Entity) {

    component_data := [dynamic]RawComponentPointer {}
    if get_component_data(e, &component_data) {
        remove_from_archetype(e)
    }
}
