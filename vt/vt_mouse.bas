' =============================================================================
' vt_mouse.bas - VT Virtual Text Screen Library
' Mouse enable/disable, coordinate query, cursor appearance.
' =============================================================================

' -----------------------------------------------------------------------------
' vt_mouse - enable or disable mouse tracking entirely
' enabled = 1 : hide OS cursor, start tracking, snap char cursor to current pos
' enabled = 0 : restore OS cursor, clear btns and wheel, stop drawing cursor
' -----------------------------------------------------------------------------
Sub vt_mouse(enabled As Byte)
    Dim px      As Long
    Dim py      As Long
    Dim wnd_w   As Long
    Dim wnd_h   As Long
    Dim log_w   As Long
    Dim log_h   As Long
    Dim scl_x   As Double
    Dim scl_y   As Double
    Dim scl     As Double
    Dim off_x   As Long
    Dim off_y   As Long
    Dim new_col As Long
    Dim new_row As Long

    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_on = IIf(enabled <> 0, 1, 0)

    If enabled Then
        SDL_ShowCursor(SDL_DISABLE)
        ' Snap char cursor to current physical mouse position immediately
        ' so it doesn't sit at (1,1) waiting for the first motion event.
        SDL_GetMouseState(@px, @py)
        SDL_GetWindowSize(vt_internal.sdl_window, @wnd_w, @wnd_h)
        log_w = vt_internal.scr_cols * vt_internal.glyph_w
        log_h = vt_internal.scr_rows * vt_internal.glyph_h
        scl_x = CDbl(wnd_w) / CDbl(log_w)
        scl_y = CDbl(wnd_h) / CDbl(log_h)
        scl   = IIf(scl_x < scl_y, scl_x, scl_y)
        off_x = CLng((wnd_w - log_w * scl) * 0.5)
        off_y = CLng((wnd_h - log_h * scl) * 0.5)
        new_col = CLng((px - off_x) / scl) \ vt_internal.glyph_w + 1
        new_row = CLng((py - off_y) / scl) \ vt_internal.glyph_h + 1
        If new_col < 1 Then new_col = 1
        If new_col > vt_internal.scr_cols Then new_col = vt_internal.scr_cols
        If new_row < 1 Then new_row = 1
        If new_row > vt_internal.scr_rows Then new_row = vt_internal.scr_rows
        vt_internal.mouse_col = new_col
        vt_internal.mouse_row = new_row
    Else
        SDL_ShowCursor(SDL_ENABLE)
        vt_internal.mouse_btns  = 0
        vt_internal.mouse_wheel = 0
    End If

    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_getmouse - read current mouse state (non-blocking)
' All parameters are Long Ptr. Pass 0 to skip any field.
' whl  : accumulated wheel delta since last call (+up / -down), reset on read
' btns : use VT_MOUSE_BTN_LEFT / _RIGHT / _MIDDLE to test bits
' Returns 0 = ok,  -1 = mouse not enabled or library not ready
'
' Examples:
'   vt_getmouse(@mx, @my)           ' position only
'   vt_getmouse(@mx, @my, @mb)      ' position + buttons
'   vt_getmouse(0, 0, 0, @mw)       ' wheel only
'   vt_getmouse(,,@mb)              ' buttons only (FB skips defaulted params)
' -----------------------------------------------------------------------------
Function vt_getmouse(col  As Long Ptr = 0, row  As Long Ptr = 0, _
                     btns As Long Ptr = 0, whl  As Long Ptr = 0) As Byte
    If vt_internal.ready    = 0 Then Return -1
    If vt_internal.mouse_on = 0 Then Return -1
    If col  <> 0 Then *col  = vt_internal.mouse_col
    If row  <> 0 Then *row  = vt_internal.mouse_row
    If btns <> 0 Then *btns = vt_internal.mouse_btns
    If whl  <> 0 Then
        *whl = vt_internal.mouse_wheel
        vt_internal.mouse_wheel = 0
    End If
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_setmouse - set cursor position and/or visibility
' col, row : 1-based cell coords; -1 = keep current
' vis      : 0 = hide cursor, 1 = show cursor; -1 = keep current
' Safe to call when mouse is disabled -- takes effect when re-enabled.
' -----------------------------------------------------------------------------
Sub vt_setmouse(col As Long = -1, row As Long = -1, vis As Byte = -1)
    If vt_internal.ready = 0 Then Exit Sub
    If col <> -1 Then
        If col < 1 Then col = 1
        If col > vt_internal.scr_cols Then col = vt_internal.scr_cols
        vt_internal.mouse_col = col
    End If
    If row <> -1 Then
        If row < 1 Then row = 1
        If row > vt_internal.scr_rows Then row = vt_internal.scr_rows
        vt_internal.mouse_row = row
    End If
    If vis <> -1 Then
        vt_internal.mouse_vis = IIf(vis <> 0, 1, 0)
    End If
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_mousecursor - configure cursor appearance
' ch    : character to draw (default 219 = full block)
' clr   : foreground colour index (default VT_WHITE)
' flags : VT_MOUSE_DEFAULT = draw ch in clr over mouse_bg
'         VT_MOUSE_INVERT  = invert fg/bg of the cell under the cursor
' -----------------------------------------------------------------------------
Sub vt_mousecursor(ch As UByte = 219, clr As UByte = VT_WHITE, _
                   flags As Long = VT_MOUSE_DEFAULT)
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_ch    = ch
    vt_internal.mouse_fg    = clr
    vt_internal.mouse_flags = flags
    vt_internal.dirty = 1
End Sub 