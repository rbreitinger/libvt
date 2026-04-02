' =============================================================================
' vt_mouse.bas - VT Virtual Text Screen Library
' Mouse enable/disable, coordinate query, cursor appearance.
' =============================================================================

' -----------------------------------------------------------------------------
' vt_mouselock - enable or disable window grab (cursor confined to window)
' Safe to call before or after vt_mouse(1). Takes effect immediately if the
' mouse is already active. Fullscreen modes auto-lock at vt_screen() time.
' -----------------------------------------------------------------------------
Sub vt_mouselock(onoff As Byte)
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_lock = IIf(onoff <> 0, 1, 0)
    If vt_internal.mouse_on Then
        SDL_SetWindowGrab(vt_internal.sdl_window, _
                          IIf(vt_internal.mouse_lock, SDL_TRUE, SDL_FALSE))
    End If
End Sub

' -----------------------------------------------------------------------------
' vt_mouse - enable or disable mouse tracking entirely
' enabled = 1 : hide OS cursor, start tracking, snap char cursor to current pos
' enabled = 0 : restore OS cursor, clear btns and wheel, stop drawing cursor
' -----------------------------------------------------------------------------
Sub vt_mouse(enabled As Byte)
    Dim px As Long
    Dim py As Long

    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_on = IIf(enabled <> 0, 1, 0)

    If enabled Then
        SDL_ShowCursor(SDL_DISABLE)
        If vt_internal.mouse_lock Then
            SDL_SetWindowGrab(vt_internal.sdl_window, SDL_TRUE)
        End If
        ' Snap char cursor to current physical mouse position immediately
        ' so it doesn't sit at (1,1) waiting for the first motion event.
        SDL_GetMouseState(@px, @py)
        vt_internal_pixel_to_cell(px, py, @vt_internal.mouse_col, @vt_internal.mouse_row)
        If vt_internal.mouse_col < 1 Then vt_internal.mouse_col = 1
        If vt_internal.mouse_col > vt_internal.scr_cols Then _
            vt_internal.mouse_col = vt_internal.scr_cols
        If vt_internal.mouse_row < 1 Then vt_internal.mouse_row = 1
        If vt_internal.mouse_row > vt_internal.scr_rows Then _
            vt_internal.mouse_row = vt_internal.scr_rows
    Else
        SDL_SetWindowGrab(vt_internal.sdl_window, SDL_FALSE)
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
