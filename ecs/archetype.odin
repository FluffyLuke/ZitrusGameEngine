package ecs;

import "core:fmt"
import "core:os"
import "core:mem"

MAX_COMPONENTS :: 256
WORDS :: MAX_COMPONENTS / 64

ArchetypeMask :: struct {
    bits: [WORDS]u64
}

create_archetype_mask :: proc {
    create_archetype_mask_id,
    create_archetype_mask_component_ptr,
}


create_archetype_mask_id :: proc(ids: []ComponentID) -> ArchetypeMask {
    mask := ArchetypeMask {}

    for id in ids {
        word_index := id / 64
        bit_index := id % 64

        mask.bits[word_index] |= (1 << bit_index)
    }

    return mask
}

create_archetype_mask_component_ptr :: proc(components: []RawComponentPointer) -> ArchetypeMask {
    mask := ArchetypeMask {}

    for c in components {
        word_index := c.id / 64
        bit_index := c.id % 64

        mask.bits[word_index] |= (1 << bit_index)
    }

    return mask
}

components_in_mask :: proc {
    components_in_mask_id,
    components_in_maks_component_ptr
}

// Checks if all components belong to that mask
components_in_mask_id :: proc(mask: ArchetypeMask, ids: []ComponentID) -> bool {
    for id in ids {
        word_index := id / 64
        bit_index := id % 64

        mask_part := mask.bits[word_index]
        id_bit := u64(1) << bit_index

        if mask_part & id_bit == 0 do return false
    }

    return true
}

components_in_maks_component_ptr :: proc(mask: ArchetypeMask, components: []RawComponentPointer) -> bool {
    for c in components {
        word_index := c.id / 64
        bit_index := c.id % 64

        mask_part := mask.bits[word_index]
        id_bit := u64(1) << bit_index

        if mask_part & id_bit == 0 do return false
    }

    return true
}

// TODO: Searching components in this manner can be rather slow.
// A better solution should be found.
get_components_in_mask :: proc(mask: ArchetypeMask, out: ^[dynamic]typeid) {
    for i in 0..=MAX_COMPONENTS {
        id := ComponentID(i)
        if components_in_mask(mask, []ComponentID { id }) {
            // This assumes component is stored in global map.
            component_type := get_component_type(id)

            append(out, component_type)
        }
    }
}

sort_raw_components :: proc(archetype: ^Archetype, components: []RawComponentPointer, ordered: ^[]RawComponentPointer) {
    // Metadata should be ordered
    for meta, i in archetype.component_metadata {
        for c in components {
            if meta.id == c.id {
                ordered[i] = c
            }
        }
    }
}

CHUNK_SIZE :: 1024 * 16 // 16 kilobytes

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

ComponentMetadata :: struct {
    id: ComponentID,
    size: int,
}

// This struct is safe to be copied.
Archetype :: struct {
    mask: ArchetypeMask,
    chunks: [dynamic]Chunk,

    component_metadata: []ComponentMetadata,

    // Marks where each component array starts.
    // This list is copied to each chunk.
    offsets: []int,
    chunk_capacity: int, // Copied to each chunk upon creation.
}

ComponentID :: distinct u64
next_id: ComponentID = 0

@(private="file")
component_to_bit := map[typeid]ComponentID {}
@(private="file")
bit_to_component := map[ComponentID]typeid {}

register_component :: proc(component_type: typeid) -> (id: ComponentID) {
    registered_id, exists := component_to_bit[component_type]
    if exists do return registered_id

    if next_id >= MAX_COMPONENTS {
        fmt.println("[ERROR] Too many components. Aborting...")
        os.exit(-1)
    }

    id = next_id
    component_to_bit[component_type] = id;
    bit_to_component[id] = component_type

    next_id += 1;
    return;
}

get_component_id :: proc {
    get_component_id_type,
    get_component_id_typeid,
}

get_component_id_type :: proc(component_type: $T) -> (ComponentID, bool) {
    return get_component_id_typeid(type_of(component_type))
}

get_component_id_typeid :: proc(component_typeid: typeid) -> (ComponentID, bool) {
    return component_to_bit[component_typeid]
}

get_component_type :: proc(component_id: ComponentID) -> typeid {
    return bit_to_component[component_id]
}

make_archetype :: proc(component_types: ..typeid) -> ^Archetype {
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
    
    archetype: ^Archetype = new(Archetype)
    archetype^ = Archetype {
        mask = mask,
        chunks = {},
        offsets = make([]int, len(component_types)),
        component_metadata = make([]ComponentMetadata, len(component_types)),
        chunk_capacity = CHUNK_SIZE / batch_size,
    }

    // Set offsets
    current_offset := 0
    for s, i in component_sizes {
        archetype.offsets[i] = current_offset
        current_offset = (s * archetype.chunk_capacity) + current_offset
    }

    // Set component metadata and ids
    for c_t, i in component_types {
        archetype.component_metadata[i] = ComponentMetadata {
            id = component_ids[i],
            size = component_sizes[i],
        }
    }

    return archetype
}

// Returns pointer to the archetype. If archetype does not exists, procedure will create it.
get_or_create_archetype :: proc(components: ..typeid) -> ^Archetype {
    component_ids := make([]ComponentID, len(components))
    defer delete(component_ids)
    
    for c_t, i in components {
        id := register_component(c_t)
        component_ids[i] = id
    }

    mask := create_archetype_mask(component_ids)
    archetype, ok := zecs.archetypes[mask]

    if !ok {
        zecs.archetypes[mask] = make_archetype(..components[:])
        archetype = zecs.archetypes[mask]
    }

    return archetype
}

delete_archetype :: proc(archetype: ^Archetype) {
    // Free the memory inside each chunk.
    for c in archetype.chunks {
        delete(c.entities)
        delete(c.offsets)
        mem.free(c.components)
    }
    
    // Free the archetype's arrays.
    delete(archetype.chunks)
    delete(archetype.offsets)
    delete(archetype.component_metadata)

    // Free the archetype itself.
    free(archetype)
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
        metadata := archetype.component_metadata[i]
        component_ptr := mem.ptr_offset(cast(^u8)chunk.components, (record.chunk_index * metadata.size) + o)

        append(data, RawComponentPointer { metadata.id, component_ptr, metadata.size })
    }

    return true
}

add_to_archetype :: proc(archetype: ^Archetype, e: Entity, components: []RawComponentPointer) {
    // Before doing anything, components must be validated.
    // This includes checking if those components actually belong to this archetype...
    // ... and if they are put in the right order (order matters).
    if !components_in_mask(archetype.mask, components) do return

    components_ordered := make([]RawComponentPointer, len(components))
    defer delete(components_ordered)
    sort_raw_components(archetype, components, &components_ordered)
    
    _, index := split_entity(e);

    current_chunk: ^Chunk = nil
    current_chunk_index: int = -1
    for &c, i in archetype.chunks {
        if c.count < c.capacity {
            current_chunk = &c
            current_chunk_index = i
            break // ADD THIS!
        }
    }

    // If chunk was not found...
    if current_chunk == nil {
        c, _ := mem.alloc(CHUNK_SIZE) // Allocate block of memory
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
    for c, i in components_ordered {
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
        component_size := archetype.component_metadata[i].size

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