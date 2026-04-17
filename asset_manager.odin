package zitrus

import "core:os"
import "core:fmt"
import "core:encoding/json"

import "core:image/png"
import img "core:image"

import str "core:strings"

import gl "vendor:OpenGL"

Asset_Manager :: struct {
    exe_path: String_Ref,
    image_assets: map[Image_Resource_ID]Image_Asset,
    image_assets_pesist: map[Image_Resource_ID]Image_Asset,
}

init_asset_manager :: proc(exe_path: String_Ref) {
    h := get_heart()

    am := &h.asset_manager
    am.exe_path = exe_path
}

get_texture :: proc(id: Image_Resource_ID) -> (Image_Asset, bool) {
    h := get_heart()

    image_asset, ok := h.asset_manager.image_assets[id]

    if ok do return image_asset, true

    image_asset, ok = h.asset_manager.image_assets_pesist[id]

    if !ok do fmt.printfln("ERROR: cannot find texure in asset manager of id: %v", id)

    return image_asset, ok
}

load_texture :: proc(relative_path: string, persist: bool = false) -> (Image_Resource_ID, bool) {
    defer free_all(context.temp_allocator)

    h := get_heart()
    am := &h.asset_manager

    fmt.printfln("INFO: Loading texture '%v'", relative_path)
    
    path := str.concatenate({am.exe_path, ASSET_ROOT, relative_path}, context.temp_allocator)
    // path_meta := str.concatenate({path, ".meta"}, context.temp_allocator)

    // metadata, ok_file := os.read_entire_file_from_path(path_meta, context.temp_allocator)
    // if ok_file != os.ERROR_NONE {
    //     fmt.printfln("ERROR: cannot FIND meta file for '%s': %s ...", relative_path, ok_file)
    //     fmt.printfln("ERROR: ... absolute path to meta file: '%s'", path_meta)
    //     return "", false
    // }

    // json_val, ok_parse := json.parse(metadata, allocator = context.temp_allocator)
    // if ok_parse != .None {
    //     fmt.printfln("ERROR: cannot FORMAT meta file for '%s': %s", relative_path, ok_parse)
    //     return "", false
    // }

    // root := json_val.(json.Object)
    // data_content, data_err := root["data"]

    // if data_err {
    //     fmt.printfln("ERROR: cannot FORMAT meta file for '%s': %s", relative_path, "'data' object is incorrect or missing")
    // }

    asset: Image_Asset

    // TODO: Bring back meta files in the future
    asset_id := Image_Resource_ID(str.clone(relative_path))
    // asset_id := Image_Resource_ID(root["id"].(json.String))
    _, asset_found := am.image_assets[asset_id]
    _, asset_found_persist := am.image_assets_pesist[asset_id]

    if asset_found || asset_found_persist {
        fmt.printfln("ERROR: cannot load file '%s' of id '%s', since this id is already used", relative_path, asset_id)
        return "", false
    }

    // asset_meta: Image_Asset_Metadata_Single
    // error := json.unmarshal(metadata, &asset_meta, allocator = context.temp_allocator)
    // if error != nil {
    //     fmt.printfln("ERROR: cannot FORMAT file for '%s': %s", relative_path, error)
    //     return "", false
    // }
    //asset.id = Image_Resource_ID(str.clone(asset_meta.id))

    asset.id = asset_id

    // switch root["type"].(json.String) {
    //     case "single": {
    //         asset_meta: Image_Asset_Metadata_Single
    //         error := json.unmarshal(metadata, &asset_meta, allocator = context.temp_allocator)
    //         if error != nil {
    //             fmt.printfln("ERROR: cannot FORMAT file for '%s': %s", relative_path, error)
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
    //             fmt.printfln("ERROR: cannot FORMAT meta file for '%s': %s", relative_path, error)
    //             return "", false
    //         }
    //         asset.id = Image_Resource_ID(str.clone(asset_meta.id))
    //         asset.type = Image_Multiple {
    //             shots = asset_meta.shots
    //         }
    //     }
    // }

    // Load proper image
    texture, err := img.load_from_file(path, {})
    defer img.destroy(texture)

    if err != nil {
        fmt.printfln("ERROR: cannot READ texture file '%s': %s ... ", relative_path, err)
        fmt.printfln("ERROR: ... absolute path to file: '%s'", path)
        delete_string(string(asset.id))
        return "", false
    }

    asset.dimensions = {auto_cast texture.width, auto_cast texture.height}

    gl.GenTextures(1, &asset.texture_id)
    gl.BindTexture(gl.TEXTURE_2D, asset.texture_id)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    format: u32 = gl.RGB
    if texture.channels == 4 {
        format = gl.RGBA
    }

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0, i32(format),
        i32(texture.width),
        i32(texture.height),
        0,
        format,
        gl.UNSIGNED_BYTE,
        raw_data(texture.pixels.buf)
    
    )
    gl.GenerateMipmap(gl.TEXTURE_2D)

    id_cloned := Image_Resource_ID(str.clone(string(asset_id)))
    
    if persist do am.image_assets_pesist[id_cloned] = asset
    else do am.image_assets[id_cloned] = asset

    fmt.printfln("INFO: successfully loaded texture '%v' of id '%v'", relative_path, id_cloned)

    return id_cloned, true
}

asset_manager_unload_textures :: proc(also_persist: bool) {
    h := get_heart()
    am := &h.asset_manager

    for k, &image in am.image_assets {
        fmt.printfln("INFO: deleting texture: %s", image.id)
        delete_string(string(k))
        delete_string(string(image.id))
        gl.DeleteTextures(1, &image.texture_id)
    }
    clear(&am.image_assets)


    if also_persist {
        for k, &image in am.image_assets_pesist {
            fmt.printfln("INFO: deleting texture: %s", image.id)
            delete_string(string(k))
            delete_string(string(image.id))
            gl.DeleteTextures(1, &image.texture_id)
        }
        clear(&am.image_assets_pesist)
    }

    fmt.printfln("INFO: deleted all image assets")
}

destroy_asset_manager :: proc() {
    h := get_heart()

    fmt.println("INFO: Destroying asset manager...")
    fmt.printfln("INFO: Number of image assets left: %v", len(h.asset_manager.image_assets))
    fmt.printfln("INFO: Number of persisting image assets left: %v", len(h.asset_manager.image_assets_pesist))

    delete_map(h.asset_manager.image_assets)
    delete_map(h.asset_manager.image_assets_pesist)
}