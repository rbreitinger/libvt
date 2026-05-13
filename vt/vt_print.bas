' =============================================================================
' vt_print.bas - VT Virtual Text Screen Library
' =============================================================================

' -----------------------------------------------------------------------------
' Internal: scroll the view region up by one line
' Column-aware: only shifts and blanks cells within view_left..view_right.
' Scrollback capture always saves the full row (full context for scrollback view).
' Full-row fast path used when view_left = -1.
' -----------------------------------------------------------------------------
Private Sub vt_internal_scroll_up()
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
Private Sub vt_internal_putch(ch As UByte)
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

'>>>
':topic vt_scroll_enable
':short Enable or disable auto-scrolling
':group Printing
'Enable or disable automatic scrolling of the
'scroll region. When disabled, text printed past
'the bottom of the scroll region stays on the
'last row. Scrolling is ENABLED by default.
':syntax
Sub vt_scroll_enable(state As Byte)
        ':params
        'state  1 = enable scrolling, 0 = disable.
        ':see
        'vt_view_print
        'vt_print
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.scroll_on = state
End Sub

'>>>
':topic vt_cls
':short Clear the screen to the current background
':group Printing
'Clear the active screen region to spaces using
'the current foreground and background colours.
'Resets the cursor to row 1, column 1 of the
'scroll region. Does not call vt_present.
'Respects the viewport set by vt_view_print,
'including column bounds. When column bounds are
'active only the cells within view_left..
'view_right are cleared per row.
':syntax
Sub vt_cls(bg As Long = -1)
        ':params
        'bg  Background colour index (0-15).
        '    empty keeps the current background colour.
        ':example
        'vt_color(VT_LIGHT_GREY, VT_BLACK)
        'vt_cls()
        'vt_present()
        ':see
        'vt_color
        'vt_locate
        'vt_print
        'vt_view_print
    '<<<
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


'>>>
':topic vt_width
':short Resize the virtual character grid at runtime without closing the window.
':group Initialization
'Reallocates all page buffers at the new dimensions, destroys and recreates 
'the render buffer, resets the cursor to (1, 1), restores the scroll 
'region to the full screen, and invalidates the scrollback buffer 
'(call vt_scrollback again afterwards if needed). 
'Finishes with vt_cls and vt_present so the cleared screen 
'is visible immediately.
':syntax
Function vt_width(new_cols As Long, new_rows As Long) As Long
        ':params
        'cols  Long  New column count. Clamped to a minimum of 10.
        'rows  Long  New row count.    Clamped to a minimum of 3.
        '
        'Return value
        '  0 - success.
        ' -1 - library not initialized (vt_screen not called).
        '
        ':example
        '' Dynamic resize in the main loop:
        'Dim nc As Long, nr As Long
        'Do
        '    k = vt_inkey()
        '    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do
        '
        '    If vt_screeninfo(nc, nr) Then
        '        vt_width nc, nr
        '        relayout nc, nr   ' re-draw app at new grid size
        '    End If
        '
        '    vt_sleep(16)
        'Loop
    '<<<
    If vt_internal.ready = 0 Then Return -1

    ' --- clamp to sane minimum ---
    If new_cols < 10 Then new_cols = 10
    If new_rows < 3  Then new_rows = 3

    Dim pg    As Long
    Dim new_w As Long = new_cols * vt_internal.glyph_w
    Dim new_h As Long = new_rows * vt_internal.glyph_h

    ' --- free all existing page buffers ---
    For pg = 0 To vt_internal.num_pages - 1
        If vt_internal.page_buf(pg) <> 0 Then
            DeAllocate vt_internal.page_buf(pg)
            vt_internal.page_buf(pg) = 0
        End If
    Next pg

    ' --- allocate at new size, no content copy ---
    For pg = 0 To vt_internal.num_pages - 1
        vt_internal.page_buf(pg) = CAllocate(new_cols * new_rows, SizeOf(vt_cell))
    Next pg
    vt_internal.work_page = 0
    vt_internal.vis_page  = 0
    vt_internal.cells     = vt_internal.page_buf(0)

    ' --- recreate SDL render buffer at new pixel size ---
    If vt_internal.sdl_buffer <> 0 Then
        _VT_DRV_DestroyTexture(vt_internal.sdl_buffer)
        vt_internal.sdl_buffer = 0
    End If
    vt_internal.sdl_buffer = _VT_DRV_CreateTexture(vt_internal.sdl_renderer, _
        _VT_DRV_PIXELFORMAT_RGBA8888, _VT_DRV_TEXTUREACCESS_TARGET, new_w, new_h)

    ' --- update geometry ---
    vt_internal.scr_cols = new_cols
    vt_internal.scr_rows = new_rows

    ' HW mode: logical size must track the new buffer dimensions
    If vt_internal.init_flags And VT_RENDERER_HW Then
        _VT_DRV_RenderSetLogicalSize(vt_internal.sdl_renderer, new_w, new_h)
    End If

    ' --- reset scroll region ---
    vt_internal.view_top   = 1
    vt_internal.view_bot   = new_rows
    vt_internal.view_left  = -1
    vt_internal.view_right = -1

    ' --- reset cursor ---
    vt_internal.cur_col = 1
    vt_internal.cur_row = 1

    ' --- invalidate scrollback ---
    ' Caller must call vt_scrollback() again if they want it after a resize.
    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If
    vt_internal.sb_lines  = 0
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0

    ' --- clear any stale selection (coords reference old geometry) ---
    vt_internal.sel_active = 0

    vt_cls()
    vt_present()
    Return 0
End Function

'>>>
':topic vt_get_cell
':short Read one character cell from the work page
':group Cells
'Read the character, foreground colour, and
'background colour of a single cell on the
'active work page. Coordinates are 1-based.
'Out-of-range coordinates are ignored.
':syntax
Sub vt_get_cell(col As Long, row As Long, _
                ByRef ch As UByte, _
                ByRef fg As UByte, ByRef bg As UByte)
        ':params
        'col  Column, 1-based.
        'row  Row, 1-based.
        'ch   Receives the CP437 character code.
        'fg   Receives the foreground colour index
        '     (may include blink bit 16).
        'bg   Receives the background colour index.
        ':example
        'Dim ch As UByte, fg As UByte, bg As UByte
        'vt_get_cell(5, 3, ch, fg, bg)
        'vt_print("Char at (5,3): " & Chr(ch))
        ':see
        'vt_set_cell
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    ch = cellptr->ch
    fg = cellptr->fg
    bg = cellptr->bg
End Sub

'>>>
':topic vt_set_cell
':short Write one character cell directly
':group Cells
'Write a character cell directly on the active
'work page without moving the cursor. Does not
'call vt_present. Out-of-range coordinates are
'silently ignored.
':syntax
Sub vt_set_cell(col As Long, row As Long, _
                ch As UByte, _
                fg As UByte, bg As UByte)
        ':params
        'col  Column, 1-based.
        'row  Row, 1-based.
        'ch   CP437 character code (0-255).
        'fg   Foreground colour (0-15), optionally
        '     OR'd with 16 for blink.
        'bg   Background colour (0-15).
        ':example
        '' Draw a solid blue block at (10, 5):
        'vt_set_cell(10, 5, 219, VT_WHITE, VT_BLUE)
        'vt_present()
        ':see
        'vt_get_cell
        'vt_color
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    cellptr->ch = ch
    cellptr->fg = fg
    cellptr->bg = bg
    vt_internal.dirty = 1
End Sub

'>>>
':topic vt_color
':short Set the active foreground and background colour
':group Printing
'Set the active foreground and/or background
'colour used by vt_print, vt_cls, and vt_input.
'Pass -1 for either parameter to keep the current
'value unchanged.
':syntax
Sub vt_color(fg As Long = -1, bg As Long = -1)
        ':params
        'fg  Foreground colour (0-15), optionally OR'd
        '    with VT_BLINK (16). -1 = keep current.
        'bg  Background colour (0-15). -1 = keep current.
        ':example
        '' Set only foreground:
        'vt_color(VT_BRIGHT_GREEN)
        '
        '' Set both:
        'vt_color(VT_WHITE, VT_BLUE)
        '
        '' Blinking foreground:
        'vt_color(VT_RED Or VT_BLINK, VT_BLACK)
        ':see
        'vt_print
        'vt_cls
        'vt_locate
        'c_colors
    '<<<
    If fg >= 0 Then vt_internal.clr_fg = fg And 31
    If bg >= 0 Then vt_internal.clr_bg = bg And 15
End Sub

'>>>
':topic vt_locate
':short Move the cursor and optionally change its style
':group Printing
'Move the text cursor and optionally change its
'visibility and glyph. Coordinates are 1-based.
'Parameters with value -1 are left unchanged.
'vt_locate is always absolute -- column bounds
'from vt_view_print do not affect it.
':syntax
Sub vt_locate(row As Long = -1, col As Long = -1, _
              vis As Long = -1, _
              cursor_ch As Long = -1)
        ':params
        'row         Target row, 1-based. -1 = keep.
        'col         Target column, 1-based. -1 = keep.
        'vis         1 = show cursor, 0 = hide, -1 = keep.
        'cursor_ch   CP437 glyph index (0-255) for cursor.
        '            Default is 219 (solid block). -1=keep.
        ':example
        'vt_locate(1, 1)
        'vt_print("Top-left corner")
        'vt_locate(12, 40)
        'vt_print("Center-ish")
        ':see
        'vt_print
        'vt_color
        'vt_csrlin
        'vt_pos
    '<<<
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

'>>>
':topic vt_view_print
':short Restrict the scroll and print region
':group Scroll
'Restrict the scroll region and print region to
'a range of rows and/or columns (like QBasic
'VIEW PRINT, extended with column bounds). Rows
'and columns outside the active viewport are
'unaffected by vt_cls, vt_print, and scrolling.
'Call with no arguments (or all -1) to reset the
'full viewport including column bounds.
':syntax
Sub vt_view_print(top_row As Long = -1, _
                  bot_row As Long = -1, _
                  lft_col As Long = -1, _
                  rgt_col As Long = -1)
        ':params
        'top_row  First row of the scroll region, 1-based.
        '         -1 resets all four bounds to full screen.
        'bot_row  Last row of the scroll region. Must be
        '         >= top_row.
        'lft_col  First column of the print region.
        '         -1 means full screen width. vt_print
        '         newlines land at this column.
        'rgt_col  Last column of the print region. Must
        '         be >= lft_col. vt_print wraps here.
        ':notes
        'vt_locate is always absolute -- column bounds
        'do not affect it. Calling with all -1 resets
        'the entire viewport: row bounds, column bounds,
        'and cursor position.
        ':example
        '' Leave row 1 and row 25 untouched (status bars):
        'vt_view_print(2, 24)
        '
        '' Reset to full viewport:
        'vt_view_print()
        ':see
        'vt_cls
        'vt_print
        'vt_scroll_enable
    '<<<
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


' =============================================================================
' vt_utf8_to_cp437
' Decode a UTF-8 string to CP437 bytes suitable for vt_print / vt_set_cell.
' Pure ASCII strings are returned unchanged (fast path, no allocation).
' Multi-byte sequences with no CP437 equivalent are silently dropped.
' Supports 2-byte and 3-byte UTF-8; 4-byte (beyond BMP) always dropped.
' =============================================================================
Function vt_utf8_to_cp437(src As String) As String
    Dim slen  As Long = Len(src)
    Dim enc_i As Long

    For enc_i = 0 To slen - 1
        If src[enc_i] >= &h80 Then GoTo do_decode
    Next enc_i
    Return src

    do_decode:
    Dim dst   As String = Space(slen)
    Dim si    As Long   = 0
    Dim di    As Long   = 0
    Dim b0    As UByte
    Dim b1    As UByte
    Dim b2    As UByte
    Dim cp    As Long
    Dim outch As UByte

    Do While si < slen
        b0 = src[si]
        If b0 < &h80 Then
            ' plain ASCII -- pass through
            dst[di] = b0 : di += 1 : si += 1
        ElseIf (b0 And &hE0) = &hC0 AndAlso si + 1 < slen _
               AndAlso (src[si + 1] And &hC0) = &h80 Then
            ' valid 2-byte UTF-8 sequence
            b1    = src[si + 1]
            cp    = ((CLng(b0) And &h1F) Shl 6) Or (CLng(b1) And &h3F)
            outch = vt_internal_unicode_to_cp437(cp)
            If outch > 0 Then dst[di] = outch : di += 1
            si += 2
        ElseIf (b0 And &hF0) = &hE0 AndAlso si + 2 < slen _
               AndAlso (src[si + 1] And &hC0) = &h80 _
               AndAlso (src[si + 2] And &hC0) = &h80 Then
            ' valid 3-byte UTF-8 sequence
            b1    = src[si + 1]
            b2    = src[si + 2]
            cp    = ((CLng(b0) And &h0F) Shl 12) _
                 Or ((CLng(b1) And &h3F) Shl  6) _
                 Or  (CLng(b2) And &h3F)
            outch = vt_internal_unicode_to_cp437(cp)
            If outch > 0 Then dst[di] = outch : di += 1
            si += 3
        ElseIf (b0 And &hF8) = &hF0 AndAlso si + 3 < slen _
               AndAlso (src[si + 1] And &hC0) = &h80 _
               AndAlso (src[si + 2] And &hC0) = &h80 _
               AndAlso (src[si + 3] And &hC0) = &h80 Then
            ' valid 4-byte UTF-8 -- beyond BMP, no CP437 equivalent, drop
            si += 4
        Else
            ' not valid UTF-8 -- treat as raw CP437 byte and pass through
            dst[di] = b0 : di += 1 : si += 1
        End If
    Loop

    Return Left(dst, di)
End Function

'>>>
':topic vt_print
':short Print a string at the current cursor position
':group Printing
'Print a string at the current cursor position
'using the active colour. The cursor advances
'after each character; the display is not
'automatically flipped. No implicit newline --
'use VT_LF or Chr(10) within the string
'for line breaks. CRLF pairs are collapsed to
'a single line feed. Characters beyond the
'right edge of the print region are wrapped
'to the start again in the same row.
':syntax
Sub vt_print(txt As String)
        ':params
        'txt  The string to print. May contain Chr(10)
        '     for newlines.
        ':notes
        'When #Define VT_USE_ANSI is set before the
        'include, vt_print parses ANSI/VT100 escape
        'sequences. Supported: SGR (ESC[...m colours),
        'CUP (ESC[row;colH cursor), ED (ESC[2J clear).
        'Use Chr(27) or !"\x1b" for the escape byte --
        'do NOT use !"\e" as FreeBASIC drops \e silently.
        ':example
        'vt_locate(5, 1)
        'vt_color(VT_CYAN, VT_BLACK)
        'vt_print("Line one" & VT_LF & "Line two")
        'vt_present()
        ':see
        'vt_locate
        'vt_color
        'vt_cls
        'vt_print_center
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    Dim slen As Long = Len(txt)
    If slen = 0 Then Exit Sub

    txt  = vt_utf8_to_cp437(txt)
    slen = Len(txt)

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

'>>>
':topic vt_print_center
':short Print a string horizontally centred on a row
':group Printing
'Print a string horizontally centred on the
'given screen row. Uses the current colour and
'does not call vt_present.
':syntax
Sub vt_print_center(row As Long, txt As String)
        ':params
        'row  Target row, 1-based.
        'txt  The string to centre and print.
        ':example
        'vt_color(VT_YELLOW, VT_BLACK)
        'vt_print_center(12, "Hello, World!")
        'vt_color(VT_LIGHT_GREY, VT_BLACK)
        'vt_print_center(14, "Press any key...")
        'vt_sleep()
        ':see
        'vt_print
        'vt_color
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    Dim txt_len   As Long = Len(txt)
    Dim start_col As Long = (vt_internal.scr_cols - txt_len) \ 2 + 1
    If start_col < 1 Then start_col = 1
    vt_locate(row, start_col)
    vt_print(txt)
End Sub

#Undef vt_internal_scroll_up
#Undef vt_internal_putch
