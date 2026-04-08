' =============================================================================
' vt_pages.bas - VT Page Management and Scrollback
' =============================================================================

' -----------------------------------------------------------------------------
' vt_page - set the active drawing page and the visible display page
' work : page index written to by all drawing commands (0..num_pages-1)
' vis  : page index rendered to screen by vt_present (0..num_pages-1)
' Invalid indices are silently ignored.
' -----------------------------------------------------------------------------
Sub vt_page(work As Long, vis As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If work < 0 Or work >= vt_internal.num_pages Then Exit Sub
    If vis  < 0 Or vis  >= vt_internal.num_pages Then Exit Sub
    vt_internal.work_page = work
    vt_internal.vis_page  = vis
    vt_internal.cells     = vt_internal.page_buf(work)
    vt_internal.dirty     = 1
End Sub

' -----------------------------------------------------------------------------
' vt_pcopy - copy one page buffer to another
' Marks display dirty but does not call vt_present.
' src = dst is a no-op. Invalid indices are silently ignored.
' -----------------------------------------------------------------------------
Sub vt_pcopy(src As Long, dst As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If src < 0 Or src >= vt_internal.num_pages Then Exit Sub
    If dst < 0 Or dst >= vt_internal.num_pages Then Exit Sub
    If src = dst Then Exit Sub
    Dim buf_sz As Long = vt_internal.scr_cols * vt_internal.scr_rows * SizeOf(vt_cell)
    CopyMemory(vt_internal.page_buf(dst), vt_internal.page_buf(src), buf_sz)
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_scroll - scroll the scrollback view by amount lines
' Returns 1 if the offset changed, 0 if already at limit or scrollback disabled.
' Does not call vt_present.
' -----------------------------------------------------------------------------
Function vt_scroll(amount As Long) As Byte
    If vt_internal.ready    = 0 Then Return 0
    If vt_internal.sb_lines = 0 Then Return 0
    If amount = 0               Then Return 0

    Dim prev As Long = vt_internal.sb_offset

    vt_internal.sb_offset += amount
    If vt_internal.sb_offset > vt_internal.sb_used Then _
        vt_internal.sb_offset = vt_internal.sb_used
    If vt_internal.sb_offset < 0 Then _
        vt_internal.sb_offset = 0

    If vt_internal.sb_offset = prev Then Return 0

    vt_internal.dirty = 1
    Return 1
End Function

' -----------------------------------------------------------------------------
' vt_scrollback - enable or resize the scrollback buffer
' Must be called after vt_screen(). Calling again clears the existing buffer.
' lines = 0 disables scrollback and frees the buffer.
' -----------------------------------------------------------------------------
Sub vt_scrollback(lines As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If
    vt_internal.sb_lines  = lines
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0
    If lines > 0 Then
        vt_internal.sb_cells = CAllocate(lines * vt_internal.scr_cols, SizeOf(vt_cell))
    End If
End Sub

' -----------------------------------------------------------------------------
' vt_screen_to_live_row - translate a screen row to the live vis_buf row,
' accounting for any active scrollback offset.
'
' During scrollback the scroll region rows no longer map 1:1 to vis_buf.
' Call this BEFORE snapping back with vt_scroll, while sb_offset is still set.
'
' Returns the 1-based vis_buf row that corresponds to screen_row, or 0 if that
' screen position is showing pure scrollback history with no live equivalent.
'
' Fixed rows outside view_top..view_bot are not affected by scrollback and are
' returned as-is. When sb_offset = 0 the function is a trivial pass-through.
' -----------------------------------------------------------------------------
Function vt_screen_to_live_row(screen_row As Long) As Long
    Dim scroll_pos  As Long
    Dim logical_row As Long
    Dim live_r      As Long

    ' Pass-through: no scrollback active, or row is a fixed row outside the
    ' scroll region -- screen row equals live row in both cases.
    If vt_internal.sb_offset = 0 OrElse _
       screen_row < vt_internal.view_top OrElse _
       screen_row > vt_internal.view_bot Then
        Return screen_row
    End If

    ' Mirror the exact arithmetic used by the vt_present cell loop.
    scroll_pos  = (screen_row - 1) - (vt_internal.view_top - 1)
    logical_row = (vt_internal.sb_used - vt_internal.sb_offset) + scroll_pos
    If logical_row < 0 Then logical_row = 0

    If logical_row < vt_internal.sb_used Then
        ' Row is pure scrollback history -- no live buffer equivalent.
        Return 0
    End If

    ' Row is still within vis_buf. Compute its 1-based live row index.
    live_r = logical_row - vt_internal.sb_used + vt_internal.view_top
    Return live_r
End Function
