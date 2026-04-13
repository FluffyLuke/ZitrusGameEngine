package zitrus
import "core:fmt"

Sparse_Index :: distinct u64
Dense_Index :: distinct u64

Item_Pointer :: rawptr

SPARSE_PAGE_SIZE :: 4096
Sparse_Set :: struct {
    type_in_set: typeid,
    number_of_items: u64,
    data: rawptr,
    
    destroy_set: proc(this: rawptr),

    get: proc(this: rawptr, id: Sparse_Index) -> Item_Pointer,
    set: proc(this: rawptr, id: Sparse_Index, item: Item_Pointer) -> Item_Pointer,
    delete: proc(this: rawptr, id: Sparse_Index) -> bool,
    clear: proc(this: rawptr),

    get_dense_index: proc(this: rawptr, id: Sparse_Index) -> Dense_Index,
    set_dense_index: proc(this: rawptr, id: Sparse_Index, index: Dense_Index),
}

Sparse_Set_Data :: struct($T: typeid) {
    dense: [dynamic]T,
    dense_to_entity: [dynamic]Sparse_Index,
    sparse: [dynamic][SPARSE_PAGE_SIZE]Dense_Index,
}

// Big ass function
// Creates new sparse set object
new_sparse_set :: proc($T: typeid, allocator := context.allocator) -> (sparse_set: Sparse_Set) {
    sparse_set.type_in_set = T

    sparse_set.data = new(Sparse_Set_Data(T), allocator)
    sparse_set.get = proc(this: rawptr, id: Sparse_Index) -> Item_Pointer {
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)
        
        dense_index: Dense_Index = sparse_set.get_dense_index(sparse_set, id)
    
        if dense_index != Dense_Index(TOMBSTONE) {
            return &data.dense[dense_index]
        }
    
        return nil
    }

    sparse_set.set = proc(this: rawptr, id: Sparse_Index, item: Item_Pointer) -> Item_Pointer{
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)

        item_deref := (^T)(item)^
        
        dense_index: Dense_Index = sparse_set.get_dense_index(sparse_set, id)
        if dense_index != Dense_Index(TOMBSTONE) {
            data.dense[dense_index] = item_deref
            data.dense_to_entity[dense_index] = id
    
            return &data.dense[dense_index]
        }

        sparse_set.number_of_items += 1;
    
        sparse_set.set_dense_index(sparse_set, id, Dense_Index(len(data.dense)))
        append(&data.dense, item_deref)
        append(&data.dense_to_entity, id)
    
        return &data.dense[len(data.dense)-1]
    }

    sparse_set.clear= proc(this: rawptr) {
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)

        clear(&data.dense)
        clear(&data.dense_to_entity)
        clear(&data.sparse)
    }

    // Gets and index to the dense set from COMPONENT! sparse set
    // Returns "default" if no index is found
    sparse_set.get_dense_index = proc(this: rawptr, id: Sparse_Index) -> Dense_Index {
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)

        // Index of the page
        page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
        // Index in that page
        sparse_index: Sparse_Index = id % SPARSE_PAGE_SIZE;
        // Return index of the component in the sparse set
        if page < u64(len(data.sparse)) {
            sprase := data.sparse[page];
            return sprase[sparse_index]
        }

        return Dense_Index(TOMBSTONE)
    }

    sparse_set.set_dense_index = proc(this: rawptr, id: Sparse_Index, index: Dense_Index) {
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)
        // Index of the page
        page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
        // Index in that page
        sparse_index: Sparse_Index = id % SPARSE_PAGE_SIZE;
    
        // Check if new page needs to be allocated
        // If so, populate it with tombstone
        if page >= u64(len(data.sparse)) {
            resize_dynamic_array(&data.sparse, page+1)
            for i in 0..<SPARSE_PAGE_SIZE {
                data.sparse[page][i] = Dense_Index(TOMBSTONE)
            }
        }
    
        // Get current sparse page
        sparse_page: ^[SPARSE_PAGE_SIZE]Dense_Index = &data.sparse[page];
        sparse_page[sparse_index] = index;
    }

    sparse_set.delete = proc(this: rawptr, id: Sparse_Index) -> bool{
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)

        dense_index: Dense_Index = sparse_set.get_dense_index(sparse_set, id)

        if dense_index == Dense_Index(TOMBSTONE) {
            return false
        }
        sparse_set.number_of_items -= 1;
    
        // Change places of last element and element that needs to be deleted
        // Or simpler - just override deleted element with the last
        data.dense[dense_index] = data.dense[len(data.dense)-1]
        moved_element_index: Sparse_Index = data.dense_to_entity[len(data.dense)-1]
    
        pop(&data.dense_to_entity)
        pop(&data.dense)
    
        // Set sparse index of deleted element to TOMBSTONE
        page: u64 = u64(id) / u64(SPARSE_PAGE_SIZE);
        sparse_index: u64 = u64(id) % u64(SPARSE_PAGE_SIZE);
        data.sparse[page][sparse_index] = Dense_Index(TOMBSTONE)
    
        // Update sparse/dense index of moved element
        page = u64(moved_element_index) / u64(SPARSE_PAGE_SIZE);
        sparse_index = u64(moved_element_index % SPARSE_PAGE_SIZE);
        data.sparse[page][sparse_index] = dense_index
    
        return true
    }

    sparse_set.destroy_set = proc(this: rawptr) {
        sparse_set: ^Sparse_Set = (^Sparse_Set)(this)
        data: ^Sparse_Set_Data(T) = (^Sparse_Set_Data(T))(sparse_set.data)
        delete(data.dense)
        delete(data.dense_to_entity)
        delete(data.sparse)
        free(data)
    }

    return
}

