package ldtk

import "core:fmt"
import "core:os"
import "core:slice"
import str "core:strings"
import path "core:path/slashpath"
import "core:mem"
import "core:encoding/json"

import z "../"

// Add an offset between each layer
LAYER_OFFSET :: 5

Entity_Def :: struct {
    name: string,
    color: z.Vec3,
    pos: z.Vec2,
    width: f32,
    height: f32,
    tags: [dynamic]string,
    values_vec2: map[string]z.Vec2,
    values_ints: map[string]i64,
    values_floats: map[string]f64,
    values_strings: map[string]string,
}

Area :: struct {
    name: string,
    int_grids: []Layer_IntGrid,
    entities: []Entity_Def
}

Layer_IntGrid :: struct {
    depth: uint,
    tileset_asset_path: string,
    auto_tiles: []Tile,
}

LDtk_Data :: struct {
    areas: []Area,
}

Tile :: struct {
    id: f32,
    pos: z.Rectangle,
    src: z.Rectangle,
    flip: z.Mesh_Flip,
    alpha: f32,
}

load_world :: proc(relative_path: string) -> (LDtk_Data, bool) {
    path := str.concatenate({z.heart.meta.exe_path, z.ASSET_ROOT, relative_path}, context.temp_allocator)
    data_raw, ok_file := os.read_entire_file_from_path(path, context.temp_allocator)
    
    if ok_file != os.ERROR_NONE {
        fmt.printfln("ERROR: Cannot load world '%v' ...", relative_path)
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

    areas_json := root.(json.Object)["levels"].(json.Array)

    ldtk.areas = make([]Area, len(areas_json))
    for area, i_area in areas_json {
        area_obj := area.(json.Object)
        current_area := &ldtk.areas[i_area]

        current_area.name = str.clone(area_obj["identifier"].(json.String))
        layers := area_obj["layerInstances"].(json.Array)

        int_grid_layers := make([dynamic]Layer_IntGrid, allocator = context.temp_allocator)
        entities := make([dynamic]Entity_Def, allocator = context.temp_allocator)

        // Depth is assigned to intgrid layers and used layer for rendering
        // It starts from fifth layer, to make room for displaying stuff in front of it
        layer_depth: uint = 4
        for layer in layers {
            layer_obj := layer.(json.Object)
            layer_id := layer_obj["__identifier"].(json.String)
            layer_type := layer_obj["__type"].(json.String)
            layer_width:= layer_obj["__cWid"].(json.Float)
            layer_height := layer_obj["__cHei"].(json.Float)
            layer_grid_size := layer_obj["__gridSize"].(json.Float)

            // Offset is used to center the level (move it back by half x and half y)
            offset := -(z.Vec2 { f32(layer_width * layer_grid_size), f32(layer_height * layer_grid_size) } / 2)

            switch layer_type {
                case "IntGrid": {
                    tiles_array := layer_obj["autoLayerTiles"].(json.Array)
                    
                    world_dir := path.dir(relative_path)
                    defer delete(world_dir)

                    layer_data := Layer_IntGrid {
                        depth = layer_depth,
                        tileset_asset_path = str.concatenate({world_dir, "/", layer_obj["__tilesetRelPath"].(json.String)}),
                        auto_tiles = make([]Tile, len(tiles_array))
                    }

                    layer_depth += LAYER_OFFSET
                    if layer_depth > z.RENDERING_DEPTH {
                        fmt.printfln("WARNING: Layer depth is too great for rendering depth. Next layer will use max depth possible ...")
                        fmt.printfln("WARNING: ... this can lead to tiles overriding each other")
                        layer_depth = z.RENDERING_DEPTH
                    }

                    for tile, i_tile in tiles_array {
                        tile_obj := tile.(json.Object)

                        pos := json_to_vec2(tile_obj["px"])
                        pos += offset
                        pos.y *= -1
                        // Move by half a tile forward and down
                        // This is because tiles have their pivot in top left corner, not center
                        pos += (z.Vec2 {auto_cast layer_grid_size, auto_cast -layer_grid_size} / 2)

                        pos /= f32(layer_grid_size)

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

                case "Entities": {
                    entity_array := layer_obj["entityInstances"].(json.Array)

                    for entity, i_entity in entity_array {
                        entity_obj := entity.(json.Object)

                        entity_pos := json_to_vec2(entity_obj["px"])
                        entity_pos += offset
                        entity_pos.y *= -1
                        entity_pos /= f32(layer_grid_size)

                        width := f32(entity_obj["width"].(json.Float))
                        height := f32(entity_obj["height"].(json.Float))

                        width /= f32(layer_grid_size)
                        height /= f32(layer_grid_size)

                        color, ok_color := z.hex_to_vec3(entity_obj["__smartColor"].(json.String))
                        if !ok_color {
                            color = z.Vec3 {255, 120, 56}
                        }

                        entity_def := Entity_Def {
                            name = str.clone(entity_obj["__identifier"].(json.String)),
                            color = color,
                            pos = entity_pos,
                            width = width,
                            height = height,
                            tags = make([dynamic]string),
                            values_floats = make(map[string]f64),
                            values_ints = make(map[string]i64),
                            values_strings = make(map[string]string),
                            values_vec2 = make(map[string]z.Vec2)
                        }

                        tags_raw := entity_obj["__tags"].(json.Array)

                        for tag in tags_raw {
                            append(&entity_def.tags, str.clone(tag.(json.String)))
                        }

                        fields_array := entity_obj["fieldInstances"].(json.Array)
                        for field in fields_array {
                            field_obj := field.(json.Object)

                            field_id := str.clone(field_obj["__identifier"].(json.String))
                            field_type_str := field_obj["__type"].(json.String)
                            
                            switch field_type_str {
                                case "Int":
                                    // For some reason it treats integers as floats? Cast from float to int
                                    entity_def.values_ints[field_id] = i64(field_obj["__value"].(json.Float))
                                case "Float":
                                    entity_def.values_floats[field_id] = field_obj["__value"].(json.Float)
                                case "String":
                                    entity_def.values_strings[field_id] = str.clone(field_obj["__value"].(json.String))
                                case "Point":
                                    vec_obj := field_obj["__value"].(json.Object)
                                    x := f32(vec_obj["cx"].(json.Float))
                                    y := f32(vec_obj["cy"].(json.Float))

                                    point := z.Vec2 {x, y}
                                    point += offset
                                    point.y *= -1
                                    point /= f32(layer_grid_size)

                                    entity_def.values_vec2[field_id] = point
                                case:
                                    fmt.printfln("WARNING: Unknown field type '%v'", field_type_str)
                                    delete_string(field_id)
                                    continue
                            }
                        }
                        append(&entities, entity_def)
                    }
                }

                case: {
                    fmt.printfln("WARNING: Unknown layer of '%v' and id '%v'", layer_type, layer_id)
                }
            }
        }

        current_area.int_grids = slice.clone(int_grid_layers[:])
        current_area.entities = slice.clone(entities[:])
    }
    return ldtk
}

delete_ldtk :: proc(ldtk: LDtk_Data) {
    for area in ldtk.areas {
        for int_grid in area.int_grids {
            delete_string(int_grid.tileset_asset_path)
            delete(int_grid.auto_tiles)
        }
        for entity in area.entities {
            delete_string(entity.name)

            for k, v in entity.values_strings {
                delete_string(k)
                delete_string(v)
            }

            for k, v in entity.values_ints {
                delete_string(k)
            }
            for k, v in entity.values_floats {
                delete_string(k)
            }
            for k, v in entity.values_vec2 {
                delete_string(k)
            }

            for tag in entity.tags {
                delete_string(tag)
            }

            delete(entity.tags)
            delete_map(entity.values_ints)
            delete_map(entity.values_strings)
            delete_map(entity.values_floats)
            delete_map(entity.values_vec2)
        }

        delete(area.int_grids)
        delete(area.entities)
        delete(area.name)
    }
    delete(ldtk.areas)
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