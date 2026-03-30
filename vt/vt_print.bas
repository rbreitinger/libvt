' =============================================================================
' vt_print.bas - VT Virtual Text Screen Library
' vt_print, vt_locate, vt_cls, vt_color, vt_scroll_enable, vt_view_print,
' vt_print_center, vt_scroll_enable, cursor control.
' =============================================================================

' -----------------------------------------------------------------------------
' Internal: scroll the view region up by one line
' -----------------------------------------------------------------------------
Private Sub vt_internal_scroll_up()
    Dim cols    As Long = vt_internal.scr_cols
    Dim vtop    As Long = vt_internal.view_top - 1   ' 0-based
    Dim vbot    As Long = vt_internal.view_bot - 1   ' 0-based

    ' push top line into scrollback buffer if enabled
    If vt_internal.sb_lines > 0 AndAlso vt_internal.sb_cells <> 0 Then
        If vt_internal.sb_used < vt_internal.sb_lines Then
            Dim dst As vt_cell Ptr = vt_internal.sb_cells + (vt_internal.sb_used * cols)
            Dim src As vt_cell Ptr = vt_internal.cells   + (vtop * cols)
            memcpy(dst, src, cols * SizeOf(vt_cell))
            vt_internal.sb_used += 1
        Else
            memcpy(vt_internal.sb_cells, _
                   vt_internal.sb_cells + cols, _
                   (vt_internal.sb_lines - 1) * cols * SizeOf(vt_cell))
            Dim dst As vt_cell Ptr = vt_internal.sb_cells + ((vt_internal.sb_lines - 1) * cols)
            Dim src As vt_cell Ptr = vt_internal.cells    + (vtop * cols)
            memcpy(dst, src, cols * SizeOf(vt_cell))
        End If
    End If

    ' shift view region lines up by one
    Dim ln As Long
    For ln = vtop To vbot - 1
        memcpy(vt_internal.cells + (ln * cols), _
               vt_internal.cells + ((ln + 1) * cols), _
               cols * SizeOf(vt_cell))
    Next ln

    ' clear the bottom line with current bg colour
    Dim cellptr As vt_cell Ptr = vt_internal.cells + (vbot * cols)
    Dim ci As Long
    For ci = 0 To cols - 1
        cellptr[ci].ch = 32
        cellptr[ci].fg = vt_internal.clr_fg
        cellptr[ci].bg = vt_internal.clr_bg
    Next ci

    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_cls - clear the screen
' Respects view_top/view_bot - only clears the active scroll region.
' -----------------------------------------------------------------------------
Sub vt_cls(bg As Long = -1)
    If vt_internal.ready = 0 Then Exit Sub
    If bg >= 0 Then vt_internal.clr_bg = bg And 15

    Dim cols As Long = vt_internal.scr_cols
    Dim vtop As Long = vt_internal.view_top - 1   ' 0-based
    Dim vbot As Long = vt_internal.view_bot - 1   ' 0-based
    Dim row  As Long
    Dim ci   As Long
    Dim cellptr As vt_cell Ptr

    For row = vtop To vbot
        cellptr = vt_internal.cells + (row * cols)
        For ci = 0 To cols - 1
            cellptr[ci].ch = 32
            cellptr[ci].fg = vt_internal.clr_fg
            cellptr[ci].bg = vt_internal.clr_bg
        Next ci
    Next row

    vt_internal.cur_col = 1
    vt_internal.cur_row = vt_internal.view_top
    vt_internal.dirty   = 1
End Sub

' -----------------------------------------------------------------------------
' vt_color - set active foreground and/or background colour
' -----------------------------------------------------------------------------
Sub vt_color(fg As Long, bg As Long = -1)
    vt_internal.clr_fg = fg And 31
    If bg >= 0 Then vt_internal.clr_bg = bg And 15
End Sub

' -----------------------------------------------------------------------------
' vt_locate - move cursor, optionally set visibility and cursor glyph
' -----------------------------------------------------------------------------
Sub vt_locate(row As Long, col As Long, vis As Long = -1, cursor_ch As Long = 0)
    If vt_internal.ready = 0 Then Exit Sub
    If row >= 1 AndAlso row <= vt_internal.scr_rows Then
        vt_internal.cur_row = row
    End If
    If col >= 1 AndAlso col <= vt_internal.scr_cols Then
        vt_internal.cur_col            = col
    End If
    If vis >= 0 Then vt_internal.cur_visible = vis
    If cursor_ch > 0 Then vt_internal.cur_ch = cursor_ch
End Sub

' -----------------------------------------------------------------------------
' vt_scroll_enable - enable or disable automatic scrolling (default: on)
' -----------------------------------------------------------------------------
Sub vt_scroll_enable(state As Byte)
    vt_internal.scroll_on = state
End Sub

' -----------------------------------------------------------------------------
' vt_view_print - restrict scroll region to a row range (like VIEW PRINT)
' -----------------------------------------------------------------------------
Sub vt_view_print(top_row As Long, bot_row As Long)
    If top_row >= 1 AndAlso top_row <= vt_internal.scr_rows Then
        vt_internal.view_top = top_row
    End If
    If bot_row >= top_row AndAlso bot_row <= vt_internal.scr_rows Then
        vt_internal.view_bot = bot_row
    End If
End Sub

Sub vt_view_print_reset()
    vt_internal.view_top = 1
    vt_internal.view_bot = vt_internal.scr_rows
End Sub

' -----------------------------------------------------------------------------
' Internal: write one character at the current cursor position and advance.
' Does NOT call vt_present - caller does that after the full string.
' -----------------------------------------------------------------------------
Private Sub vt_internal_putch(ch As UByte)
    Select Case ch
        Case 13   ' carriage return
            vt_internal.cur_col = 1

        Case 10   ' line feed - advance row AND reset column to 1 (DOS behaviour)
            vt_internal.cur_col = 1
            If vt_internal.cur_row < vt_internal.view_bot Then
                vt_internal.cur_row += 1
            ElseIf vt_internal.scroll_on Then
                vt_internal_scroll_up()
            End If

        Case Else
            Dim cellptr As vt_cell Ptr = vt_internal.cells + _
                ((vt_internal.cur_row - 1) * vt_internal.scr_cols + (vt_internal.cur_col - 1))
            cellptr->ch = ch
            cellptr->fg = vt_internal.clr_fg
            cellptr->bg = vt_internal.clr_bg
            vt_internal.dirty = 1

            ' advance cursor
            vt_internal.cur_col += 1
            If vt_internal.cur_col > vt_internal.scr_cols Then
                vt_internal.cur_col = 1
                If vt_internal.cur_row < vt_internal.view_bot Then
                    vt_internal.cur_row += 1
                ElseIf vt_internal.scroll_on Then
                    vt_internal_scroll_up()
                End If
            End If

    End Select
End Sub

' -----------------------------------------------------------------------------
' vt_print - print a string at the current cursor position
' -----------------------------------------------------------------------------
Sub vt_print(txt As String)
    If vt_internal.ready = 0 Then Exit Sub
    Dim slen As Long = Len(txt)
    If slen = 0 Then Exit Sub

    Dim ci   As Long
    Dim ch   As UByte
    Dim prev As UByte = 0

    For ci = 1 To slen
        ch = txt[ci - 1]
        ' collapse CRLF into a single LF
        If ch = 10 AndAlso prev = 13 Then
            prev = ch
            Continue For
        End If
        vt_internal_putch(ch)
        prev = ch
    Next ci
End Sub

' -----------------------------------------------------------------------------
' vt_print_center - print text horizontally centered on a given row
' -----------------------------------------------------------------------------
Sub vt_print_center(row As Long, txt As String)
    If vt_internal.ready = 0 Then Exit Sub
    Dim txt_len   As Long = Len(txt)
    Dim start_col As Long = (vt_internal.scr_cols - txt_len) \ 2 + 1
    If start_col < 1 Then start_col = 1
    vt_locate(row, start_col)
    vt_print(txt)
End Sub
