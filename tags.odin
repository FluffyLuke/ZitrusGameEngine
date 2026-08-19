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

    for i in 0..<heart.tags.next_index {
        delete_string(heart.tags.registered[i].(string))
    }

    defer delete(heart.tags.groups)
    for _, &v in heart.tags.groups {
        v.destroy_set(&v)
    }
}

set_tag :: proc {
    set_tag_index,
    set_tag_string,
}

set_tag_index :: proc(id: Entity_ID, tag: Tag_Index) -> bool {
    return set_tag_bitset(id, tag, true)
}

set_tag_string :: proc(id: Entity_ID, tag_raw: string) -> bool {
    tag_index := register_tag(tag_raw)
    return set_tag_index(id, tag_index)
}

remove_tag :: proc {
    remove_tag_index,
    remove_tag_string,
}

remove_tag_index :: proc(id: Entity_ID, tag: Tag_Index) -> bool {
    return set_tag_bitset(id, tag, false)
}

remove_tag_string :: proc(id: Entity_ID, tag_raw: string) -> bool {
    tag_index := register_tag(tag_raw)
    return remove_tag_index(id, tag_index)
}

register_tag :: proc(tag_raw: string) -> (saved_index: Tag_Index) {
    if index, found := tag_to_index(tag_raw); found {
        return index
    }

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

view_tags_strings :: proc(tags: ..string) -> (view: View) {
    t := &heart.tags

    indexes := make([dynamic]Tag_Index, 0, len(tags))
    defer delete(indexes)

    for tag_str in tags {
        if idx, ok := tag_to_index(tag_str); ok {
            append(&indexes, idx)
        } else {
            fmt.printfln("[Warning] Tag '%v' does not exist in registry.", tag_str)
        }
    }

    return view_tags_indexes(..indexes[:])
}

view_tags_indexes :: proc(indexes: ..Tag_Index) -> (view: View) {
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

set_tag_bitset :: proc(entity_id: Entity_ID, tag_id: Tag_Index, has_it: bool) -> bool {
    tags := &heart.tags
    // Get entity's bit set and remove entity from current group
    bitset_ptr := (^Tag_Mask)(tags.masks.get(&tags.masks, entity_id))
    bitset: Tag_Mask
    if bitset_ptr != nil {
        bitset = bitset_ptr^
        group, ok := &tags.groups[bitset]
        if ok {
            group.delete(group, entity_id)
            if group.number_of_items == 0 {
                group.destroy_set(group)
                delete_key(&tags.groups, bitset)
            }
        }
    } else {
        bitset = {auto_cast tag_id}
    }

    // Treat tag as bit and update bitset
    if has_it {
        bitset += {auto_cast tag_id}
    } else {
        bitset -= {auto_cast tag_id}
    }
    
    // Get tag group (and create it if not existing)
    group, ok := &tags.groups[bitset]
    if !ok {
        tags.groups[bitset] = new_sparse_set(Entity_ID, cleanup = Component_Cleanup_Default)
        group = &tags.groups[bitset]
    }

    // Move entity to new bitset
    id_copy := entity_id
    group.set(group, entity_id, &id_copy)
    tags.masks.set(&tags.masks, entity_id, &bitset)

    return true
}