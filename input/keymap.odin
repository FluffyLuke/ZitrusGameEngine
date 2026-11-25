package input

import rl "vendor:raylib"

Input_Key :: enum {
    // Letters
    A, B, C, D, E, F, G, H, I, J, K, L, M, 
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    // Numbers
    Num0, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,

    // Function Keys
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,

    // Symbols & Punctuation
    Space, Escape, Enter, Tab, Backspace, Insert, Delete,
    Right, Left, Down, Up,
    Page_Up, Page_Down, Home, End,
    Caps_Lock, Scroll_Lock, Num_Lock, Print_Screen, Pause,

    // Special Characters
    Grave, Minus, Equals, Left_Bracket, Right_Bracket, Backslash,
    Semicolon, Apostrophe, Comma, Period, Slash,

    // Modifiers
    L_Shift, R_Shift, L_Control, R_Control, L_Alt, R_Alt, L_GUI, R_GUI,
}

@(private="package")
INPUT_TO_RAYLIB := [Input_Key]rl.KeyboardKey {
    // Letters
    .A = .A, .B = .B, .C = .C, .D = .D, .E = .E,
    .F = .F, .G = .G, .H = .H, .I = .I, .J = .J,
    .K = .K, .L = .L, .M = .M, .N = .N, .O = .O,
    .P = .P, .Q = .Q, .R = .R, .S = .S, .T = .T,
    .U = .U, .V = .V, .W = .W, .X = .X, .Y = .Y, .Z = .Z,

    // Numbers
    .Num0 = .ZERO, .Num1 = .ONE, .Num2 = .TWO, .Num3 = .THREE, .Num4 = .FOUR,
    .Num5 = .FIVE, .Num6 = .SIX, .Num7 = .SEVEN, .Num8 = .EIGHT, .Num9 = .NINE,

    // Function Keys
    .F1 = .F1, .F2 = .F2, .F3 = .F3, .F4 = .F4, 
    .F5 = .F5, .F6 = .F6, .F7 = .F7, .F8 = .F8,
    .F9 = .F9, .F10 = .F10, .F11 = .F11, .F12 = .F12,

    // Navigation & Controls
    .Space     = .SPACE,
    .Escape    = .ESCAPE,
    .Enter     = .ENTER,
    .Tab       = .TAB,
    .Backspace = .BACKSPACE,
    .Insert    = .INSERT,
    .Delete    = .DELETE,
    .Right     = .RIGHT,
    .Left      = .LEFT,
    .Down      = .DOWN,
    .Up        = .UP,
    .Page_Up   = .PAGE_UP,
    .Page_Down = .PAGE_DOWN,
    .Home      = .HOME,
    .End       = .END,

    // Locks and System
    .Caps_Lock    = .CAPS_LOCK,
    .Scroll_Lock  = .SCROLL_LOCK,
    .Num_Lock     = .NUM_LOCK,
    .Print_Screen = .PRINT_SCREEN,
    .Pause        = .PAUSE,

    // Symbols
    .Grave         = .GRAVE,
    .Minus         = .MINUS,
    .Equals        = .EQUAL,
    .Left_Bracket  = .LEFT_BRACKET,
    .Right_Bracket = .RIGHT_BRACKET,
    .Backslash     = .BACKSLASH,
    .Semicolon     = .SEMICOLON,
    .Apostrophe    = .APOSTROPHE,
    .Comma         = .COMMA,
    .Period        = .PERIOD,
    .Slash         = .SLASH,

    // Modifiers
    .L_Shift   = .LEFT_SHIFT,
    .R_Shift   = .RIGHT_SHIFT,
    .L_Control = .LEFT_CONTROL,
    .R_Control = .RIGHT_CONTROL,
    .L_Alt     = .LEFT_ALT,
    .R_Alt     = .RIGHT_ALT,
    .L_GUI     = .LEFT_SUPER,
    .R_GUI     = .RIGHT_SUPER,
}