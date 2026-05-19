' =============================================================================
' vt.bi - VT Virtual Text Screen Library
' Usage: #include once "vt/vt.bi"
' =============================================================================

#Define _FIX_ARTIFACT_ISSUE 
    'fixes artifact issue on HW render BUT needs revisit as
    ' theres something fishy, rarely random crashes on window resize, not certain if lib
    ' related or vtirc related yet.
    ' see: vt_core.bas - vt_present() - line ~1565
    ' ED: I could not reproduce the crash, probably its fine.

#Ifndef BACKEND_VT
    #Include Once "driver/sdl2.bi"
#Else
    #Include Once "driver/fbgfx.bi"
    #Include Once "driver/fbgfx.bas"
#Endif

Enum
    CPNONE = 0
    CP437  = 437
End Enum

'>>>
    ':topic c_misc
    ':short Miscellaneous constants
    ':group Constants
    'Miscellaneous library constants
':params
Const   VT_VERSION   = "1.11.0"   ' major.minor.patch
#Define VT_VER_MAJOR = 1          ' preprocessor Versioning
#Define VT_VER_MINOR = 10
#Define VT_VER_PATCH = 0
Const   VT_VIDEO     = 0          ' the visible display page
Const   VT_DISABLED  = 0          ' generic on/off flags
Const   VT_ENABLED   = 1
#Define VT_NEWLINE     Chr(10)    ' newline for vt_print
#Define VT_LF          VT_NEWLINE ' short alias
':see
    'vt_print
    'vt_copypaste
    'vt_page
    'vt_pcopy
'<<<

'>>>
    ':topic c_winflags
    ':short Window flag constants for vt_screen
    ':group Constants
    'Passed as the flags argument to vt_screen. Combine multiple flags with Or.
':params
Const VT_WINDOWED           = 1   ' Start in a resizable window (default).
Const VT_FULLSCREEN_ASPECT  = 2   ' Fullscreen, integer-scaled, letterboxed.
Const VT_FULLSCREEN_STRETCH = 4   ' Fullscreen, stretches to fill display.
Const VT_NO_RESIZE          = 8   ' Prevent user from resizing the window.
Const VT_VSYNC              = 16  ' Enable vsync, off by default.
Const VT_WINDOWED_MAX       = 32  ' Start regular window maximized.
Const VT_RENDERER_HW        = 64  ' Use HW rendering (default: software).
    ':see 
    'vt_screen
    'c_screenmodes
'<<<

' custom screenmodes
Union vt_screenparam_t
  Type
    w  As ubyte
    h  As ubyte
    fw As ubyte
    fh As ubyte
  End Type
  n As long
End Union

'>>>
':topic c_screenmodes
':short Screen mode constants for vt_screen
':group Constants
'Passed as the mode argument to vt_screen. VT_SCREEN_TILES uses 8x8 font data scaled to 16x16 glyphs - useful for square-cell tiles.
':params
Const VT_SCREEN_0       = 0   ' 80x25  8x16  640x400 - VGA text (default)
Const VT_SCREEN_2       = 2   ' 80x25  8x8   640x200 - CGA hi-res text grid
Const VT_SCREEN_9       = 9   ' 80x25  8x14  640x350 - EGA text grid
Const VT_SCREEN_12      = 12  ' 80x30  8x16  640x480 - VGA hi-res text grid
Const VT_SCREEN_13      = 13  ' 40x25  8x8   320x200 - VGA Mode 13h text grid
Const VT_SCREEN_EGA43   = 43  ' 80x43  8x8   640x344 - EGA 43-line
Const VT_SCREEN_VGA50   = 50  ' 80x50  8x8   640x400 - VGA 50-line
Const VT_SCREEN_TILES   = 100 ' 40x25  16x16 640x400 - square tiles, game-friendly
Const VT_SCREEN_100_40  = 200 ' 100x40 8x16  800x640 - hi-res wide
Const VT_SCREEN_100_50  = 201 ' 100x50 8x8   800x400 - hi-res wide packed
Const VT_SCREEN_120_45  = 300 ' 120x45 8x16  960x720 - hi-res ultrawide
Const VT_SCREEN_120_50  = 301 ' 120x50 8x8   960x400 - hi-res ultrawide packed
'
#define VT_SCREENPARAM(_p...) type<vt_screenparam_t>(_p).n ' custom mode
':syntax
'VT_SCREENPARAM(col, row, fontwid, fonthei) 
'
':notes
'  supports up to 255×255 cells. 
'  fontwid and fonthei select the destination glyph cell size in pixels.
' 
'  Scaled font support: 
'    fontwid must be a multiple of 8. 
'    The library derives scale = fontwid \ 8 and base_gh = fonthei \ scale. 
'    base_gh must equal 8, 14, or 16 (a built-in source font).
'    Invalid combinations silently fall back to the 8×16 source at scale 1.
'   
':see
'vt_screen
'c_winflags
'<<<

Static Shared vt_default_palette(47) As UByte = { _
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

'>>>
    ':topic c_colors
    ':short Color index constants (0-15 + VT_BLINK)
    ':group Constants
    'Used with vt_color, vt_cls, vt_set_cell etc. These are VT_COLOR_IDX enum values 0-15. 
    'OR any foreground color with VT_BLINK (16) to enable character blinking.
    '
':params
Enum
    VT_BLACK          ' 0
    VT_BLUE           ' 1
    VT_GREEN          ' 2
    VT_CYAN           ' 3
    VT_RED            ' 4
    VT_MAGENTA        ' 5
    VT_BROWN          ' 6
    VT_LIGHT_GREY     ' 7
    VT_DARK_GREY      ' 8
    VT_BRIGHT_BLUE    ' 9
    VT_BRIGHT_GREEN   ' 10
    VT_BRIGHT_CYAN    ' 11
    VT_BRIGHT_RED     ' 12  
    VT_BRIGHT_MAGENTA ' 13
    VT_YELLOW         ' 14
    VT_WHITE          ' 15
    VT_BLINK          ' 16 
End Enum
'
':example
    ''Blinking red warning text :
    ' vt_screen()
    ' vt_color(VT_RED Or VT_BLINK)
    ' vt_print("Warning, are you sure?")
    ' vt_sleep()
    ' vt_shutdown()
    ':see
    'vt_color
    'vt_cls
    'vt_set_cell
'<<<

'>>>
':topic c_keymacros
':short Key-event extraction macros
':group Constants
'vt_inkey and vt_getkey return a packed ULong. Use these macros to extract fields from it.

':params
#Define VT_CHAR(k)    ((k) And &hFF)
'  ASCII code of the resulting character (Ctrl+letter gives 1-26). 0 for special keys - use VT_SCAN for those.
'
#Define VT_SCAN(k)    (((k) Shr 16) And &hFFF)
'  VT scancode (bits 16-27). Only meaningful for VT_KEY_* constants. Returns 0 for regular letter/digit/symbol keys.
'  Always compare via this macro.
'
#Define VT_REPEAT(k)  (((k) Shr 28) And 1)
'  1 if this is an auto-repeat event.
'
#Define VT_SHIFT(k)   (((k) Shr 29) And 1)
'  1 if Shift was held.
'
#Define VT_CTRL(k)    (((k) Shr 30) And 1)
'  1 if Ctrl was held.
'
#Define VT_ALT(k)     (((k) Shr 31) And 1)
'  1 if Alt was held.
'

':example
    'Dim k As ULong = vt_getkey()
    'Select Case VT_SCAN(k)
    '    Case VT_KEY_UP    : ' move up
    '    Case VT_KEY_DOWN  : ' move down
    '    Case VT_KEY_ENTER : ' confirm
    '    Case Else
    '        If VT_CHAR(k) = Asc("q") Then End
    'End Select
    ':see
    'vt_inkey
    'vt_getkey
    'c_keyscans
'<<<

'>>>
':topic c_keyscans
':short VT_KEY_* scancode constants
':group Constants
'Compare these against VT_SCAN(k). Never compare them directly against the raw ULong value returned by vt_inkey.
':params
'F-keys:
Const VT_KEY_F1     = 59
Const VT_KEY_F2     = 60
Const VT_KEY_F3     = 61
Const VT_KEY_F4     = 62
Const VT_KEY_F5     = 63
Const VT_KEY_F6     = 64
Const VT_KEY_F7     = 65
Const VT_KEY_F8     = 66
Const VT_KEY_F9     = 67
Const VT_KEY_F10    = 68
Const VT_KEY_F11    = 133
Const VT_KEY_F12    = 134
'
'Navigation:
Const VT_KEY_UP     = 72
Const VT_KEY_DOWN   = 80
Const VT_KEY_LEFT   = 75
Const VT_KEY_RIGHT  = 77
Const VT_KEY_HOME   = 71
Const VT_KEY_END    = 79
Const VT_KEY_PGUP   = 73
Const VT_KEY_PGDN   = 81
Const VT_KEY_INS    = 82
Const VT_KEY_DEL    = 83
'
'Special:
Const VT_KEY_ESC    = 1
Const VT_KEY_ENTER  = 28
Const VT_KEY_BKSP   = 14
Const VT_KEY_TAB    = 15
Const VT_KEY_SPACE  = 57
Const VT_KEY_LSHIFT = 42
Const VT_KEY_RSHIFT = 54
Const VT_KEY_LCTRL  = 29
Const VT_KEY_RCTRL  = 157
Const VT_KEY_LALT   = 56
Const VT_KEY_RALT   = 184
Const VT_KEY_LWIN   = 219
Const VT_KEY_RWIN   = 220
'
':see
'c_keymacros
'vt_inkey
'vt_getkey
'vt_key_held
'<<<

'>>>
    ':topic c_mousebtns
    ':short Mouse button bitmask constants
    ':group Constants
    'Bitmask values returned in the btns parameter of vt_getmouse.
':params
Const VT_MOUSE_BTN_LEFT   = 1   ' bit 0
Const VT_MOUSE_BTN_RIGHT  = 2   ' bit 1
Const VT_MOUSE_BTN_MIDDLE = 4   ' bit 2
':example
    'Dim mb As Long
    'vt_getmouse( , , @mb)
    'If mb And VT_MOUSE_BTN_LEFT Then
    '    ' left button is held
    'End If
    ':see
    'vt_getmouse
    'vt_mouse
'<<<

' Internal tuning constants
Const _VT_KEY_BUFFER_SIZE    = 64
Const _VT_BLINK_MS           = 450
Const _VT_PAGE_SLOTS         = 8    ' max allocatable pages (0=VT_VIDEO, 1..7 work pages)
Const _VT_KEY_REPEAT_INITIAL = 400
Const _VT_KEY_REPEAT_RATE    = 30
Const _VT_CP_SCROLL_MS       = 150  ' ms between auto-scroll steps during drag selection

' vt_cell - one character cell on the virtual screen
Type vt_cell
    ch  As UByte
    fg  As UByte
    bg  As ubyte
End Type

' vt_internal_state - complete internal library state
Type vt_internal_state
    ' --- (SDL) handles ---
    sdl_window   As _VT_DRV_Window Ptr
    sdl_renderer As _VT_DRV_Renderer Ptr
    sdl_texture  As _VT_DRV_Texture Ptr
    sdl_buffer   As _VT_DRV_Texture Ptr

    ' --- screen geometry ---
    scr_cols    As Long
    scr_rows    As Long
    glyph_w     As Long
    glyph_h     As Long

    ' --- font ---
    font_ptr    As UByte Ptr   ' points to active font data array
    font_src_h  As Long        ' source glyph height

    ' --- cell buffer ---
    ' cells always points to page_buf(work_page).
    ' All drawing commands write here. vt_page() updates this pointer.
    ' vt_present() reads from page_buf(vis_page) directly, not from cells.
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

    ' --- region ---
    view_top    As Long
    view_bot    As Long
    view_left   As Long
    view_right  As Long

    ' --- scrollback buffer ---
    sb_cells    As vt_cell Ptr
    sb_lines    As Long
    sb_used     As Long
    sb_offset   As Long

    ' --- key event buffer ---
    key_buf(_VT_KEY_BUFFER_SIZE - 1) As ULong
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
    mouse_btns  As Long
    mouse_vis   As Byte    ' 1 = cursor drawn on screen, 0 = hidden
    mouse_wheel As Long    ' accumulated wheel delta, reset on vt_getmouse read
    mouse_lock  As Byte    ' 1 = SDL window grab active

    ' --- pages ---
    ' page_buf holds all allocated cell buffers. Only 0..num_pages-1 are valid.
    ' cells = page_buf(work_page) at all times. vt_present reads page_buf(vis_page).
    page_buf(_VT_PAGE_SLOTS - 1) As vt_cell Ptr
    num_pages   As Long   ' how many pages were allocated at vt_screen() time
    work_page   As Long   ' active drawing page index
    vis_page    As Long   ' visible page index shown by vt_present

    ' --- palette ---
    palette(47) As UByte

    ' --- letterbox border colour ---
    border_r    As UByte
    border_g    As UByte
    border_b    As UByte

    ' --- window title (stored for pre-init vt_title calls) ---
    win_title   As String

    min_win_w As Long   ' pixel floor set by vt_screen_minimum  (0 = unconstrained)
    min_win_h As Long   ' pixel floor set by vt_screen_minimum  (0 = unconstrained)
    max_win_w As Long   ' pixel ceiling set by vt_screen_maximum (0 = unconstrained)
    max_win_h As Long   ' pixel ceiling set by vt_screen_maximum (0 = unconstrained)

    ' --- flags ---
    dirty       As Byte
    ready       As Byte   ' 1 = running, 0 = not init
    init_flags  As Long   ' flags passed to vt_screen (fullscreen mode, grab, etc.)

    ' --- copy/paste ---
    ' cp_flags gates all interception. sel_active = 0 means nothing selected.
    ' Anchor is where the selection started; end moves as user extends it.
    ' sel_dragging tracks LMB held for mouse drag -- independent of mouse_btns.
    ' cp_paste_pend is set by vt_pump and drained by vt_input.
    ' cp_view_* snapshot the viewport at LMB-down; survive LMB-up so highlight
    ' render and build_text can still use them. Cleared to -1 after RMB copy
    ' or vt_copypaste(VT_DISABLED).
    cp_flags       As Long
    sel_active     As Byte
    sel_anchor_col As Long
    sel_anchor_row As Long
    sel_end_col    As Long
    sel_end_row    As Long
    sel_dragging   As Byte
    cp_paste_pend  As Byte
    cp_view_left   As Long   ' snapshot of view_left  at LMB-down, -1 = full
    cp_view_right  As Long   ' snapshot of view_right at LMB-down, -1 = full
    cp_view_top    As Long   ' snapshot of view_top   at LMB-down, -1 = full
    cp_view_bot    As Long   ' snapshot of view_bot   at LMB-down, -1 = full
    cp_scroll_tick As ULong  ' last auto-scroll tick during drag

    ' --- close callback ---
    ' If set, called on _VT_DRV_QUIT instead of the default shutdown+End.
    ' Return 0 = proceed with shutdown. Return 1 = veto (user handles it).
    close_cb As Function() As Byte
End Type

Dim Shared vt_internal As vt_internal_state
#Include Once "vt_font_8x8.bi"
#Include Once "vt_font_8x14.bi"
#Include Once "vt_font_8x16.bi"
#Include Once "vt_utf8.bas"
#Include Once "vt_core.bas"
#Include Once "vt_keyboard.bas"
#Include Once "vt_palette.bas"
#Include Once "vt_pages.bas"
#Include Once "vt_misc.bas"
#Include Once "vt_print.bas"
#Include Once "vt_input.bas"
#Include Once "vt_mouse.bas"
#Include Once "vt_bsave.bas"
#Include Once "vt_copypaste.bas"
#Include Once "vt_font.bas"

#Ifdef VT_USE_FILE
    #Include Once "vt_file.bas"
#Endif
#Ifdef VT_USE_STRINGS
    #include Once "vt_strings.bas"
#Endif
#Ifdef VT_USE_MATH
    #Include Once "vt_math.bas"
#Endif
#Ifdef VT_USE_SOUND
    #Include Once "vt_sound.bas"
#Endif
#Ifdef VT_USE_TUI
    #Include Once "vt_tui.bas"
#Endif
#Ifdef VT_USE_TLS
    #Define VT_USE_NET
#Endif
#Ifdef VT_USE_NET
    #Include Once "vt_net.bas"
#Endif
#Ifdef VT_USE_TLS
    #Include Once "vt_tls.bas"
#Endif

' --- undefine internals ---
#Undef vt_internal_shutdown
#Undef vt_internal_key_push
#Undef vt_internal_sdl_to_vtscan
#Undef vt_internal_blink_update
#Undef vt_internal_init
#Undef vt_internal_present_if_dirty
#Undef vt_internal_scroll_rect
#Undef vt_internal_pixel_to_cell
#Undef vt_internal_display_cellptr
#Undef vt_default_palette
#Undef vt_font_data_8x8
#Undef vt_font_data_8x14
#Undef vt_font_data_8x16
'#Undef vt_internal

' =============================================================================
' additional vth topics below
' =============================================================================
'>>>
    ':topic hk_scrollback
    ':short Internal scrollback navigation key bindings
    ':group Hotkeys
    'VT intercepts these combinations before they reach your program. Scrollback must be enabled
    'with vt_scrollback/vt_scroll_enable for these to have any effect. Any key not listed below exits scrollback and
    'returns to the live view.
    '
    '  Shift+PgUp       Scroll back 1 line
    '  Shift+PgDn       Scroll forward 1 line
    '  Ctrl+Shift+PgUp  Scroll back half a page
    '  Ctrl+Shift+PgDn  Scroll forward half a page
    ':see
    'vt_scrollback
    'vt_scroll
    'vt_scroll_enable
    '<<<

    '>>>
    ':topic hk_copypaste
    ':short Internal copy/paste key and mouse bindings
    ':group Hotkeys
    'Available only when vt_copypaste has been called to enable it.
    '
    '  LMB drag        Select a region. Activates
    '                  only once the mouse moves.
    '  RMB click       Copy selection to clipboard
    '                  and deselect.
    '  MMB click       Paste clipboard (vt_input only)
    '  Shift+Ins       Paste clipboard (vt_input only,
    '                  always available regardless of
    '                  copy/paste mode setting).
    ':see
    'vt_copypaste
    'vt_input
    'vt_tui_menubar_draw
    'hk_alt
    '<<<

    '>>>
    ':topic hk_alt
    ':short Alt+letter intercept for the TUI menubar
    ':group Hotkeys
    'VT intercepts Alt+letter combinations before they reach your program and delivers them to the TUI menubar. 
    'The key event arrives with VT_ALT(k) = 1 and VT_CHAR(k) set to the letter that was pressed. Used by
    'vt_tui_menubar_draw to open a menu group by its first letter.
    ':see
    'vt_tui_menubar_draw
    'c_keymacros
    'hk_copypaste
'<<<
