package zitrus

Vector4 :: [4]f32
Vector3 :: [3]f32
Vector2 :: [2]f32

String_Ref :: string

Rectangle :: struct {
    x: f32      `json:"x"`, 
    y: f32      `json:"y"`,
    width: f32  `json:"w"`,
    height: f32 `json:"h"`,
}