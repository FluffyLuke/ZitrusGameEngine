package zitrus

import "core:os"
import "core:fmt"
import "core:encoding/json"
import str "core:strings"
import fp "core:path/filepath"

import rl "vendor:raylib"

Asset_Manager :: struct {
    image_assets: map[Image_Resource_ID]Image_Asset,
    image_assets_pesist: map[Image_Resource_ID]Image_Asset,
}

init_asset_manager :: proc(exe_path: String_Ref) {
    am := &heart.asset_manager

    image_assets := make(map[Image_Resource_ID]Image_Asset)
    image_assets_pesist := make(map[Image_Resource_ID]Image_Asset)
}

get_texture :: proc(id: Image_Resource_ID) -> (Image_Asset, bool) {
    am := &heart.asset_manager

    image_asset, ok := am.image_assets[id]

    if ok do return image_asset, true

    image_asset, ok = am.image_assets_pesist[id]

    if !ok do fmt.printfln("[ERROR] cannot find texure in asset manager of id: %v", id)

    return image_asset, ok
}

load_texture :: proc(relative_path: string, persist: bool = false) -> (Image_Resource_ID, bool) {
    defer free_all(context.temp_allocator)

    am := &heart.asset_manager

    fmt.printfln("[INFO] Loading texture '%v'", relative_path)
    
    path := str.concatenate({heart.meta.exe_path, ASSET_ROOT, relative_path}, context.temp_allocator)
    // path_meta := str.concatenate({path, ".meta"}, context.temp_allocator)

    // metadata, ok_file := os.read_entire_file_from_path(path_meta, context.temp_allocator)
    // if ok_file != os.ERROR_NONE {
    //     fmt.printfln("[ERROR] cannot FIND meta file for '%s': %s ...", relative_path, ok_file)
    //     fmt.printfln("[ERROR] ... absolute path to meta file: '%s'", path_meta)
    //     return "", false
    // }

    // json_val, ok_parse := json.parse(metadata, allocator = context.temp_allocator)
    // if ok_parse != .None {
    //     fmt.printfln("[ERROR] cannot FORMAT meta file for '%s': %s", relative_path, ok_parse)
    //     return "", false
    // }

    // root := json_val.(json.Object)
    // data_content, data_err := root["data"]

    // if data_err {
    //     fmt.printfln("[ERROR] cannot FORMAT meta file for '%s': %s", relative_path, "'data' object is incorrect or missing")
    // }

    asset: Image_Asset

    // TODO: Bring back meta files in the future
    // asset_id := Image_Resource_ID(root["id"].(json.String))

    _, asset_found := am.image_assets[auto_cast relative_path]
    _, asset_found_persist := am.image_assets_pesist[auto_cast relative_path]

    if asset_found || asset_found_persist {
        fmt.printfln("[ERROR] cannot load file '%s' of id '%s', since this id is already used", relative_path, relative_path)
        return "", false
    }

    asset_id := Image_Resource_ID(str.clone(fp.stem(path)))
    asset.asset_id = asset_id

    // asset_meta: Image_Asset_Metadata_Single
    // error := json.unmarshal(metadata, &asset_meta, allocator = context.temp_allocator)
    // if error != nil {
    //     fmt.printfln("[ERROR] cannot FORMAT file for '%s': %s", relative_path, error)
    //     return "", false
    // }
    //asset.id = Image_Resource_ID(str.clone(asset_meta.id))

    // switch root["type"].(json.String) {
    //     case "single": {
    //         asset_meta: Image_Asset_Metadata_Single
    //         error := json.unmarshal(metadata, &asset_meta, allocator = context.temp_allocator)
    //         if error != nil {
    //             fmt.printfln("[ERROR] cannot FORMAT file for '%s': %s", relative_path, error)
    //             return "", false
    //         }
    //         asset.id = Image_Resource_ID(str.clone(asset_meta.id))

    //         asset.type = Image_Single {
    //             shot = asset_meta.shot
    //         }
    //     }
    //     case "multiple": {
    //         asset_meta: Image_Asset_Metadata_Multiple
    //         error := json.unmarshal(metadata, &asset_meta, allocator = context.temp_allocator)
    //         if error != nil {
    //             fmt.printfln("[ERROR] cannot FORMAT meta file for '%s': %s", relative_path, error)
    //             return "", false
    //         }
    //         asset.id = Image_Resource_ID(str.clone(asset_meta.id))
    //         asset.type = Image_Multiple {
    //             shots = asset_meta.shots
    //         }
    //     }
    // }

    // Load proper image
    path_c := str.clone_to_cstring(path, context.temp_allocator)
    texture := rl.LoadTexture(path_c)

    if texture.id <= 0 {
        fmt.printfln("[ERROR] cannot READ texture file '%s' ", relative_path)
        fmt.printfln("[ERROR] ... absolute path to file: '%s'", path)
        delete_string(string(asset.asset_id))
        return "", false
    }
    asset.texture = texture

    // Clone this id for map. Now map and value have their own respected strings
    id_cloned := Image_Resource_ID(str.clone(string(asset_id)))
    
    if persist do am.image_assets_pesist[id_cloned] = asset
    else do am.image_assets[id_cloned] = asset

    fmt.printfln("[INFO] successfully loaded texture '%v' of id '%v'", relative_path, id_cloned)

    return id_cloned, true
}

load_all_textures :: proc(relative_path: string) -> bool {
    defer free_all(context.temp_allocator)
    am := &heart.asset_manager

    fmt.printfln("[INFO] Loading directory '%v'", relative_path)
    asset_path := str.concatenate({heart.meta.exe_path, ASSET_ROOT, relative_path}, context.temp_allocator)

    if !os.exists(asset_path) {
        fmt.printfln("[ERROR] Cannot load directory '%v' - does not exist!", relative_path)
        return false
    }

    if !os.is_dir(asset_path) {
        fmt.printfln("[ERROR] Cannot load directory '%v' - it's not a directory!", relative_path)
        return false
    }

    w := os.walker_create(asset_path)
    defer os.walker_destroy(&w)

    for info in os.walker_walk(&w) {
        if path, err := os.walker_error(&w); err != nil {
			fmt.eprintfln("[ERROR] Failed to read '%s' - %s", path, err)
			continue
		}

        if os.is_dir(info.fullpath) do continue
        
        path_to_remove := str.concatenate({heart.meta.exe_path, ASSET_ROOT}, context.temp_allocator)
        // relative path from assets folder is needed
        path_part := str.trim_prefix(info.fullpath, path_to_remove)

        if _, ok := load_texture(path_part); !ok {
            fmt.eprintfln("[ERROR] Failed to load texture '%s'!")
        }
    }

    return true
}

asset_manager_unload_textures :: proc(also_persist: bool) {
    h := get_heart()
    am := &h.asset_manager

    for k, &image in am.image_assets {
        fmt.printfln("[INFO] deleting texture: %s", image.asset_id)
        delete_string(string(k))
        delete_string(string(image.asset_id))
        rl.UnloadTexture(image)
    }
    clear(&am.image_assets)


    if also_persist {
        for k, &image in am.image_assets_pesist {
            fmt.printfln("[INFO] deleting persisted texture: %s", image.asset_id)
            delete_string(string(k))
            delete_string(string(image.asset_id))
            rl.UnloadTexture(image)
        }
        clear(&am.image_assets_pesist)
    }

    fmt.printfln("[INFO] deleted all image assets")
}

destroy_asset_manager :: proc() {
    h := get_heart()

    fmt.println("[INFO] Destroying asset manager...")
    fmt.printfln("[INFO] Number of image assets left: %v", len(h.asset_manager.image_assets))
    fmt.printfln("[INFO] Number of persisting image assets left: %v", len(h.asset_manager.image_assets_pesist))

    delete_map(h.asset_manager.image_assets)
    delete_map(h.asset_manager.image_assets_pesist)
}