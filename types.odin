package zitrus

import "core:fmt"

import "core:math"
import "core:math/rand"

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

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