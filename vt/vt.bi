' =============================================================================
' vt.bi - VT Virtual Text Screen Library
' Usage: #include once "vt/vt.bi"
' =============================================================================

#include once "SDL2/SDL.bi"

#Define VT_NEWLINE  Chr(10)
#Define vt_pump     vt_internal_pump()
#Define vt_pump()   vt_internal_pump()

' -----------------------------------------------------------------------------
' Init flags  (combinable with Or)
' -----------------------------------------------------------------------------
Const VT_WINDOWED           = 1    ' start in a resizable window (default)
Const VT_FULLSCREEN_ASPECT  = 2    ' fullscreen, integer-scaled, black bars to keep ratio
Const VT_FULLSCREEN_STRETCH = 4    ' fullscreen, fills entire display (widescreen feel)
Const VT_NO_RESIZE          = 8    ' prevent manual window resize
Const VT_VSYNC              = 16   ' vsync (locks vt_present to monitor refresh), off by default
                                   
' -----------------------------------------------------------------------------
' Screen mode constants  (shorthand for well-known DOS configurations)
' Passed as first argument to vt_init() instead of explicit cols/rows.
' -----------------------------------------------------------------------------
Enum VT_MODE_LIST
    VT_MODE_80x25 = 1   ' 8x16  glyphs - classic DOS, the default
    VT_MODE_80x43       ' 8x8   glyphs - EGA 43-line
    VT_MODE_80x50       ' 8x8   glyphs - VGA 50-line
    VT_MODE_40x25       ' 16x16 glyphs - wide / chunky like SCREEN 13
End Enum

' -----------------------------------------------------------------------------
' Colour constants  (fg 0-15, bg 0-15, add VT_BLINK to fg for blinking)
' Uses the original DOS / CGA palette - NOT modern CMD colours.
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
' Extraction macros - use these instead of raw bit math:
' -----------------------------------------------------------------------------
#Define VT_CHAR(k)    ((k) And &hFF)           ' ASCII character, 0 if special
#Define VT_SCAN(k)    (((k) Shr 16) And &hFFF) ' VT scancode
#Define VT_REPEAT(k)  (((k) Shr 28) And 1)     ' 1 if auto-repeat event
#Define VT_SHIFT(k)   (((k) Shr 29) And 1)     ' 1 if Shift was held
#Define VT_CTRL(k)    (((k) Shr 30) And 1)     ' 1 if Ctrl was held
#Define VT_ALT(k)     (((k) Shr 31) And 1)     ' 1 if Alt was held

' -----------------------------------------------------------------------------
' VT key scancode constants  (VT_SCAN(k) values - our own namespace, no SDL exposed)
' -----------------------------------------------------------------------------

' Function keys
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

' Navigation cluster
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

' Special keys
Const VT_KEY_ESC   = 1
Const VT_KEY_ENTER = 28
Const VT_KEY_BKSP  = 14
Const VT_KEY_TAB   = 15
Const VT_KEY_SPACE = 57

' Modifier keys (as standalone key events - held-state flags are in VT_SHIFT/CTRL/ALT)
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
' Internal tuning constants  (not part of the public API - subject to change)
' -----------------------------------------------------------------------------
Const VT_KEY_BUFFER_SIZE    = 64    ' circular key event buffer capacity (entries)
Const VT_BLINK_MS           = 533   ' blink half-period in ms (~1.875 Hz, matches DOS)
Const VT_PAGE_SLOTS         = 4     ' number of vt_page_save / vt_page_restore slots
Const VT_KEY_REPEAT_INITIAL = 400   ' default initial key-repeat delay in ms
Const VT_KEY_REPEAT_RATE    = 30    ' default repeat interval in ms after initial delay

' -----------------------------------------------------------------------------
' vt_cell - one character cell on the virtual screen
' -----------------------------------------------------------------------------
Type vt_cell
    ch  As UByte   ' CP437 character code
    fg  As UByte   ' foreground colour 0-15, bit 4 set = blink
    bg  As UByte   ' background colour 0-15
End Type

' -----------------------------------------------------------------------------
' vt_internal_state - complete internal library state
' One Dim Shared instance (vt_internal)
' No other module declares additional globals - everything lives here.
' User code must never access vt_internal directly.
' -----------------------------------------------------------------------------
Type vt_internal_state

    ' --- SDL handles ---
    sdl_window   As SDL_Window Ptr
    sdl_renderer As SDL_Renderer Ptr
    sdl_texture  As SDL_Texture Ptr     ' font glyph texture (white glyphs, transparent bg)
    sdl_font     As SDL_Surface Ptr     ' always 0 after init - surface freed after upload

    ' --- screen geometry ---
    scr_cols    As Long   ' screen width in cells
    scr_rows    As Long   ' screen height in cells
    glyph_w     As Long   ' font glyph width in pixels
    glyph_h     As Long   ' font glyph height in pixels

    ' --- cell buffer ---
    ' heap-allocated array of scr_cols * scr_rows cells, row-major
    ' index = row * scr_cols + col
    cells       As vt_cell Ptr

    ' --- cursor ---
    cur_col     As Long    ' current cursor column (1-based)
    cur_row     As Long    ' current cursor row    (1-based)
    cur_visible As Byte    ' 1 = cursor shown, 0 = hidden
    cur_ch      As UByte   ' cursor glyph (default 219 = solid block)
    
    ' --- active colour ---
    clr_fg      As UByte   ' current foreground (0-15, bit4 = blink)
    clr_bg      As UByte   ' current background (0-15)

    ' --- blink ---
    blink_visible As Byte   ' 1 = blink-on phase, 0 = blink-off phase
    blink_tick    As ULong  ' SDL_GetTicks value at last phase toggle

    ' --- scroll ---
    scroll_on   As Byte   ' 1 = scroll enabled (default), 0 = disabled
    view_top    As Long   ' scroll region top row    (1-based, default 1)
    view_bot    As Long   ' scroll region bottom row (1-based, default scr_rows)

    ' --- scrollback buffer ---
    sb_cells    As vt_cell Ptr
    sb_lines    As Long   ' total scrollback line capacity (0 = disabled)
    sb_used     As Long   ' lines currently stored in scrollback
    sb_offset   As Long   ' lines currently scrolled back (0 = live view)

    ' --- key event buffer (circular, stores ULong vt_inkey values) ---
    key_buf(VT_KEY_BUFFER_SIZE - 1) As ULong
    key_read    As Long   ' read head index
    key_write   As Long   ' write head index
    key_count   As Long   ' entries currently in buffer

    ' --- key repeat tracking ---
    rep_scan    As Long    ' scancode of currently held key (0 = none)
    rep_tick    As ULong   ' SDL_GetTicks when key was first pressed
    rep_last    As ULong   ' SDL_GetTicks of last generated repeat event
    rep_initial As Long    ' initial delay ms  (default VT_KEY_REPEAT_INITIAL)
    rep_rate    As Long    ' repeat interval ms (default VT_KEY_REPEAT_RATE)

    ' --- mouse ---
    mouse_on    As Byte    ' 1 = mouse enabled via vt_mouse_init()
    mouse_col   As Long    ' last known mouse column (1-based)
    mouse_row   As Long    ' last known mouse row    (1-based)
    mouse_ch    As UByte   ' mouse cursor glyph (default 219)
    mouse_fg    As UByte   ' mouse cursor foreground colour
    mouse_bg    As UByte   ' mouse cursor background colour
    mouse_btns  As Long    ' last known button state bitmask

    ' --- page save slots ---
    page_slot(VT_PAGE_SLOTS - 1) As vt_cell Ptr

    ' --- live palette (16 entries x 3 bytes = 48 bytes, R,G,B order) ---
    palette(47) As UByte
    
    ' --- letterbox border colour (shown outside logical viewport on resize) ---
    border_r    As UByte   ' default 0
    border_g    As UByte   ' default 0
    border_b    As UByte   ' default 0

    ' --- dirty flag ---
    ' set by any write to the cell buffer (putch, cls, set_cell, scroll, blink toggle)
    ' cleared by vt_present after flip. vt_inkey skips present when not dirty.
    dirty       As Byte

    ' --- init flag ---
    ready       As Byte   ' 1 = vt_init completed successfully, 0 = not initialised, 2 = quit
End Type

Dim Shared vt_internal As vt_internal_state

#include once "vt_font_8x16.bi"
'#include once "vt_font_8x8.bi"
#include once "vt_core.bas"
#include once "vt_print.bas"

#undef vt_internal
#undef vt_default_palette

' vt_core.bas
#undef vt_internal_key_push
#undef vt_internal_sdl_to_vtscan
#undef vt_internal_pump
#undef vt_internal_blink_update
#undef vt_init_impl
#undef vt_internal_present_if_dirty

' vt_print.bas
#undef vt_internal_scroll_up
#undef vt_internal_putch
