package zitrus

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

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