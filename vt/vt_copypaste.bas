' =============================================================================
' vt_copypaste.bas - VT Virtual Text Screen Library
' Copy/paste: selection state, clipboard copy, and mode control.
' Paste injection lives in vt_input.bas (cp_paste_pend flag).
' Key interception and mouse drag tracking live in vt_pump (vt_core.bas).
' Selection rendering lives in vt_present (vt_core.bas).
' =============================================================================

' -----------------------------------------------------------------------------
' vt_internal_cp_build_text
' Walk the active selection, build a plain-text string, trim trailing spaces
' per row, join rows with CR+LF, push to SDL clipboard.
' Called from vt_pump on Ctrl+INS (kbd) or RMB (mouse).
' Safe no-op when sel_active = 0.
' Reads from vt_internal_display_cellptr so it works during scrollback --
' cells come from sb_cells or vis_buf depending on sb_offset, same as render.
' -----------------------------------------------------------------------------
Sub vt_internal_cp_build_text()
    Dim cols     As Long
    Dim flat1    As Long
    Dim flat2    As Long
    Dim r1       As Long
    Dim c1       As Long
    Dim r2       As Long
    Dim c2       As Long
    Dim row_idx  As Long
    Dim col_from As Long
    Dim col_to   As Long
    Dim col_idx  As Long
    Dim cellptr  As vt_cell Ptr
    Dim clip_str As String
    Dim row_str  As String
    Dim tlen     As Long
    Dim vis_buf  As vt_cell Ptr

    If vt_internal.ready      = 0 Then Exit Sub
    If vt_internal.sel_active = 0 Then Exit Sub

    cols    = vt_internal.scr_cols
    vis_buf = vt_internal.page_buf(vt_internal.vis_page)

    ' normalize so flat1 is always the earlier cell
    flat1 = (vt_internal.sel_anchor_row - 1) * cols + (vt_internal.sel_anchor_col - 1)
    flat2 = (vt_internal.sel_end_row    - 1) * cols + (vt_internal.sel_end_col    - 1)
    If flat1 > flat2 Then Swap flat1, flat2

    r1 = flat1 \ cols + 1
    c1 = flat1 Mod cols + 1
    r2 = flat2 \ cols + 1
    c2 = flat2 Mod cols + 1

    clip_str = ""

    For row_idx = r1 To r2
        col_from = IIf(row_idx = r1, c1, 1)
        col_to   = IIf(row_idx = r2, c2, cols)

        row_str = ""
        For col_idx = col_from To col_to
            cellptr = vt_internal_display_cellptr(col_idx - 1, row_idx - 1, vis_buf)
            row_str = row_str & Chr(cellptr->ch)
        Next col_idx

        ' trim trailing spaces from this row segment
        tlen = Len(row_str)
        Do While tlen > 0 AndAlso row_str[tlen - 1] = 32
            tlen -= 1
        Loop
        row_str = Left(row_str, tlen)

        If row_idx < r2 Then
            clip_str = clip_str & row_str & Chr(13) & Chr(10)
        Else
            clip_str = clip_str & row_str
        End If
    Next row_idx

    SDL_SetClipboardText(clip_str)
End Sub

' -----------------------------------------------------------------------------
' vt_copypaste - configure copy/paste mode
' flags : VT_CP_DISABLED (0), VT_CP_MOUSE, VT_CP_KBD, or both Or'd together.
' Clears any active selection. Call after vt_screen().
' When VT_CP_DISABLED: no keys reserved, no mouse events captured by VT.
' -----------------------------------------------------------------------------
Sub vt_copypaste(flags As Long)
    vt_internal.cp_flags      = flags
    vt_internal.sel_active    = 0
    vt_internal.sel_dragging  = 0
    vt_internal.cp_paste_pend = 0
    vt_internal.dirty         = 1
End Sub 