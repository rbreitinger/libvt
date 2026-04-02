' =============================================================================
' vt.bi - VT Virtual Text Screen Library
' Usage: #include once "vt/vt.bi"
' =============================================================================

#include once "SDL2/SDL.bi"

#Define VT_NEWLINE  Chr(10)

' -----------------------------------------------------------------------------
' Init flags  (combinable with Or)
' -----------------------------------------------------------------------------
Const VT_WINDOWED           = 1    ' start in a resizable window (default)
Const VT_FULLSCREEN_ASPECT  = 2    ' fullscreen, integer-scaled, black bars
Const VT_FULLSCREEN_STRETCH = 4    ' fullscreen, fills entire display
Const VT_NO_RESIZE          = 8    ' prevent manual window resize
Const VT_VSYNC              = 16   ' vsync, off by default

' -----------------------------------------------------------------------------
' Screen mode constants
' Values match the original QBasic SCREEN numbers where applicable.
' -----------------------------------------------------------------------------
Const VT_SCREEN_0     = 0    ' 80x25  8x16  640x400  -- VGA text (default)
Const VT_SCREEN_2     = 2    ' 80x25  8x8   640x200  -- CGA hi-res text grid
Const VT_SCREEN_9     = 9    ' 80x25  8x14  640x350  -- EGA text grid
Const VT_SCREEN_12    = 12   ' 80x30  8x16  640x480  -- VGA hi-res text grid
Const VT_SCREEN_13    = 13   ' 40x25  8x8   320x200  -- VGA Mode 13h text grid
Const VT_SCREEN_EGA43 = 43   ' 80x43  8x8   640x344  -- EGA 43-line
Const VT_SCREEN_VGA50 = 50   ' 80x50  8x8   640x400  -- VGA 50-line
Const VT_SCREEN_TILES = 100  ' 40x25  16x16 640x400  -- square tiles, game-friendly

' -----------------------------------------------------------------------------
' Colour constants
' -----------------------------------------------------------------------------
Enum VT_COLOR_IDX
    VT_BLACK
    VT_BLUE
    VT_GREEN
    VT_CYAN
    VT_RED
    VT_MAGENTA
    VT_BROWN
    VT_LIGHT_GREY
    VT_DARK_GREY
    VT_BRIGHT_BLUE
    VT_BRIGHT_GREEN
    VT_BRIGHT_CYAN
    VT_BRIGHT_RED
    VT_BRIGHT_MAGENTA
    VT_YELLOW
    VT_WHITE
    VT_BLINK           ' OR with fg to enable blinking  eg. VT_WHITE Or VT_BLINK
End Enum

' -----------------------------------------------------------------------------
' vt_inkey return value layout (ULong, 32 bits)
'
'   Bit  0 -  7 : ASCII character  (0 if non-printable or special key)
'   Bit  8 - 15 : reserved
'   Bit 16 - 27 : VT scancode
'   Bit 28      : repeat flag  (1 = key-held auto-repeat event)
'   Bit 29      : Shift held
'   Bit 30      : Ctrl held
'   Bit 31      : Alt held
'
' Extraction macros:
' -----------------------------------------------------------------------------
#Define VT_CHAR(k)    ((k) And &hFF)
#Define VT_SCAN(k)    (((k) Shr 16) And &hFFF)
#Define VT_REPEAT(k)  (((k) Shr 28) And 1)
#Define VT_SHIFT(k)   (((k) Shr 29) And 1)
#Define VT_CTRL(k)    (((k) Shr 30) And 1)
#Define VT_ALT(k)     (((k) Shr 31) And 1)

' -----------------------------------------------------------------------------
' VT key scancode constants
' -----------------------------------------------------------------------------
Const VT_KEY_F1  = 59
Const VT_KEY_F2  = 60
Const VT_KEY_F3  = 61
Const VT_KEY_F4  = 62
Const VT_KEY_F5  = 63
Const VT_KEY_F6  = 64
Const VT_KEY_F7  = 65
Const VT_KEY_F8  = 66
Const VT_KEY_F9  = 67
Const VT_KEY_F10 = 68
Const VT_KEY_F11 = 133
Const VT_KEY_F12 = 134

Const VT_KEY_UP    = 72
Const VT_KEY_DOWN  = 80
Const VT_KEY_LEFT  = 75
Const VT_KEY_RIGHT = 77
Const VT_KEY_HOME  = 71
Const VT_KEY_END   = 79
Const VT_KEY_PGUP  = 73
Const VT_KEY_PGDN  = 81
Const VT_KEY_INS   = 82
Const VT_KEY_DEL   = 83

Const VT_KEY_ESC   = 1
Const VT_KEY_ENTER = 28
Const VT_KEY_BKSP  = 14
Const VT_KEY_TAB   = 15
Const VT_KEY_SPACE = 57

Const VT_KEY_LSHIFT = 42
Const VT_KEY_RSHIFT = 54
Const VT_KEY_LCTRL  = 29
Const VT_KEY_RCTRL  = 157
Const VT_KEY_LALT   = 56
Const VT_KEY_RALT   = 184
Const VT_KEY_LWIN   = 219
Const VT_KEY_RWIN   = 220

' -----------------------------------------------------------------------------
' Default CGA / DOS palette  - 16 colours, 3 bytes each (R, G, B)
' -----------------------------------------------------------------------------
Dim Shared vt_default_palette(47) As UByte = { _
    0,   0,   0,  _ '  0 Black
    0,   0, 170,  _ '  1 Blue
    0, 170,   0,  _ '  2 Green
    0, 170, 170,  _ '  3 Cyan
  170,   0,   0,  _ '  4 Red
  170,   0, 170,  _ '  5 Magenta
  170,  85,   0,  _ '  6 Brown
  170, 170, 170,  _ '  7 Light Grey
   85,  85,  85,  _ '  8 Dark Grey
   85,  85, 255,  _ '  9 Bright Blue
   85, 255,  85,  _ ' 10 Bright Green
   85, 255, 255,  _ ' 11 Bright Cyan
  255,  85,  85,  _ ' 12 Bright Red
  255,  85, 255,  _ ' 13 Bright Magenta
  255, 255,  85,  _ ' 14 Yellow
  255, 255, 255   _ ' 15 White
}

' -----------------------------------------------------------------------------
' Internal tuning constants
' -----------------------------------------------------------------------------
Const VT_KEY_BUFFER_SIZE    = 64
Const VT_BLINK_MS           = 533
Const VT_PAGE_SLOTS         = 4
Const VT_KEY_REPEAT_INITIAL = 400
Const VT_KEY_REPEAT_RATE    = 30

' -----------------------------------------------------------------------------
' Mouse cursor style flags
' -----------------------------------------------------------------------------
Const VT_MOUSE_DEFAULT = 0   ' draw cursor char in fixed fg colour
Const VT_MOUSE_INVERT  = 1   ' invert fg/bg of the cell under the cursor

' -----------------------------------------------------------------------------
' Mouse button bitmask constants  (vt_getmouse btns param)
' -----------------------------------------------------------------------------
Const VT_MOUSE_BTN_LEFT   = 1   ' bit 0
Const VT_MOUSE_BTN_RIGHT  = 2   ' bit 1
Const VT_MOUSE_BTN_MIDDLE = 4   ' bit 2

' -----------------------------------------------------------------------------
' vt_cell - one character cell on the virtual screen
' -----------------------------------------------------------------------------
Type vt_cell
    ch  As UByte
    fg  As UByte
    bg  As UByte
End Type

' -----------------------------------------------------------------------------
' vt_internal_state - complete internal library state
' -----------------------------------------------------------------------------
Type vt_internal_state

    ' --- SDL handles ---
    sdl_window   As SDL_Window Ptr
    sdl_renderer As SDL_Renderer Ptr
    sdl_texture  As SDL_Texture Ptr
    sdl_font     As SDL_Surface Ptr    ' always 0 after init

    ' --- screen geometry ---
    scr_cols    As Long
    scr_rows    As Long
    glyph_w     As Long
    glyph_h     As Long

    ' --- font ---
    font_ptr    As UByte Ptr   ' points to active font data array
    font_src_h  As Long        ' source glyph height: 8, 14, or 16

    ' --- cell buffer ---
    cells       As vt_cell Ptr

    ' --- cursor ---
    cur_col     As Long
    cur_row     As Long
    cur_visible As Byte
    cur_ch      As UByte

    ' --- active colour ---
    clr_fg      As UByte
    clr_bg      As UByte

    ' --- blink ---
    blink_visible As Byte
    blink_tick    As ULong

    ' --- scroll ---
    scroll_on   As Byte
    view_top    As Long
    view_bot    As Long

    ' --- scrollback buffer ---
    sb_cells    As vt_cell Ptr
    sb_lines    As Long
    sb_used     As Long
    sb_offset   As Long

    ' --- key event buffer ---
    key_buf(VT_KEY_BUFFER_SIZE - 1) As ULong
    key_read    As Long
    key_write   As Long
    key_count   As Long

    ' --- key repeat ---
    rep_scan    As Long
    rep_tick    As ULong
    rep_last    As ULong
    rep_initial As Long
    rep_rate    As Long

    ' --- mouse ---
    mouse_on    As Byte
    mouse_col   As Long
    mouse_row   As Long
    mouse_ch    As UByte
    mouse_fg    As UByte
    mouse_bg    As UByte
    mouse_btns  As Long
    mouse_vis   As Byte    ' 1 = cursor drawn on screen, 0 = hidden
    mouse_wheel As Long    ' accumulated wheel delta, reset on vt_getmouse read
    mouse_flags As Long    ' VT_MOUSE_DEFAULT or VT_MOUSE_INVERT

    ' --- page save slots ---
    page_slot(VT_PAGE_SLOTS - 1) As vt_cell Ptr

    ' --- palette ---
    palette(47) As UByte

    ' --- letterbox border colour ---
    border_r    As UByte
    border_g    As UByte
    border_b    As UByte

    ' --- window title (stored for pre-init vt_title calls) ---
    win_title   As String

    ' --- flags ---
    dirty       As Byte
    ready       As Byte   ' 1 = running, 0 = not init

End Type

Dim Shared vt_internal As vt_internal_state

#include once "vt_font_8x8.bi"
#include once "vt_font_8x14.bi"
#include once "vt_font_8x16.bi"

#include once "vt_core.bas"
#include once "vt_print.bas"
#include once "vt_input.bas"
#include once "vt_mouse.bas"

' --- undef internals so nothing leaks into user sources ---
'#undef vt_internal <-- we cannot undef this one as the destructor needs it live
#undef vt_default_palette
#undef vt_font_data_8x8
#undef vt_font_data_8x14
#undef vt_font_data_8x16

' vt_core.bas
#undef vt_internal_shutdown
#undef vt_internal_key_push
#undef vt_internal_sdl_to_vtscan
#undef vt_internal_blink_update
#undef vt_init_impl
#undef vt_internal_present_if_dirty

' vt_print.bas
#undef vt_internal_scroll_up
#undef vt_internal_putch
