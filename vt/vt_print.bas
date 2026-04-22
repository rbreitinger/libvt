' =============================================================================
' vt_print.bas - VT Virtual Text Screen Library
' =============================================================================

' -----------------------------------------------------------------------------
' Internal: scroll the view region up by one line
' Column-aware: only shifts and blanks cells within view_left..view_right.
' Scrollback capture always saves the full row (full context for scrollback view).
' Full-row fast path used when view_left = -1.
' -----------------------------------------------------------------------------
Sub vt_internal_scroll_up()
    Dim cols    As Long = vt_internal.scr_cols
    Dim vtop    As Long = vt_internal.view_top - 1   ' 0-based
    Dim vbot    As Long = vt_internal.view_bot - 1   ' 0-based
    Dim v_left  As Long
    Dim v_right As Long
    Dim ln      As Long
    Dim ci      As Long
    Dim cellptr As vt_cell Ptr
    Dim src     As vt_cell Ptr
    Dim dst     As vt_cell Ptr
    ' resolve column bounds
    If vt_internal.view_left = -1 Then
        v_left  = 0
        v_right = cols - 1
    Else
        v_left  = vt_internal.view_left  - 1   ' 0-based
        v_right = vt_internal.view_right - 1   ' 0-based
    End If
    ' push top line into scrollback buffer if enabled -- always full row
    If vt_internal.sb_lines > 0 AndAlso vt_internal.sb_cells <> 0 Then
        If vt_internal.sb_used < vt_internal.sb_lines Then
            dst = vt_internal.sb_cells + (vt_internal.sb_used * cols)
            src = vt_internal.cells    + (vtop * cols)
            memcpy(dst, src, cols * SizeOf(vt_cell))
            vt_internal.sb_used += 1
        Else
            memcpy(vt_internal.sb_cells, _
                   vt_internal.sb_cells + cols, _
                   (vt_internal.sb_lines - 1) * cols * SizeOf(vt_cell))
            dst = vt_internal.sb_cells + ((vt_internal.sb_lines - 1) * cols)
            src = vt_internal.cells    + (vtop * cols)
            memcpy(dst, src, cols * SizeOf(vt_cell))
        End If
    End If
    If vt_internal.view_left = -1 Then
        ' full-row fast path -- no column viewport active
        For ln = vtop To vbot - 1
            memcpy(vt_internal.cells + (ln * cols), _
                   vt_internal.cells + ((ln + 1) * cols), _
                   cols * SizeOf(vt_cell))
        Next ln
        cellptr = vt_internal.cells + (vbot * cols)
        For ci = 0 To cols - 1
            cellptr[ci].ch = 32
            cellptr[ci].fg = vt_internal.clr_fg
            cellptr[ci].bg = vt_internal.clr_bg
        Next ci
    Else
        ' column-range path -- only touch v_left..v_right per row
        For ln = vtop To vbot - 1
            dst = vt_internal.cells + (ln       * cols)
            src = vt_internal.cells + ((ln + 1) * cols)
            For ci = v_left To v_right
                dst[ci] = src[ci]
            Next ci
        Next ln
        ' blank bottom line within column range only
        cellptr = vt_internal.cells + (vbot * cols)
        For ci = v_left To v_right
            cellptr[ci].ch = 32
            cellptr[ci].fg = vt_internal.clr_fg
            cellptr[ci].bg = vt_internal.clr_bg
        Next ci
    End If
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' Internal: write one character at the current cursor position and advance.
' Does NOT call vt_present - caller does that after the full string.
' Respects view_left/view_right for wrap boundary and newline left edge.
' view_left = -1 means full width (left edge = col 1, right edge = scr_cols).
' -----------------------------------------------------------------------------
Sub vt_internal_putch(ch As UByte)
    Dim col_left  As Long
    Dim col_right As Long

    ' resolve column bounds -- -1 means full width
    If vt_internal.view_left = -1 Then
        col_left  = 1
        col_right = vt_internal.scr_cols
    Else
        col_left  = vt_internal.view_left
        col_right = vt_internal.view_right
    End If

    Select Case ch
        Case 13   ' carriage return
            vt_internal.cur_col = col_left
        Case 10   ' line feed -- advance row AND reset column to left edge (DOS behaviour)
            vt_internal.cur_col = col_left
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
            If vt_internal.cur_col > col_right Then
                vt_internal.cur_col = col_left
                If vt_internal.cur_row < vt_internal.view_bot Then
                    vt_internal.cur_row += 1
                ElseIf vt_internal.scroll_on Then
                    vt_internal_scroll_up()
                End If
            End If
    End Select
End Sub

' -----------------------------------------------------------------------------
' vt_scroll_enable - enable or disable automatic scrolling (default: on)
' -----------------------------------------------------------------------------
Sub vt_scroll_enable(state As Byte)
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.scroll_on = state
End Sub

' -----------------------------------------------------------------------------
' vt_cls - clear the screen
' Respects view_top/view_bot and view_left/view_right.
' When column bounds are active, only that column range is cleared per row.
' -----------------------------------------------------------------------------
Sub vt_cls(bg As Long = -1)
    If vt_internal.ready = 0 Then Exit Sub
    If bg >= 0 Then vt_internal.clr_bg = bg And 15

    Dim cols    As Long
    Dim vtop    As Long
    Dim vbot    As Long
    Dim ci_from As Long
    Dim ci_to   As Long
    Dim row     As Long
    Dim ci      As Long
    Dim cellptr As vt_cell Ptr

    cols = vt_internal.scr_cols
    vtop = vt_internal.view_top - 1   ' 0-based
    vbot = vt_internal.view_bot - 1   ' 0-based

    ' resolve column bounds -- -1 means full width
    If vt_internal.view_left = -1 Then
        ci_from = 0
        ci_to   = cols - 1
    Else
        ci_from = vt_internal.view_left  - 1   ' 0-based
        ci_to   = vt_internal.view_right - 1   ' 0-based
        If ci_to > cols - 1 Then ci_to = cols - 1
    End If

    For row = vtop To vbot
        cellptr = vt_internal.cells + (row * cols)
        For ci = ci_from To ci_to
            cellptr[ci].ch = 32
            cellptr[ci].fg = vt_internal.clr_fg
            cellptr[ci].bg = vt_internal.clr_bg
        Next ci
    Next row

    ' cursor to top-left of the active viewport (not screen col 1)
    If vt_internal.view_left = -1 Then
        vt_internal.cur_col = 1
    Else
        vt_internal.cur_col = vt_internal.view_left
    End If
    vt_internal.cur_row = vt_internal.view_top
    vt_internal.dirty   = 1
End Sub

' -----------------------------------------------------------------------------
' vt_get_cell / vt_set_cell
' Both operate on the active work page (via vt_internal.cells).
' -----------------------------------------------------------------------------
Sub vt_get_cell(col As Long, row As Long, ByRef ch As UByte, ByRef fg As UByte, ByRef bg As UByte)
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    ch = cellptr->ch
    fg = cellptr->fg
    bg = cellptr->bg
End Sub

Sub vt_set_cell(col As Long, row As Long, ch As UByte, fg As UByte, bg As UByte)
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    cellptr->ch = ch
    cellptr->fg = fg
    cellptr->bg = bg
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_color - set active foreground and/or background colour
' -----------------------------------------------------------------------------
Sub vt_color(fg As Long = -1, bg As Long = -1)
    If fg >= 0 Then vt_internal.clr_fg = fg And 31
    If bg >= 0 Then vt_internal.clr_bg = bg And 15
End Sub

' -----------------------------------------------------------------------------
' vt_locate - move cursor, optionally set visibility and cursor glyph
' -----------------------------------------------------------------------------
Sub vt_locate(row As Long = -1, col As Long = -1, vis As Long = -1, cursor_ch As Long = -1)
    If vt_internal.ready = 0 Then Exit Sub
    If row >= 1 AndAlso row <= vt_internal.scr_rows Then vt_internal.cur_row = row
    If col >= 1 AndAlso col <= vt_internal.scr_cols Then vt_internal.cur_col = col
    If vis >= 0 Then vt_internal.cur_visible = vis
    If cursor_ch >= 0 Then vt_internal.cur_ch = cursor_ch And 255
End Sub

' -----------------------------------------------------------------------------
' Query functions
' -----------------------------------------------------------------------------
Function vt_csrlin() As Long : Return vt_internal.cur_row  : End Function
Function vt_pos()    As Long : Return vt_internal.cur_col  : End Function
Function vt_cols()   As Long : Return vt_internal.scr_cols : End Function
Function vt_rows()   As Long : Return vt_internal.scr_rows : End Function

' -----------------------------------------------------------------------------
' vt_view_print - restrict scroll/print region to a row and/or column range
' All -1 (or omitted): full reset of all four viewport bounds.
' Partial call (e.g. only top/bot): column bounds stay unchanged.
' vt_locate is always absolute -- never affected by the viewport.
' -----------------------------------------------------------------------------
Sub vt_view_print(top_row As Long = -1, bot_row As Long = -1, _
                  lft_col As Long = -1, rgt_col As Long = -1)
    If vt_internal.ready = 0 Then Exit Sub
    ' all sentinel -1 = full reset of all four bounds
    If top_row = -1 AndAlso bot_row = -1 AndAlso lft_col = -1 AndAlso rgt_col = -1 Then
        vt_internal.view_top   = 1
        vt_internal.view_bot   = vt_internal.scr_rows
        vt_internal.view_left  = -1
        vt_internal.view_right = -1
        Exit Sub
    End If
    ' partial set -- only update params that are not -1
    If top_row >= 1 AndAlso top_row <= vt_internal.scr_rows Then vt_internal.view_top = top_row
    If bot_row >= vt_internal.view_top AndAlso bot_row <= vt_internal.scr_rows Then vt_internal.view_bot = bot_row
    If lft_col >= 1 AndAlso lft_col <= vt_internal.scr_cols Then vt_internal.view_left = lft_col
    If rgt_col >= 1 AndAlso rgt_col <= vt_internal.scr_cols Then vt_internal.view_right = rgt_col
End Sub

' -----------------------------------------------------------------------------
' vt_print - print a string at the current cursor position, NO auto LF
'
' With VT_USE_ANSI: ESC[ sequences are parsed before reaching the cell buffer.
' Supported sequences:
'   SGR  ESC [ <params> m   -- color / blink attributes
'   CUP  ESC [ row ; col H  -- cursor position (1-based; omitted = 1)
'        ESC [ row ; col f  -- same as H
'   ED   ESC [ 2 J          -- clear screen (only param 2 for M1)
' Unknown final chars: raw bytes emitted as CP437 glyphs.
' Without VT_USE_ANSI: plain byte feed, CRLF collapse only.
' -----------------------------------------------------------------------------
Sub vt_print(txt As String)
    If vt_internal.ready = 0 Then Exit Sub
    Dim slen As Long = Len(txt)
    If slen = 0 Then Exit Sub

    Dim ci   As Long
    Dim ch   As UByte
    Dim prev As UByte = 0

    #Ifdef VT_USE_ANSI
        ' Parser state
        '   0 = normal output
        '   1 = got ESC (27), waiting for next byte
        '   2 = in CSI  (ESC [), collecting numeric params
        Dim ansi_state As Long = 0

        ' param accumulator -- up to 8 params separated by ';'
        Dim params(7) As Long
        Dim nparams   As Long   ' number of params committed so far
        Dim cur_param As Long   ' numeric accumulator for current param

        ' raw bytes buffered since ESC, used for unknown-sequence pass-through
        Dim raw(31) As UByte
        Dim raw_n   As Long

        Dim pi      As Long   ' param loop index (SGR)
        Dim ri      As Long   ' raw loop index   (pass-through)
        Dim cup_row As Long   ' CUP scratch
        Dim cup_col As Long   ' CUP scratch
    #EndIf

    For ci = 1 To slen
        ch = txt[ci - 1]

        #Ifdef VT_USE_ANSI
            Select Case ansi_state

                Case 0  ' ---- normal output ----
                    If ch = 27 Then
                        ' begin potential escape sequence
                        ansi_state = 1
                        raw(0) = 27 : raw_n = 1
                    Else
                        ' CRLF collapse then emit
                        If ch = 10 AndAlso prev = 13 Then
                            prev = ch
                            Continue For
                        End If
                        vt_internal_putch(ch)
                        prev = ch
                    End If

                Case 1  ' ---- got ESC ----
                    If ch = Asc("[") Then
                        ' confirmed CSI -- start param collection
                        raw(1) = ch : raw_n  = 2
                        ansi_state = 2
                        nparams = 0 : cur_param = 0
                    Else
                        ' not CSI: emit ESC glyph, re-process current byte
                        vt_internal_putch(27)
                        prev = 27
                        ansi_state = 0
                        If ch = 27 Then
                            ' back-to-back ESC
                            ansi_state = 1
                            raw(0) = 27 : raw_n = 1
                        Else
                            If ch = 10 AndAlso prev = 13 Then
                                prev = ch
                                Continue For
                            End If
                            vt_internal_putch(ch)
                            prev = ch
                        End If
                    End If

                Case 2  ' ---- in CSI: collecting params ----
                    ' buffer raw byte for possible pass-through
                    If raw_n < 32 Then : raw(raw_n) = ch : raw_n += 1 : End If

                    If ch >= Asc("0") AndAlso ch <= Asc("9") Then
                        ' numeric digit: accumulate into current param
                        cur_param = cur_param * 10 + (ch - Asc("0"))

                    ElseIf ch = Asc(";") Then
                        ' param separator: commit current param, start next
                        If nparams < 8 Then
                            params(nparams) = cur_param
                            nparams += 1
                        End If
                        cur_param = 0

                    Else
                        ' final byte: commit last param, dispatch on command char
                        If nparams < 8 Then
                            params(nparams) = cur_param
                            nparams += 1
                        End If
                        ansi_state = 0

                        Select Case ch

                            Case Asc("m")   ' ---- SGR: set graphics rendition ----
                                ' process all params in order; empty param list = reset (param 0)
                                For pi = 0 To nparams - 1
                                    Select Case params(pi)
                                        Case 0      ' reset all attributes
                                            vt_internal.clr_fg = VT_LIGHT_GREY
                                            vt_internal.clr_bg = VT_BLACK
                                        Case 5      ' blink on  (set bit 4 of fg)
                                            vt_internal.clr_fg = vt_internal.clr_fg Or &h10
                                        Case 25     ' blink off (clear bit 4 of fg)
                                            vt_internal.clr_fg = vt_internal.clr_fg And &hEF
                                        ' fg dark -- CGA order, explicit map (arithmetic is wrong)
                                        Case 30 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 0
                                        Case 34 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 1
                                        Case 32 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 2
                                        Case 36 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 3
                                        Case 31 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 4
                                        Case 35 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 5
                                        Case 33 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 6
                                        Case 37 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 7
                                        ' fg bright
                                        Case 90 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 8
                                        Case 94 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 9
                                        Case 92 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 10
                                        Case 96 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 11
                                        Case 91 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 12
                                        Case 95 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 13
                                        Case 93 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 14
                                        Case 97 : vt_internal.clr_fg = (vt_internal.clr_fg And &h10) Or 15
                                        ' bg dark
                                        Case 40  : vt_internal.clr_bg = 0
                                        Case 44  : vt_internal.clr_bg = 1
                                        Case 42  : vt_internal.clr_bg = 2
                                        Case 46  : vt_internal.clr_bg = 3
                                        Case 41  : vt_internal.clr_bg = 4
                                        Case 45  : vt_internal.clr_bg = 5
                                        Case 43  : vt_internal.clr_bg = 6
                                        Case 47  : vt_internal.clr_bg = 7
                                        ' bg bright
                                        Case 100 : vt_internal.clr_bg = 8
                                        Case 104 : vt_internal.clr_bg = 9
                                        Case 102 : vt_internal.clr_bg = 10
                                        Case 106 : vt_internal.clr_bg = 11
                                        Case 101 : vt_internal.clr_bg = 12
                                        Case 105 : vt_internal.clr_bg = 13
                                        Case 103 : vt_internal.clr_bg = 14
                                        Case 107 : vt_internal.clr_bg = 15
                                    End Select
                                Next pi

                            Case Asc("H"), Asc("f")   ' ---- CUP: cursor position ----
                                ' ESC[H       -> (1,1)
                                ' ESC[row;colH -> (row,col)  0 treated as 1
                                cup_row = 1
                                cup_col = 1
                                If nparams >= 1 AndAlso params(0) > 0 Then cup_row = params(0)
                                If nparams >= 2 AndAlso params(1) > 0 Then cup_col = params(1)
                                vt_locate(cup_row, cup_col)

                            Case Asc("J")   ' ---- ED: erase display ----
                                ' only ESC[2J (full clear) implemented for Milestone 1
                                If nparams >= 1 AndAlso params(0) = 2 Then
                                    vt_cls()
                                End If

                            Case Else   ' ---- unknown sequence: pass through as CP437 ----
                                For ri = 0 To raw_n - 1
                                    vt_internal_putch(raw(ri))
                                Next ri

                        End Select
                    End If

            End Select
        #Else
            ' no ANSI parser -- plain byte feed with CRLF collapse
            If ch = 10 AndAlso prev = 13 Then
                prev = ch
                Continue For
            End If
            vt_internal_putch(ch)
            prev = ch
        #EndIf
    Next ci
End Sub

Sub vt_print_center(row As Long, txt As String)
    If vt_internal.ready = 0 Then Exit Sub
    Dim txt_len   As Long = Len(txt)
    Dim start_col As Long = (vt_internal.scr_cols - txt_len) \ 2 + 1
    If start_col < 1 Then start_col = 1
    vt_locate(row, start_col)
    vt_print(txt)
End Sub

#Undef vt_internal_scroll_up
#Undef vt_internal_putch
