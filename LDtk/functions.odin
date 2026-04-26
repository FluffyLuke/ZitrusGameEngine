package ldtk

import "core:fmt"

import z "../"

Area_Index :: int
Bad_Area_Index :: -1
get_area_index :: proc(ldtk: ^LDtk_Data, name: string) -> Area_Index {
    for &a, i in ldtk.areas {
        if a.name != name do continue
        return i
    }
    return Bad_Area_Index
}

get_entity :: proc(ldtk: ^LDtk_Data, area: Area_Index, name: string) -> (Entity_Def, bool) {
    for entity in ldtk.areas[area].entities {
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

create_area_mesh :: proc(ldtk: ^LDtk_Data, index: Area_Index) {
    if index > len(ldtk.areas) - 1 || index < 0 {
        fmt.printfln("ERROR: cannot create area mesh: bad index")
        return
    }

    area := &ldtk.areas[index]
    area_name := area.name

    for grid in area.int_grids {
        for tile in grid.auto_tiles {
            image_id := z.Image_Resource_ID(grid.tileset_asset_path)
            //mesh, ok := z.create_mesh({tile.pos.width, tile.pos.height}, z.rectangle_to_image_source(tile.src, {512, 512}))
            mesh := z.create_mesh({1, 1}, grid.depth)
            // if !ok {
            //     fmt.printfln("ERROR: Cannot create tile mesh from area '%v'!", area_name)
            //     z.delete_mesh(&mesh)
            //     continue
            // }

            ok := z.mesh_set_texture(&mesh, image_id, {tile.src.x, tile.src.y, tile.src.width, tile.src.height})
            if !ok {
                fmt.printfln("ERROR: Cannot set texture for tile mesh from area '%v'!", area_name)
                z.delete_mesh(&mesh)
                continue
            }

            tile_id := z.create_entity({tile.pos.x, tile.pos.y},  on_delete = proc(id: z.Sparse_Index) {
                mesh, _ := z.get_component(id, z.Mesh_2D)
                z.delete_mesh(mesh)
            })

            mesh_ref := z.set_component(tile_id, mesh)
        }
    }
    fmt.printfln("INFO: Created mesh for area '%v'", area_name)
}