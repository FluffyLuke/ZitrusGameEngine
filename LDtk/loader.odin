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

Entity_Reference :: struct {
    entity_iid: string,
    layer_iid: string,
    level_iid: string,
    world_iid: string,
    entity_def_ptr: Entity_Def,
}

Entity_Def :: struct {
    is_attribute: bool,
    parent: z.Entity_Properties_Ref,
    internal_id: string,
    name: string,
    color: z.Vec3,
    pos: z.Vec3,
    width: f32,
    height: f32,
    tags: [dynamic]string,
    values_vec2: map[string]z.Vec2,
    values_ints: map[string]i64,
    values_floats: map[string]f64,
    values_strings: map[string]string,
    // References to other objects (iids)
    // references: [dynamic]string,
}

Level :: struct {
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
    levels: []Level,
}

Tile :: struct {
    id: f32,
    pos: z.Rectangle,
    src: z.Rectangle,
    flip: z.Mesh_Flip,
    alpha: f32,
}

load_world :: proc(relative_path: string) -> (map[z.Level_ID]z.Level, bool) {
    defer free_all(context.temp_allocator)

    exe_path, os_err := os.get_executable_directory(context.temp_allocator)
    if os_err != os.ERROR_NONE {
        fmt.printfln("[ERROR] Cannot load executable's path: %s", os_err)
        os.exit(-1)
    }

    path := str.concatenate({exe_path, z.ASSET_ROOT, relative_path}, context.temp_allocator)
    data_raw, ok_file := os.read_entire_file_from_path(path, context.temp_allocator)
    
    if ok_file != os.ERROR_NONE {
        fmt.printfln("[ERROR] Cannot load world '%v' ...", relative_path)
        fmt.printfln("[ERROR] ... full path: '%v'", path)
        return {}, false
    }

    root, err := json.parse(data_raw, allocator = context.temp_allocator)

    if err != nil {
        fmt.printfln("[ERROR] Cannot parse world json: %v", err)
        return {}, false
    }

    data := parse_world_json(root, relative_path)
    defer delete_ldtk(&data)
    
    parsed_levels := make(map[z.Level_ID]z.Level)
    for l in data.levels {
        level_parsed: z.Level
        level_parsed.label = auto_cast str.clone(l.name)

        // Set default (empty) functions
        level_parsed.start = proc(^z.Level) {}
        level_parsed.update = proc(^z.Level, f64) {}
        level_parsed.end = proc(^z.Level) {}

        for e in l.entities {
            entity_parsed := z.Entity_Default_Properties {
                parent = e.parent,
                position = e.pos,
                scale = z.Vec3 {1, 1, 1},
                rotation = quaternion128(1+0i+0j+0k)
            }

            for t in e.tags do append(&entity_parsed.tags, str.clone(t))
            for k, v in e.values_vec2 do entity_parsed.values.vec2[str.clone(k)] = v
            for k, v in e.values_ints do entity_parsed.values.ints[str.clone(k)] = v
            for k, v in e.values_floats do entity_parsed.values.floats[str.clone(k)] = v
            for k, v in e.values_strings do entity_parsed.values.strings[str.clone(k)] = str.clone(v)

            level_parsed.entities[str.clone(e.internal_id)] = entity_parsed
        }

        parsed_levels[level_parsed.label] = level_parsed
    }

    return parsed_levels, true
}



parse_world_json :: proc(root: json.Value, relative_path: string) -> LDtk_Data {
    ldtk: LDtk_Data

    levels_json := root.(json.Object)["levels"].(json.Array)

    ldtk.levels = make([]Level, len(levels_json))
    for level, i_level in levels_json {
        level_obj := level.(json.Object)
        current_area := &ldtk.levels[i_level]

        current_area.name = str.clone(level_obj["identifier"].(json.String))
        layers := level_obj["layerInstances"].(json.Array)

        int_grid_layers := make([dynamic]Layer_IntGrid, allocator = context.temp_allocator)

        // List of entities
        entities := make(map[string]Entity_Def, allocator = context.temp_allocator)

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
                        fmt.printfln("[WARNING] Layer depth is too great for rendering depth. Next layer will use max depth possible ...")
                        fmt.printfln("[WARNING] ... this can lead to tiles overriding each other")
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
                                fmt.printfln("[WARNING] Unknown flip value for tile: '%v'. Setting to .None", flip_value)
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
                            internal_id = str.clone(entity_obj["iid"].(json.String), context.temp_allocator),
                            parent = str.clone(""),
                            is_attribute = false,
                            name = str.clone(entity_obj["__identifier"].(json.String)),
                            color = color,
                            pos = z.Vec3 { entity_pos.x, entity_pos.y, 0 },
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
                            if tag.(json.String) == "Attribute" do entity_def.is_attribute = true
                            append(&entity_def.tags, str.clone(tag.(json.String)))
                        }

                        // Miscellaneous attributes for tags
                        // This values can be overwritten by fields later
                        for t in entity_def.tags {
                            switch(t) {
                                case "Collider":
                                    entity_def.values_vec2[str.clone("_Collider_Size")] = { entity_def.width, entity_def.height }
                                case: {}
                            }
                        }

                        fields_array := entity_obj["fieldInstances"].(json.Array)

                        for field in fields_array {
                            field_obj := field.(json.Object)

                            field_id := field_obj["__identifier"].(json.String)
                            field_type_str := field_obj["__type"].(json.String)

                            if _, ok := field_obj["__value"].(json.Null); ok {
                                fmt.printfln("[WARNING] Value '%v' on entity '%v' is null.", field_id, entity_def.internal_id)
                                continue
                            }
                            
                            switch field_type_str {
                                case "Int":
                                    // For some reason it treats integers as floats? Cast from float to int
                                    entity_def.values_ints[str.clone(field_id)] = i64(field_obj["__value"].(json.Float))
                                case "Float":
                                    value := field_obj["__value"].(json.Float)
                                    
                                    if field_id == "_Depth" {
                                        entity_def.pos.z = f32(value)
                                    } else {
                                        // Default
                                        entity_def.values_floats[str.clone(field_id)] = value
                                    }
                                case "String":
                                    entity_def.values_strings[str.clone(field_id)] = str.clone(field_obj["__value"].(json.String))
                                case "Point":
                                    vec_obj := field_obj["__value"].(json.Object)
                                    x := f32(vec_obj["cx"].(json.Float))
                                    y := f32(vec_obj["cy"].(json.Float))

                                    point := z.Vec2 {x, y}
                                    point += offset
                                    point.y *= -1
                                    point /= f32(layer_grid_size)

                                    entity_def.values_vec2[str.clone(field_id)] = point
                                // Convert it to Vec2 if possible
                                case "Array<Float>":
                                    array_obj := field_obj["__value"].(json.Array)
                                    if len(array_obj) != 2 {
                                        fmt.printfln("[Warning] Too many or too few fields in array. Skipping.")
                                        continue
                                    }
                                    x := f32(array_obj[0].(json.Float))
                                    y := f32(array_obj[1].(json.Float))

                                    size := z.Vec2 {x, y}
                                    // size += offset
                                    // size.y *= -1
                                    // size /= f32(layer_grid_size)

                                    entity_def.values_vec2[str.clone(field_id)] = size
                                case "EntityRef":
                                    ref_obj := field_obj["__value"].(json.Object)
                                    entity_iid := ref_obj["entityIid"].(json.String)
                                    if field_id == "_Parent" {
                                        entity_def.parent = str.clone(entity_iid)
                                    } else {
                                        // append(&entity_def.references, entity_iid)
                                    }
                                case:
                                    fmt.printfln("[WARNING] Unknown field type '%v'.", field_type_str)
                                    continue
                            }
                        }

                        entities[entity_def.internal_id] = entity_def
                    }
                }

                case: {
                    fmt.printfln("[WARNING] Unknown layer of '%v' and id '%v'", layer_type, layer_id)
                }
            }
        }

        current_area.int_grids = slice.clone(int_grid_layers[:])
        entity_slice := make([]Entity_Def, len(entities))
        index := 0
        for iid, entity in entities {
            entity_slice[index] = entity
            index += 1 
        }
        current_area.entities = entity_slice
    }
    return ldtk
}

delete_ldtk :: proc(ldtk: ^LDtk_Data) {
    for lvl in ldtk.levels {
        for int_grid in lvl.int_grids {
            delete_string(int_grid.tileset_asset_path)
            delete(int_grid.auto_tiles)
        }
        for entity in lvl.entities {
            delete_string(entity.name)
            delete_string(entity.parent)

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

        delete(lvl.int_grids)
        delete(lvl.entities)
        delete(lvl.name)
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