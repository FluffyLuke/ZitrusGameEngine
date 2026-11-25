package graphics

import "core:os"
import "core:fmt"
import str "core:strings"
import fp "core:path/filepath"

import rl "vendor:raylib"

import "../assets"

ASSETS_ROOT :: "./assets/"

Sprite :: struct {
    texture: rl.Texture2D
}

LoadSpriteResultOk :: struct {
    sprite: ^Sprite,
    handle: assets.AssetHandle,
}

load_sprite :: proc(relative_path: string, name: string) -> Maybe(LoadSpriteResultOk) {
    defer free_all(context.temp_allocator)
    sprite_manager := assets.get_asset_manager(Sprite)

    fmt.printfln("[INFO] Loading sprite '%v'", relative_path)
    exe_path, os_err := os.get_executable_directory(context.temp_allocator)
    
    path := str.concatenate({exe_path, ASSETS_ROOT, relative_path}, context.temp_allocator)

    if handle := assets.asset_exists(sprite_manager, name); handle != nil {
        // fmt.printfln("[ERROR] cannot load file '%s' of id '%s', since this id is already used!", relative_path, name)
        s, h := assets.get_asset_by_name(sprite_manager, name)
        return LoadSpriteResultOk {
            sprite = s,
            handle = handle.(assets.AssetHandle),
        }
    }

    // Load proper image
    path_c := str.clone_to_cstring(path, context.temp_allocator)
    texture := rl.LoadTexture(path_c)

    if texture.id <= 0 {
        fmt.printfln("[ERROR] cannot READ texture file '%s' ", relative_path)
        fmt.printfln("[ERROR] ... absolute path to file: '%s'.", path)
        return nil
    }

    sprite := Sprite {
        texture = texture
    }
    handle := assets.append_asset(sprite_manager, sprite, name)
    
    result := LoadSpriteResultOk {
        assets.get_asset(sprite_manager, handle),
        handle,
    }

    fmt.printfln("[INFO] successfully loaded sprite '%v' of id '%v'", relative_path, name)

    return result
}

delete_sprite :: proc(sprite: ^Sprite) {
    rl.UnloadTexture(sprite.texture)
}

get_sprite :: proc(name: string) -> ^Sprite {
    sprite_manager := assets.get_asset_manager(Sprite)
    sprite, _ := assets.get_asset_by_name(sprite_manager, name)
    return sprite
}

load_all_sprites :: proc(relative_path: string) -> bool {
    defer free_all(context.temp_allocator)
    sprite_manager := assets.get_asset_manager(Sprite)

    fmt.printfln("[INFO] Loading all sprites from directory '%v'.", relative_path)
    exe_path, os_err := os.get_executable_directory(context.temp_allocator)
    full_path := str.concatenate({exe_path, ASSETS_ROOT, relative_path}, context.temp_allocator)

    if !os.exists(full_path) {
        fmt.printfln("[ERROR] Cannot load directory '%v' - does not exist!", relative_path)
        return false
    }

    if !os.is_dir(full_path) {
        fmt.printfln("[ERROR] Cannot load directory '%v' - it's not a directory!", relative_path)
        return false
    }

    w := os.walker_create(full_path)
    defer os.walker_destroy(&w)

    for info in os.walker_walk(&w) {
        if path, err := os.walker_error(&w); err != nil {
			fmt.printfln("[Warning] Failed to read '%s' - %s", path, err)
			continue
		}

        if os.is_dir(info.fullpath) do continue
        
        path_to_remove := str.concatenate({exe_path, ASSETS_ROOT}, context.temp_allocator)
        // relative path from assets folder is needed
        path_part := str.trim_prefix(info.fullpath, path_to_remove)

        if result := load_sprite(path_part, info.name); result == nil {
            fmt.printfln("[ERROR] Failed to load texture '%s'!")
        }
    }

    return true
}