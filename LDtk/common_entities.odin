package ldtk

import "core:fmt"

import rl "vendor:raylib"

import z "../"

// Load all common things for area
load_area :: proc(ldtk: ^LDtk_Data, index: Area_Index) {
    load_area_mesh(ldtk, index)
    load_lights(ldtk, index)
}

load_area_mesh :: proc(ldtk: ^LDtk_Data, index: Area_Index) {
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

load_lights :: proc(ldtk: ^LDtk_Data, index: Area_Index) {
    if index > len(ldtk.areas) - 1 || index < 0 {
        fmt.printfln("ERROR: cannot create area mesh: bad index")
        return
    }

    area := &ldtk.areas[index]
    area_name := area.name

    for entity in area.entities {
        if entity.name == "LightSource" {
            z.create_light(entity.pos)
        }

        if entity.name == "LightObstruction" {
            color4 := z.Vec4 {
                auto_cast entity.color.x,
                auto_cast entity.color.y,
                auto_cast entity.color.z,
                255/2
            }
            z.create_light_obstruction({entity.pos.x, entity.pos.y, entity.width, entity.height}, color4)
        }
    }
    fmt.printfln("INFO: Loaded lights for area '%v'", area_name)
}