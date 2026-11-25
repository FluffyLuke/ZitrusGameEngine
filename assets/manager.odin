package assets

import "core:fmt"
import str "core:strings"

AssetHandle :: distinct u64

HandleGeneration :: distinct u32
HandleIndex :: distinct u32

AssetRecord :: struct {
    handle: AssetHandle,
    name: Maybe(string),
}

split_handle :: proc(h: AssetHandle) -> (HandleIndex, HandleGeneration) {
    return get_index(h), get_generation(h);
}

get_index :: proc(h: AssetHandle) -> HandleIndex {
    return auto_cast u32(h)
}

get_generation :: proc(h: AssetHandle) -> HandleGeneration {
    return auto_cast auto_cast u32(h >> 32)
}

check_generation :: proc(h1, h2: AssetHandle) -> bool {
    gen1, gen2 := get_generation(h1), get_generation(h2)
    return gen1 == gen2
}

// Return new handle with an updated generation.
update_generation :: proc(h: AssetHandle) -> AssetHandle {
    index, generation := split_handle(h)
    generation += 1
    return zip_handle(index, generation)
}

zip_handle :: proc(i: HandleIndex, g: HandleGeneration) -> AssetHandle {
    handle: AssetHandle = auto_cast g
    handle = handle << 32
    handle += auto_cast i
    return handle
}

AssetManager :: struct($T: typeid) {
    free_slots: [dynamic]HandleIndex,
    records: [dynamic]AssetRecord,
    asset_list: [dynamic]Maybe(T),

    // This can be used, if a given asset is associated with a specific name.
    // Asset can be found based on that name (id)
    asset_name: map[string]AssetHandle,
    cleanup: proc(asset: ^T)
}

@(private="file")
DEFAULT_ASSET_CLEANUP := proc(asset: rawptr) {}

ManagerPointer :: rawptr
ManagerRaw :: struct {
    manager_ptr: ManagerPointer,
    manager_cleanup: proc(manager: ManagerPointer),
    manager_delete: proc(manager: ManagerPointer)
}

@(private="file")
all_managers := map[typeid]ManagerRaw {}

make_asset_manager :: proc($AssetType: typeid, cleanup: proc(asset: ^AssetType) = nil) -> ^AssetManager(AssetType) {
    manager_raw, ok := all_managers[AssetType]
    previous_manager: ManagerPointer = nil

    if ok {
        previous_manager = manager_raw.manager_ptr
        fmt.printfln("[WARNING] Asset manager of type '%v' already exists. Overwriting its cleanup...", typeid_of(AssetType))
        (^AssetManager(AssetType))(previous_manager).cleanup = cleanup != nil ? cleanup : (proc(asset: ^AssetType))(DEFAULT_ASSET_CLEANUP)
        return auto_cast previous_manager
    }

    previous_manager = manager_raw.manager_ptr
    
    manager := new_clone(AssetManager(AssetType) {
        records = {},
        asset_list = {},
        asset_name = {},
        cleanup = cleanup != nil ? cleanup : (proc(asset: ^AssetType))(DEFAULT_ASSET_CLEANUP)
    })
    all_managers[AssetType] = ManagerRaw {
        manager_ptr = manager,
        manager_cleanup = proc(manager_ptr: ManagerPointer) {
            manager: ^AssetManager(AssetType) = auto_cast manager_ptr
            for &a in manager.asset_list {
                if a == nil do continue
                manager.cleanup(&a.(AssetType))
            }
        },
        manager_delete = proc(manager_ptr: ManagerPointer) {
            manager: ^AssetManager(AssetType) = auto_cast manager_ptr
            delete_asset_manager(manager)
        },
    }
    return manager
}

get_asset_manager :: proc($T: typeid) -> ^AssetManager(T) {
    manager_raw, ok := all_managers[T]
    if !ok {
        fmt.printfln("[ERROR] Cannot find asset manager of type '%v'!", typeid_of(T))
        return nil
    }
    return auto_cast manager_raw.manager_ptr
}

delete_asset_manager :: proc(manager: ^AssetManager($T)) {
    for &asset in manager.asset_list {
        if asset != nil {
            manager.cleanup(&asset.(T))
        }
    }

    for r in manager.records {
        if r.name != nil do delete(r.name.(string))
    }

    delete(manager.free_slots)
    delete(manager.asset_list)
    delete(manager.records)
    delete(manager.asset_name)
}

append_asset :: proc(manager: ^AssetManager($T), asset: T, asset_name: Maybe(string) = nil) -> AssetHandle {
    next_free_index: HandleIndex
    generation: HandleGeneration;

    create_new := false // This bool is later use to determine if record should be replaced, or appended as new. 
    
    // Check if there are any free slots. If not, mark "create_new" as true.
    // Based on the contition, get the index and generation for new handle.
    if len(manager.free_slots) > 0 {
        next_free_index = manager.free_slots[0]

        record: ^AssetRecord = &manager.records[next_free_index]
        generation = get_generation(record.handle) + 1

        unordered_remove(&manager.free_slots, 0)
    } else {
        next_free_index = auto_cast len(manager.records)
        generation = 0
        create_new = true;
    }

    // Now we can create new/updated record.
    handle := zip_handle(next_free_index, generation)
    new_record := AssetRecord {
        handle = handle,
        name = nil
    }

    // Add name to the record.
    if asset_name != nil {
        // Check if the name is already taken.
        _, is_used := manager.asset_name[asset_name.(string)]
        if is_used {
            fmt.printfln("[ERROR|AssetManager] Asset name '%v' is already in use!", asset_name.(string))
        } else {
            cloned := str.clone(asset_name.(string))
            new_record.name = cloned
            manager.asset_name[cloned] = handle
        }
    }

    if create_new {
        // Append at the end if not reusing existing slot.
        append(&manager.records, new_record)
        append(&manager.asset_list, asset)
    } else {
        // Reusing existing free slot.
        manager.records[next_free_index] = new_record
        manager.asset_list[next_free_index] = asset
    }


    return handle
}

get_asset :: proc(manager: ^AssetManager($T), handle: AssetHandle) -> ^T {
    index, generation := split_handle(handle)

    if auto_cast index >= len(manager.records) {
        fmt.println("[ERROR:AssetManager] Handle is invalid!")
        return nil
    }

    record := manager.records[index]
    record_index, record_generation := split_handle(record.handle)
    
    if record_generation != generation {
        return nil
    }

    return &manager.asset_list[index].(T)
}

get_asset_by_name :: proc(manager: ^AssetManager($T), name: string) -> (^T, AssetHandle) {
    handle, ok := manager.asset_name[name]
    if !ok do return nil, 0
    return &manager.asset_list[get_index(handle)].(T), handle
}

asset_exists :: proc(manager: ^AssetManager($T), name: string) -> Maybe(AssetHandle) {
    handle, ok := manager.asset_name[name]
    return ok ? handle : nil
}

delete_asset :: proc(manager: ^AssetManager($T), handle: AssetHandle) -> bool {
    index, generation := split_handle(handle)

    if auto_cast index >= len(manager.records) {
        fmt.println("[ERROR:AssetManager] Handle is invalid!")
        return false
    }

    if !check_generation(handle, manager.records[index].handle) {
        fmt.println("[WARNING:AssetManager] Handle has wrong generation!")
        return false
    }

    asset := manager.asset_list[index]
    
    if asset == nil {
        fmt.println("[ERROR:AssetManager] Handle is invalid! Probably tried to delete asset twice?")
        return false
    }

    manager.cleanup(&manager.asset_list[index].(T))
    manager.asset_list[index] = nil
    append(&manager.free_slots, index)

    record := &manager.records[index]
    if record.name != nil {
        delete_key(&manager.asset_name, record.name.(string))
        delete(record.name.(string))
        record.name = nil
    }
    record.handle = update_generation(handle)

    return true
}

clear_all_managers :: proc() {
    for handle, manager_raw in all_managers {
        ptr := manager_raw.manager_ptr
        manager_raw.manager_cleanup(ptr)
    }
}

delete_all_managers :: proc() {
    clear_all_managers()

    for handle, manager_raw in all_managers {
        ptr := manager_raw.manager_ptr
        manager_raw.manager_delete(ptr)
    }

    for id, m in all_managers {
        free(m.manager_ptr)
    }
    delete(all_managers)
}
