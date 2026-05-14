' =============================================================================
' vt_mouse.bas : mouse set/query functions
' =============================================================================

'>>>
':topic vt_mouselock
':short Confine the mouse cursor to the window
':group Mouse
'Enable or disable window grab, which
'confines the mouse cursor to the window.
'Fullscreen modes enable this automatically at
'vt_screen time. Safe to call before or after
'vt_mouse(1).
':syntax
Sub vt_mouselock(onoff As Byte)
        ':params
        'onoff  1 = lock cursor inside window, 0 = unlock.
        ':see
        'vt_mouse
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_lock = IIf(onoff <> 0, 1, 0)
    If vt_internal.mouse_on Then
        _VT_DRV_SetWindowGrab(vt_internal.sdl_window, _
                          IIf(vt_internal.mouse_lock, _VT_DRV_TRUE, _VT_DRV_FALSE))
    End If
End Sub

'>>>
':topic vt_mouse
':short Enable or disable mouse tracking
':group Mouse
'Enable or disable mouse tracking entirely.
'Enabling hides the OS cursor, starts tracking,
'and snaps the character cursor to the current
'physical mouse position. Disabling restores the
'OS cursor and clears button/wheel state.
':syntax
Sub vt_mouse(enabled As Byte)
        ':params
        'enabled  1 = enable mouse tracking, 0 = disable.
        ':example
        'vt_mouse(1)
        '' ... use vt_getmouse in loop ...
        'vt_mouse(0)
        ':see
        'vt_getmouse
        'vt_setmouse
        'vt_mouselock
    '<<<
    Dim px As Long
    Dim py As Long

    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.mouse_on = IIf(enabled <> 0, 1, 0)

    If enabled Then
        _VT_DRV_ShowCursor(_VT_DRV_DISABLE)
        If vt_internal.mouse_lock Then
            _VT_DRV_SetWindowGrab(vt_internal.sdl_window, _VT_DRV_TRUE)
        End If
        ' Snap char cursor to current physical mouse position immediately
        ' so it doesn't sit at (1,1) waiting for the first motion event.
        _VT_DRV_GetMouseState(@px, @py)
        vt_internal_pixel_to_cell(px, py, @vt_internal.mouse_col, @vt_internal.mouse_row)
        If vt_internal.mouse_col < 1 Then vt_internal.mouse_col = 1
        If vt_internal.mouse_col > vt_internal.scr_cols Then _
            vt_internal.mouse_col = vt_internal.scr_cols
        If vt_internal.mouse_row < 1 Then vt_internal.mouse_row = 1
        If vt_internal.mouse_row > vt_internal.scr_rows Then _
            vt_internal.mouse_row = vt_internal.scr_rows
    Else
        _VT_DRV_SetWindowGrab(vt_internal.sdl_window, _VT_DRV_FALSE)
        _VT_DRV_ShowCursor(_VT_DRV_ENABLE)
        vt_internal.mouse_btns  = 0
        vt_internal.mouse_wheel = 0
    End If

    vt_internal.dirty = 1
End Sub

'>>>
':topic vt_getmouse
':short Non-blocking read of current mouse state
':group Mouse
'Non-blocking read of the current mouse state.
'All parameters are optional pointers; pass 0
'to skip any field. Must enable the mouse first
'with vt_mouse(1). The wheel accumulator resets
'to zero each time it is read. Button state uses
'VT_MOUSE_BTN_* bitmask constants.
':syntax
Function vt_getmouse(col  As Long Ptr = 0, _
                     row  As Long Ptr = 0, _
                     btns As Long Ptr = 0, _
                     whl  As Long Ptr = 0) _
                     As Byte
        ':params
        'col   Receives 1-based column. 0 to skip.
        'row   Receives 1-based row. 0 to skip.
        'btns  Receives button bitmask. 0 to skip.
        'whl   Receives accumulated wheel delta
        '      (+up / -down) since last read. 0 to skip.
        ':notes
        'Return values:
        '   0   OK
        '  -1   Mouse not enabled, or library not ready.
        ':example
        'Dim mx As Long, my As Long, mb As Long
        'vt_getmouse(@mx, @my, @mb)
        '
        '' Read buttons only:
        'Dim mw As Long
        'vt_getmouse(,, @mb)
        ':see
        'vt_mouse
        'vt_setmouse
        'c_mousebtns
    '<<<
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

'>>>
':topic vt_setmouse
':short Set mouse cursor position and visibility
':group Mouse
'Set the character cursor position and/or
'visibility. Coordinates are 1-based. Pass -1
'to leave any field unchanged. Safe to call
'when the mouse is disabled; settings take
'effect when re-enabled.
':syntax
Sub vt_setmouse(col As Long = -1, _
                row As Long = -1, _
                vis As Byte = -1)
        ':params
        'col  Column, 1-based. Clamped to screen bounds.
        '     -1 = keep current.
        'row  Row, 1-based. Clamped to screen bounds.
        '     -1 = keep current.
        'vis  1 = show cursor, 0 = hide, -1 = keep.
        ':see
        'vt_mouse
        'vt_getmouse
    '<<<
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
