package ldtk

import "core:fmt"

import z "../"

Level_Index :: int
Bad_Area_Index :: -1
get_area_index :: proc(ldtk: ^LDtk_Data, name: string) -> Level_Index {
    for &a, i in ldtk.levels {
        if a.name != name do continue
        return i
    }
    return Bad_Area_Index
}

get_entity :: proc(ldtk: ^LDtk_Data, level: Level_Index, name: string) -> (Entity_Def, bool) {
    for entity in ldtk.levels[level].entities {
        if entity.name == name do return entity, true
    }
    return {}, false
}

entity_get_f64 :: proc(entity: Entity_Def, value_id: string) -> (f64, bool) {
    return entity.values_floats[value_id]
}

entity_get_vec2 :: proc(entity: Entity_Def, value_id: string) -> (z.Vec2, bool) {
    return entity.values_vec2[value_id]
}

entity_get_i64 :: proc(entity: Entity_Def, value_id: string) -> (i64, bool) {
    return entity.values_ints[value_id]
}

entity_get_string :: proc(entity: Entity_Def, value_id: string) -> (z.String_Ref, bool) {
    return entity.values_strings[value_id]
}