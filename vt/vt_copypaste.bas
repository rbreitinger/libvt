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
' Called from vt_pump on RMB (mouse).
' Reads from vt_internal_display_cellptr so it works during scrollback --
' cells come from sb_cells or vis_buf depending on sb_offset, same as render.
' Respects cp_view_* snapshot: column range is clipped to effective bounds.
' After copy, resets cp_view_* snapshot to -1.
' -----------------------------------------------------------------------------
Sub vt_internal_cp_build_text()
    Dim cols      As Long
    Dim flat1     As Long
    Dim flat2     As Long
    Dim r1        As Long
    Dim c1        As Long
    Dim r2        As Long
    Dim c2        As Long
    Dim row_idx   As Long
    Dim col_from  As Long
    Dim col_to    As Long
    Dim col_idx   As Long
    Dim cellptr   As vt_cell Ptr
    Dim clip_str  As String
    Dim row_str   As String
    Dim tlen      As Long
    Dim vis_buf   As vt_cell Ptr
    Dim eff_left  As Long
    Dim eff_right As Long

    If vt_internal.ready      = 0 Then Exit Sub
    If vt_internal.sel_active = 0 Then Exit Sub

    cols    = vt_internal.scr_cols
    vis_buf = vt_internal.page_buf(vt_internal.vis_page)

    ' resolve effective column bounds from cp_view_* snapshot (-1 = full width)
    eff_left  = IIf(vt_internal.cp_view_left  <> -1, vt_internal.cp_view_left,  1)
    eff_right = IIf(vt_internal.cp_view_right <> -1, vt_internal.cp_view_right, cols)

    ' normalize so flat1 is always the earlier cell
    flat1 = (vt_internal.sel_anchor_row - 1) * cols + (vt_internal.sel_anchor_col - 1)
    flat2 = (vt_internal.sel_end_row    - 1) * cols + (vt_internal.sel_end_col    - 1)
    If flat1 > flat2 Then Swap flat1, flat2

    r1 = flat1 \ cols + 1
    c1 = flat1 Mod cols + 1
    r2 = flat2 \ cols + 1
    c2 = flat2 Mod cols + 1

    ' clamp first and last column of the selection to effective viewport bounds
    If c1 < eff_left  Then c1 = eff_left
    If c2 > eff_right Then c2 = eff_right

    clip_str = ""

    For row_idx = r1 To r2
        col_from = IIf(row_idx = r1, c1, eff_left)
        col_to   = IIf(row_idx = r2, c2, eff_right)

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

    ' reset cp_view_* snapshot after copy
    vt_internal.cp_view_left  = -1
    vt_internal.cp_view_right = -1
    vt_internal.cp_view_top   = -1
    vt_internal.cp_view_bot   = -1
End Sub

' -----------------------------------------------------------------------------
' vt_copypaste - enable or disable mouse copy/paste
' flags: VT_ENABLED (1) = on, VT_DISABLED (0) = off. Values > 1 clamped to 1.
' Clears any active selection, resets viewport snapshot and auto-scroll throttle.
' -----------------------------------------------------------------------------
Sub vt_copypaste(flags As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If flags > 1 Then flags = 1
    vt_internal.cp_flags       = flags
    vt_internal.sel_active     = 0
    vt_internal.sel_dragging   = 0
    vt_internal.cp_paste_pend  = 0
    vt_internal.cp_view_left   = -1
    vt_internal.cp_view_right  = -1
    vt_internal.cp_view_top    = -1
    vt_internal.cp_view_bot    = -1
    vt_internal.cp_scroll_tick = 0
    vt_internal.dirty          = 1
End Sub

#Undef vt_internal_cp_build_text
