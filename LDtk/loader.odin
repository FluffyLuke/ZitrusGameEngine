package ldtk

import "core:fmt"
import "core:os"
import "core:slice"
import str "core:strings"
import path "core:path/slashpath"
import "core:mem"
import "core:encoding/json"

import z "../"

Layer_IntGrid :: struct {
    tileset_asset_path: string,
    auto_tiles: []Tile,
}

Level :: struct {
    id: string,
    int_grids: []Layer_IntGrid,
}

LDtk_Data :: struct {
    levels: []Level,
}

Tile_Flip :: enum {
    None,
    X,
    Y,
    XY,
}

Tile :: struct {
    id: f32,
    pos: z.Rectangle,
    src: z.Rectangle,
    flip: Tile_Flip,
    alpha: f32,
}

load_level :: proc(relative_path: string) -> (LDtk_Data, bool) {
    path := str.concatenate({z.heart.meta.exe_path, z.ASSET_ROOT, relative_path}, context.temp_allocator)
    data_raw, ok_file := os.read_entire_file_from_path(path, context.temp_allocator)
    
    if ok_file != os.ERROR_NONE {
        fmt.printfln("ERROR: Cannot load level '%v' ...", relative_path)
        fmt.printfln("ERROR: ... full path: '%v'", path)
        return {}, false
    }

    root, err := json.parse(data_raw, allocator = context.temp_allocator)

    if err != nil {
        fmt.printfln("ERROR: Cannot parse world json: %v", err)
        return {}, false
    }

    data := parse_world_json(root, relative_path)

    free_all(context.temp_allocator)
    return data, true
}

parse_world_json :: proc(root: json.Value, relative_path: string) -> LDtk_Data {
    ldtk: LDtk_Data

    levels := root.(json.Object)["levels"].(json.Array)

    ldtk.levels = make([]Level, len(levels))
    for level, i_level in levels {
        level_obj := level.(json.Object)
        current_level := &ldtk.levels[i_level]

        current_level.id = str.clone(level_obj["identifier"].(json.String))
        layers := level_obj["layerInstances"].(json.Array)

        int_grid_layers := make([dynamic]Layer_IntGrid, allocator = context.temp_allocator)

        for layer in layers {
            layer_obj := layer.(json.Object)
            layer_id := layer_obj["__identifier"].(json.String)
            layer_type := layer_obj["__type"].(json.String)
            layer_width:= layer_obj["__cWid"].(json.Float)
            layer_height := layer_obj["__cHei"].(json.Float)
            layer_grid_size := layer_obj["__gridSize"].(json.Float)

            switch layer_type {
                case "IntGrid": {
                    tiles_array := layer_obj["autoLayerTiles"].(json.Array)
                    
                    level_dir := path.dir(relative_path)
                    defer delete(level_dir)

                    layer_data := Layer_IntGrid {
                        tileset_asset_path = str.concatenate({level_dir, "/", layer_obj["__tilesetRelPath"].(json.String)}),
                        auto_tiles = make([]Tile, len(tiles_array))
                    }

                    for tile, i_tile in tiles_array {
                        tile_obj := tile.(json.Object)

                        move_by := -(z.Vec2 { f32(layer_width * layer_grid_size), f32(layer_height * layer_grid_size) } / 2)

                        pos := json_to_vec2(tile_obj["px"])
                        pos += move_by
                        pos.y *= -1
                        pos /= z.PPU

                        src := json_to_vec2(tile_obj["src"])

                        layer_data.auto_tiles[i_tile] = Tile {
                            pos = {pos.x, pos.y, auto_cast layer_grid_size, auto_cast layer_grid_size},
                            src = {src.x, src.y, auto_cast layer_grid_size, auto_cast layer_grid_size},
                            id = f32(tile_obj["t"].(json.Float)),
                            alpha = f32(tile_obj["a"].(json.Float)),
                        }

                        flip_value := i32(tile_obj["f"].(json.Float))
                        switch flip_value {
                            case 0: layer_data.auto_tiles[i_tile].flip = .None
                            case 1: layer_data.auto_tiles[i_tile].flip = .X
                            case 2: layer_data.auto_tiles[i_tile].flip = .Y
                            case 3: layer_data.auto_tiles[i_tile].flip = .XY
                            case: 
                                fmt.printfln("WARNING: Unknown flip value for tile: '%v'. Setting to .None", flip_value)
                                layer_data.auto_tiles[i_tile].flip = .None
                        }
                    }

                    append(&int_grid_layers, layer_data)
                }

                case: {
                    fmt.printfln("WARNING: Unknown layer of '%v' and id '%v'", layer_type, layer_id)
                }
            }
        }

        current_level.int_grids = slice.clone(int_grid_layers[:])
    }
    return ldtk
}

delete_ldtk :: proc(ldtk: LDtk_Data) {
    for level in ldtk.levels {
        for int_grid in level.int_grids {
            delete_string(int_grid.tileset_asset_path)
            delete(int_grid.auto_tiles)
        }
        delete(level.int_grids)
        delete(level.id)
    }
    delete(ldtk.levels)
}

json_to_vec2 :: proc(vec_json: json.Value) -> z.Vec2 {
    return {
        f32(vec_json.(json.Array)[0].(json.Float)),
        f32(vec_json.(json.Array)[1].(json.Float))
    }
}

json_to_vec2int :: proc(vec_json: json.Value) -> z.Vec2Int {
    return {
        i32(vec_json.(json.Array)[0].(json.Integer)),
        i32(vec_json.(json.Array)[1].(json.Integer))
    }
}