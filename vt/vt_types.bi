' =============================================================================
' vt_types.bi - VT Virtual Text Screen Library
' Cell type and internal state UDT.
' Include via vt.bi only - use: #include once "vt/vt.bi"
' =============================================================================

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
' One Dim Shared instance (vt_internal) lives in vt_core.bas.
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


' -----------------------------------------------------------------------------
' The single shared instance - all VT modules access state through this only
' -----------------------------------------------------------------------------
Dim Shared vt_internal As vt_internal_state
