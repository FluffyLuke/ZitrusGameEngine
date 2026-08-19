package zitrus

import "core:fmt"
import "core:os"
import "core:time"
import str "core:strings"


MAX_TAGS :: 128
Tag_Mask :: bit_set[0..<MAX_TAGS]
Tag_Index :: distinct int
Tag_Sparse_Set :: Sparse_Set

Tag_Data :: struct {
    next_index: Tag_Index,
    registered: [MAX_TAGS]Maybe(string),

    masks: Tag_Sparse_Set,
    groups: map[Tag_Mask]Entity_ID_Sparse_Set,
}

init_tags :: proc() {
    heart.tags.masks = new_sparse_set(Component_Mask, cleanup = Component_Cleanup_Default)
}

destroy_tags :: proc() {
    heart.tags.masks.destroy_set(&heart.tags.masks)

    defer delete(heart.tags.groups)
    for _, &v in heart.tags.groups {
        v.destroy_set(&v)
    }
}

register_tags :: proc(tag_raw: string) -> (saved_index: Tag_Index) {
    tags := &heart.tags

    if tags.next_index >= MAX_TAGS {
        fmt.println("[ERROR] Cannot register new tag. Limit is reached.")
        return -1
    }

    // Check if tag already exists
    for i in 0..<tags.next_index {
        if tags.registered[i].(string) == tag_raw do return auto_cast i
    }

    tags.registered[tags.next_index] = str.clone(tag_raw)
    saved_index = tags.next_index
    tags.next_index += 1

    return 
}

tag_to_index :: proc(tag_raw: string) -> (Tag_Index, bool) {
    tags := &heart.tags

    for i in 0..<tags.next_index {
        if tags.registered[i].(string) == tag_raw do return auto_cast i, true
    }

    return -1, false
}

view_tags :: proc(indexes: ..Tag_Index) -> (view: View) {
    tags := &heart.tags

    target_mask := Tag_Mask {}
    for mask in indexes do target_mask += {auto_cast mask}
    if target_mask == {} do return
    
    matches := [dynamic]Entity_ID_Sparse_Set {}
    defer delete(matches)
    for group_mask, entities_set in tags.groups {
        if (group_mask & target_mask) == target_mask {
            append(&matches, entities_set)
        }
    }

    for m in matches {
        data: ^Sparse_Set_Data(Entity_ID) = (^Sparse_Set_Data(Entity_ID))(m.data)
        append(&view.entities, ..data.dense[:])
    }

    return
}

set_tag_bitset :: proc(id: Entity_ID, tag_id: Tag_Index, has_it: bool) -> bool {
    tags := &heart.tags
    // Get entity's bit set and remove entity from current group
    bitset_ptr := (^Tag_Mask)(tags.masks.get(&tags.masks, id))
    if bitset_ptr != nil {
        bitset := bitset_ptr^
        group, ok := &tags.groups[bitset]
        if ok {
            group.delete(group, id)
            if group.number_of_items == 0 {
                group.destroy_set(group)
                delete_key(&tags.groups, bitset)
            }
        }
    }
    bitset := bitset_ptr^

    // Treat tag as bit and update bitset
    if has_it {
        bitset += {auto_cast tag_id}
    } else {
        bitset -= {auto_cast tag_id}
    }
    
    // Get entity group (and create it if not existing)
    group, ok := &tags.groups[bitset]
    if !ok {
        tags.groups[bitset] = new_sparse_set(Entity_ID, cleanup = Component_Cleanup_Default)
        group = &tags.groups[bitset]
    }

    // Move entity to new bitset
    id_copy := id
    group.set(group, id, &id_copy)
    tags.masks.set(&tags.masks, id, &bitset)

    return true
}