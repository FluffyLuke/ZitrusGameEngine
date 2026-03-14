package zitrus

Sparse_Index :: distinct u64
Dense_Index :: distinct u64

SPARSE_PAGE_SIZE :: 4096
Sparse_Set :: struct($T: typeid) {
    clean_up: proc(this: rawptr, a: T),
    
}

// Gets and index to the dense set from COMPONENT! sparse set
// Returns "default" if no index is found
sparse_set_get_dense_index :: proc(using sparse_set: ^Sparse_Set($T), id: Sparse_Index) -> Dense_Index {
    // Index of the page
    page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
    // Index in that page
    sparse_index: Sparse_Index = id % SPARSE_PAGE_SIZE;

    // Return index of the component in the sparse set
    if page < u64(len(sparse)) {
        sprase := sparse[page];
        return sprase[sparse_index]
    }

    return Dense_Index(TOMBSTONE)
}

sparse_set_insert_dense_index :: proc(using sparse_set: ^Sparse_Set($T), id: Sparse_Index, index: Dense_Index) {
    // Index of the page
    page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
    // Index in that page
    sparse_index: Sparse_Index = id % SPARSE_PAGE_SIZE;

    // Check if new page needs to be allocated
    // If so, populate it with tombstone
    if page >= u64(len(sparse)) {
        resize_dynamic_array(&sparse, page+1)
        for i in 0..<SPARSE_PAGE_SIZE {
            sparse[page][i] = Dense_Index(TOMBSTONE)
        }
    }

    // Get current sparse page
    sparse_page: ^[SPARSE_PAGE_SIZE]Dense_Index = &sparse[page];
    sparse_page[sparse_index] = index;
}

// If item exists it gets updated
sparse_set_insert :: proc(using sparse_set: ^Sparse_Set($T), id: Sparse_Index, item: T) -> ^T{
    dense_index: Dense_Index = sparse_set_get_dense_index(sparse_set, id)

    if dense_index != Dense_Index(TOMBSTONE) {
        dense[dense_index] = item
        dense_to_entity[dense_index] = id

        return &dense[dense_index]
    }

    sparse_set_insert_dense_index(sparse_set, id, Dense_Index(len(sparse_set.dense)))
    append(&dense, item)
    append(&dense_to_entity, id)

    return &dense[len(dense)-1]
}

sparse_set_get :: proc(using sparse_set: ^Sparse_Set($T), id: Sparse_Index) -> ^T{
    dense_index: Dense_Index = sparse_set_get_dense_index(sparse_set, id)

    if dense_index != Dense_Index(TOMBSTONE) {
        return &dense[dense_index]
    }

    return nil
}

sparse_set_delete :: proc(using sparse_set: ^Sparse_Set($T), id: Sparse_Index) -> bool{
    dense_index: Dense_Index = sparse_set_get_dense_index(sparse_set, id)

    if dense_index == Dense_Index(TOMBSTONE) {
        return false
    }

    // Change places of last element and element that needs to be deleted
    // Or simpler - just override deleted element with the last
    dense[dense_index] = dense[len(dense)-1]
    moved_element_index: Sparse_Index = dense_to_entity[len(dense)-1]

    pop(&dense_to_entity)
    pop(&dense)

    // Set sparse index of deleted element to TOMBSTONE
    page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
    sparse_index: u64 = u64(id) % u64(SPARSE_PAGE_SIZE);
    sparse[page][sparse_index] = Dense_Index(TOMBSTONE)

    // Update sparse/dense index of moved element
    page = u64(moved_element_index) / u64(SPARSE_PAGE_SIZE);
    sparse_index = u64(moved_element_index % SPARSE_PAGE_SIZE);
    sparse[page][sparse_index] = dense_index

    return true
}

destroy_sparse_set :: proc(using set: ^Sparse_Set($T)) {
    delete(dense)
    delete(dense_to_entity)
    delete(sparse)
}