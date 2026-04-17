package ldtk

import "core:fmt"

import z "../"

create_level_mesh :: proc(ldtk: ^LDtk_Data, id: string) {
    level: ^Level
    for &l in ldtk.levels {
        if l.id != id do continue
        level = &l
    }

    if level == nil {
        fmt.printfln("ERROR: cannot create level mesh: Level ID '%v' not found", id)
        return
    }

    for grid in level.int_grids {
        for tile in grid.auto_tiles {
            image_id := z.Image_Resource_ID(grid.tileset_asset_path)
            mesh, ok := z.create_texture_mesh_size_and_src(image_id, {tile.pos.width, tile.pos.height}, tile.src)
            
            if !ok {
                fmt.printfln("ERROR: Cannot create tile from level '%v'!", id)
                z.delete_mesh(&mesh)
                continue
            }

            tile_id := z.create_entity(proc(id: z.Sparse_Index) {
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
    fmt.printfln("INFO: Created mesh for level '%v'", id)
}