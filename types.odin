package zitrus

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import str "core:strings"
import la "core:math/linalg"

import rl "vendor:raylib"

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

vec3_to_quaternion :: proc(vec: Vec3) -> quaternion128 {
    rad := vec * la.to_radians(f32(1.0))
    return la.quaternion_angle_axis(rad.x, Vec3 {1,0,0}) \
        * la.quaternion_angle_axis(rad.y, Vec3 {0,1,0}) \
        * la.quaternion_angle_axis(rad.z, Vec3 {0,0,1})
}

Vec4Int :: [4]i32
Vec3Int :: [3]i32
Vec2Int :: [2]i32

Forward_Vec :: Vec3 {0, 0, -1}
Up_Vec :: Vec3 {0, 1, 0}

Identity_Matrix :: matrix[4,4]f32 {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
}

String_Ref :: string

Rectangle :: struct {
    x: f32      `json:"x"`, 
    y: f32      `json:"y"`,
    width: f32  `json:"w"`,
    height: f32 `json:"h"`,
}

Circle :: struct {
    x: f32      `json:"x"`, 
    y: f32      `json:"y"`,
    radius: f32 `json:"r"`,
}

get_random_point :: proc(circle: Circle) -> Vec2 {
    how_much := rand.float32_range(0, 2 * math.PI)
    point: Vec2 = {math.sin(how_much), math.cos(how_much)} * circle.radius

    return point + Vec2 {circle.x, circle.y}
}

get_random_point3 :: proc(circle: Circle) -> Vec3 {
    how_much := rand.float32_range(0, 2 * math.PI)
    point: Vec3 = {math.sin(how_much), math.cos(how_much), 0} * circle.radius

    return point + Vec3 {circle.x, circle.y, 0}
}

hex_to_vec3 :: proc(hex_str: string) -> (color: Vec3, ok: bool) {
    clean_hex := str.trim_prefix(hex_str, "#")

    if len(clean_hex) != 6 {
        fmt.printfln("[ERROR] Invalid hex string length. Expected 6, got %v", len(clean_hex))
        return {}, false
    }

    // Parse the string into a single base-16 unsigned integer
    hex_value, parse_ok := strconv.parse_u64(clean_hex, 16)
    if !parse_ok {
        fmt.printfln("[ERROR] Could not parse hex string: %s", hex_str)
        return {}, false
    }

    // Extract the RGB components using bitwise shifts (0 - 255)
    r_byte := f32((hex_value >> 16) & 0xFF)
    g_byte := f32((hex_value >> 8)  & 0xFF)
    b_byte := f32(hex_value         & 0xFF)

    color = {
        r_byte,
        g_byte,
        b_byte,
    }

    return color, true
}

// === Functions for raylib ===

rl_convert_rectangle :: #force_inline proc(rec: Rectangle) -> rl.Rectangle {
    return {
        x = rec.x,
        y = rec.y,
        width = rec.width,
        height = rec.height
    }
}