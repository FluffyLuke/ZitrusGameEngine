package ecs;

import "core:fmt"
import "core:os"
import "core:mem"

MAX_COMPONENTS :: 256
WORDS :: MAX_COMPONENTS / 64

ArchetypeMask :: struct {
    bits: [WORDS]u64
}

create_archetype_mask :: proc(ids: []ComponentID) -> ArchetypeMask {
    mask := ArchetypeMask {}

    for id in ids {
        word_index := id / 64
        bit_index := id % 64

        mask.bits[word_index] |= (1 << bit_index)
    }

    return mask
}

CHUNK_SIZE :: 8 * 1000 * 16 // 16 kilobytes

Chunk :: struct {
    count: int,
    capacity: int,

    // Maps components to entities
    entities: []Entity,

    // Marks where each component array starts
    offsets: []int,

    // Holds all of the components.
    components: rawptr,
}

Archetype :: struct {
    mask: ArchetypeMask,
    chunks: [dynamic]Chunk,

    component_sizes: []int,

    // Marks where each component array starts.
    // This list is copied to each chunk.
    offsets: []int,
    chunk_capacity: int, // Copied to each chunk upon creation.
}

ComponentID :: u64
next_id: ComponentID = 0

@(private="file")
component_to_bit := map[typeid]ComponentID {}

register_component :: proc(component_type: typeid) -> (id: ComponentID) {
    registered_id, exists := component_to_bit[component_type]
    if exists do return registered_id

    if next_id >= MAX_COMPONENTS {
        fmt.println("[ERROR] Too many components. Aborting...")
        os.exit(-1)
    }

    id = next_id
    component_to_bit[component_type] = id;

    next_id += 1;
    return;
}

make_archetype :: proc(component_types: ..typeid) -> Archetype {
    component_ids := [dynamic]ComponentID {}
    component_sizes := [dynamic]int {}
    defer delete(component_ids)
    defer delete(component_sizes)

    batch_size: int = 0
    for c_t, i in component_types {
        append(&component_ids, register_component(c_t))
        append(&component_sizes, size_of(c_t))
        batch_size += size_of(c_t)
    }

    mask := create_archetype_mask(component_ids[:])
    archetype := Archetype {
        mask = mask,
        chunks = {},
        offsets = make([]int, len(component_types)),
        component_sizes = make([]int, len(component_types)),
        chunk_capacity = CHUNK_SIZE / batch_size,
    }

    // Set offsets and component sizes
    current_offset := 0
    for s, i in component_sizes {
        archetype.offsets[i] = current_offset
        current_offset = (s * archetype.chunk_capacity) + current_offset

        archetype.component_sizes[i] = s
    }

    return archetype
}

delete_archetype :: proc(archetype: Archetype) {
    delete(archetype.chunks);
    delete(archetype.offsets)
}

// Keep in mind, that RawComponentPointer does not own the memory it holds reference to.
// It is only used for transfering the data from one archetype to another.
RawComponentPointer :: struct {
    id: ComponentID,
    data: rawptr,
    size: int,
}

get_component_data :: proc(e: Entity, data: ^[dynamic]RawComponentPointer) -> bool {
    record := get_entity_record(e)

    if record.archetype == nil do return false
    archetype := zecs.archetypes[record.archetype.(ArchetypeMask)]
    chunk := archetype.chunks[record.chunk]

    for o, i in chunk.offsets {
        component_size := archetype.component_sizes[i]
        component_ptr := mem.ptr_offset(cast(^u8)chunk.components, (record.chunk_index * component_size) + o)

        append(data, RawComponentPointer { component_ptr, component_size })
    }

    return true
}

add_to_archetype :: proc(archetype: ^Archetype, e: Entity, components: []RawComponentPointer) {
    _, index := split_entity(e);

    current_chunk: ^Chunk = nil
    current_chunk_index: int = -1
    for &c, i in archetype.chunks {
        if c.count < c.capacity {
            current_chunk = &c
            current_chunk_index = i
        }
    }

    // If chunk was not found...
    if current_chunk == nil {
        c, _ := mem.alloc(16000) // Allocate block of memory
        new_chunk := Chunk {
            capacity = archetype.chunk_capacity,
            entities = make([]Entity, archetype.chunk_capacity),
            offsets = make([]int, len(archetype.offsets)),
            components = c
        }
        copy(new_chunk.offsets, archetype.offsets)
        append(&archetype.chunks, new_chunk)
        current_chunk = &archetype.chunks[len(archetype.chunks)-1]
        current_chunk_index = len(archetype.chunks) - 1
    }

    // From this point, we can safely assume that chunk has free space
    free_index := current_chunk.count
    defer current_chunk.count += 1

    // Copy component data into proper places.
    for c, i in components {
        offset := current_chunk.offsets[i]
        component_ptr: rawptr = current_chunk.components
        component_ptr = mem.ptr_offset(cast(^u8)component_ptr, (free_index * c.size) + offset)

        mem.copy(component_ptr, c.data, c.size)
    }

    // Connect component with entity
    current_chunk.entities[free_index] = e

    record := get_entity_record(e)
    record.archetype = archetype.mask
    record.chunk = current_chunk_index
    record.chunk_index = free_index
}

remove_from_archetype :: proc(e: Entity) -> bool {
    record := get_entity_record(e)

    if record.archetype == nil do return false
    archetype := zecs.archetypes[record.archetype.(ArchetypeMask)]

    chunk := archetype.chunks[record.chunk]
    defer {
        record.chunk = -1
        record.chunk_index = -1
        record.archetype = nil
        chunk.count -= 1
    }

    last_index := chunk.count - 1

    // If this entity is the last entity, return imidiatelly and don't do the swap. 
    if record.chunk_index == last_index do return true

    for o, i in chunk.offsets {
        component_size := archetype.component_sizes[i]

        // Component to be removed. At its place last element will be copied.
        dest := mem.ptr_offset(cast(^u8)chunk.components, (record.chunk_index * component_size) + o)

        // Component that will be copied to the empty spot after removed component.
        src := mem.ptr_offset(cast(^u8)chunk.components, (last_index * component_size) + o)

        mem.copy(dest, src, component_size)
    }

    // Update the swapped entity.
    swapped_entity := chunk.entities[last_index]
    swapped_entity_record := get_entity_record(swapped_entity)

    chunk.entities[record.chunk_index] = chunk.entities[last_index]
    swapped_entity_record.chunk_index = record.chunk_index

    return true
}