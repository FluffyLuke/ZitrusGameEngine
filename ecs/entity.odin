package ecs;

import "core:fmt"
import "core:mem"
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

// @(private="package")
// Should not be used by the end user!
delete_entity :: proc(e: Entity) {
    component_data := [dynamic]RawComponentPointer {}
    defer delete(component_data)

    if get_component_data(e, &component_data) {
        for raw in component_data {
            destructor := get_component_destructor(raw.id)
            if destructor != nil do destructor(raw.data)
        }
    }
    remove_from_archetype(e)

    generation, index := split_entity(e)
    append(&zecs.free_entities, index)

    entity_record := get_entity_record(e)
    entity_record.archetype = nil // clear archetype
    entity_record.generation += 1 // increment generation
    entity_record.chunk = -1
    entity_record.chunk_index = -1
}

schedule_deletion :: proc(e: Entity) {
    add_component(e, DeleteComponent {})
}

// TODO: Some of the functions take raw types, while other RawComponentPtr.
// This should be standarized.
add_component :: proc(e: Entity, component: $T) -> ^T{
    component_data := [dynamic]RawComponentPointer {}
    defer delete(component_data)

    component_types := [dynamic]typeid {}
    defer delete(component_types)

    component_id := register_component(T)

    // If entity belongs to an archetype, then remove entity from it.
    if get_component_data(e, &component_data) {
        remove_from_archetype(e)
        for raw in component_data {
            type := get_component_type(raw.id)
            append(&component_types, type)
        }
    }
    // Copying entire component, because immutable arguments are great!!!
    component_copy := component

    // Add new component to the list.
    append(&component_data, RawComponentPointer {
        id = component_id,
        data = &component_copy,
        size = size_of(T),
    })

    append(&component_types, T)

    // Paste that data into new archetype. Mark if new archetype was created.
    archetype, created_new  := get_or_create_archetype(..component_types[:])
    if created_new do zecs.new_archetype_created = true
    add_to_archetype(archetype, e, component_data[:])

    return get_component(e, T)
}

get_component :: proc(e: Entity, $T: typeid) -> ^T {
    record := get_entity_record(e)
    
    // Check if entity is even alive.
    if record.archetype == nil do return nil

    archetype := zecs.archetypes[record.archetype.(ArchetypeMask)]
    target_id := register_component(T)

    // Get column of desired component.
    column_index := -1
    for meta, i in archetype.component_metadata {
        if meta.id == target_id {
            column_index = i
            break
        }
    }

    // Column not found in this archetype, return nil.
    if column_index == -1 do return nil

    chunk := archetype.chunks[record.chunk]
    offset := chunk.offsets[column_index]
    size := archetype.component_metadata[column_index].size

    ptr := mem.ptr_offset(cast(^u8)chunk.components, (record.chunk_index * size) + offset)
    
    return (^T)(ptr)
}