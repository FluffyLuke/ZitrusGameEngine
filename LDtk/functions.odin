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
            mesh, ok := z.create_texture_mesh_size_and_src(image_id, {tile.pos.width, tile.pos.height}, tile.src)
            
            if !ok {
                fmt.printfln("ERROR: Cannot create tile from area '%v'!", area_name)
                z.delete_mesh(&mesh)
                continue
            }

            tile_id := z.create_entity(on_delete = proc(id: z.Sparse_Index) {
                mesh, _ := z.get_component(id, z.Mesh_2D)
                z.delete_mesh(mesh)
            })

            mesh_ref := z.set_component(tile_id, mesh)

            // rotation_vector: z.Vec3
            // switch tile.flip {
            //     case .None: rotation_vector = {0,0,0}
            //     case .X:    rotation_vector = {0,0,0}
            //     case .Y:    rotation_vector = {0,0,0}
            //     case .XY:   rotation_vector = {0,0,90}
            // }

            // z.set_rotation(tile_id, rotation_vector)
            z.set_position(tile_id, {tile.pos.x, tile.pos.y,0})
        }
    }
    fmt.printfln("INFO: Created mesh for area '%v'", area_name)
}