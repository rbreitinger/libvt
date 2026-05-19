' Compute 0-based visual line and column for byte offset pos in work,
' given display width wid. Matches the draw render loop exactly.
Private Sub vt_tui_ed_vis_pos(work As String, wid As Long, ipos As Long, _
                               ByRef vln As Long, ByRef vcol As Long)
    Dim scan As Long = 0
    Dim col  As Long = 0
    Dim wlen As Long = Len(work)
    vln = 0
    Do While scan < ipos
        If scan >= wlen Then Exit Do
        If work[scan] = 10 Then
            vln  += 1
            col   = 0
            scan += 1
        Else
            col  += 1
            scan += 1
            If col >= wid Then
                ' consume a Chr(10) sitting right at the wrap boundary
                ' (a logical line exactly wid chars long must not add a blank row)
                If scan < wlen AndAlso work[scan] = 10 Then scan += 1
                vln += 1
                col  = 0
            End If
        End If
    Loop
    vcol = col
End Sub

' Return the byte offset of the start of visual line tgt_vln.
Private Function vt_tui_ed_vis_to_byte(work As String, wid As Long, _
                                        tgt_vln As Long) As Long
    Dim scan As Long = 0
    Dim col  As Long = 0
    Dim vln  As Long = 0
    Dim wlen As Long = Len(work)
    Do While scan < wlen AndAlso vln < tgt_vln
        If work[scan] = 10 Then
            vln  += 1
            col   = 0
            scan += 1
        Else
            col  += 1
            scan += 1
            If col >= wid Then
                If scan < wlen AndAlso work[scan] = 10 Then scan += 1
                vln += 1
                col  = 0
            End If
        End If
    Loop
    Return scan
End Function

'>>>
    ':topic vt_tui_editor_*
    ':short Non-blocking multi-line editor/viewer
    ':group Text UI
    'Non-blocking multi-line editor and viewer.
    'Two-function design: vt_tui_editor_draw renders
    'the visible text each frame; vt_tui_editor_handle
    'processes one key or mouse event and returns
    'immediately. The caller owns the
    'vt_tui_editor_state struct. Text is stored as a
    'single String with Chr(10) line separators.
    'Lines exceeding wid are truncated in display; no
    'horizontal scrolling. Uses theme's inp_fg/inp_bg.
    'NOTE: call vt_tui_editor_draw LAST in your loop,
    'after any status bars or labels that use
    'vt_locate. The draw function sets the text cursor
    'position; any vt_locate after it moves the cursor
    'to the wrong place before vt_sleep flips the frame.
    'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_editor_draw(x   As Long, y   As Long, _
                       wid As Long, hei As Long, _
                       ByRef st As vt_tui_editor_state)             
        ':params
        'x, y     1-based top-left of the editing area.
        'wid, hei Width and height in cells.
        'st       Caller-owned state. Pass same struct to
        '         both functions every frame.
        'k        Key value from vt_inkey() this frame.
        ':notes
        'Return (vt_tui_editor_handle):
        '  VT_FORM_PENDING(-2)  Always while editing.
        '  VT_FORM_CANCEL(-1)   Escape pressed.
        '  Check st.dirty to know if edits were made.
        '
        'vt_tui_editor_state fields:
        '  work    As String  ' text buffer (Chr(10) newlines)
        '  cpos    As Long    ' byte cursor offset -- init 0
        '  top_ln  As Long    ' first visible line -- init 0
        '  dirty   As Byte    ' 0 until first edit
        '  flags   As Long    ' VT_TUI_ED_READONLY etc.
        '
        'Key/mouse bindings:
        '  Up/Down          Move cursor one line.
        '  PgUp/PgDn        Move by hei lines.
        '  Left/Right       Move cursor one character.
        '  Home/End         Start/end of current line.
        '  Enter            Insert newline (edit mode only).
        '  Backspace/Del    Delete (edit mode only).
        '  Printable char   Insert at cursor (edit only).
        '  Escape           Return VT_FORM_CANCEL.
        '  Scroll wheel     Scroll the view (both modes).
        '  
        ':example
        'Dim st As vt_tui_editor_state
        'st.work   = "First line" & Chr(10) & "Second line"
        'st.cpos   = 0
        'st.top_ln = 0
        'st.dirty  = 0
        'st.flags  = 0
        '
        'vt_tui_window(5, 3, 70, 20, " Notes ")
        'Dim result As Long = VT_FORM_PENDING
        'Dim k As ULong
        'Do While result = VT_FORM_PENDING
        '    k = vt_inkey()
        '    result = vt_tui_editor_handle(6, 4, 68, 18, st, k)
        '    vt_color(VT_BLACK, VT_CYAN)
        '    vt_locate(24, 1)
        '    vt_print(" Esc=Close" & _
        '             IIf(st.dirty, "  *modified*", ""))
        '    vt_tui_editor_draw(6, 4, 68, 18, st)
        '    vt_sleep(16)
        'Loop
        ':see
        'vt_tui_window
        'vt_tui_form_*
        'c_tuiconsts
    '<<<

    Dim vis_cur_line As Long
    Dim vis_cur_col  As Long
    Dim total_vis    As Long
    Dim total_vis_c  As Long
    Dim scan_pos     As Long
    Dim wlen         As Long
    Dim readonly_f   As Byte
    Dim r            As Long
    Dim c            As Long
    Dim cel          As vt_cell Ptr
    Dim ifg          As UByte
    Dim ibg          As UByte

    _VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    readonly_f = IIf((st.flags And VT_TUI_ED_READONLY) <> 0, 1, 0)
    ifg        = vt_internal_tui_theme.inp_fg
    ibg        = vt_internal_tui_theme.inp_bg
    wlen       = Len(st.work)

    ' cursor position in visual-line space
    vt_tui_ed_vis_pos(st.work, wid, st.cpos, vis_cur_line, vis_cur_col)

    ' total visual lines (needed for readonly top_ln clamping)
    vt_tui_ed_vis_pos(st.work, wid, wlen, total_vis, total_vis_c)
    total_vis += 1  ' vis_pos returns 0-based line index at end; +1 = count

    ' clamp top_ln
    If readonly_f <> 0 Then
        Dim max_top As Long = total_vis - hei
        If max_top < 0 Then max_top = 0
        If st.top_ln > max_top Then st.top_ln = max_top
        If st.top_ln < 0 Then st.top_ln = 0
    Else
        If vis_cur_line < st.top_ln Then st.top_ln = vis_cur_line
        If vis_cur_line >= st.top_ln + hei Then st.top_ln = vis_cur_line - hei + 1
        If st.top_ln < 0 Then st.top_ln = 0
    End If

    ' byte offset of the first visible visual row
    scan_pos = vt_tui_ed_vis_to_byte(st.work, wid, st.top_ln)

    ' render hei visual rows
    For r = 0 To hei - 1
        cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
        For c = 0 To wid - 1
            cel[c].ch = 32 : cel[c].fg = ifg : cel[c].bg = ibg
        Next c
        c = 0
        Do While c < wid AndAlso scan_pos < wlen AndAlso st.work[scan_pos] <> 10
            cel[c].ch = st.work[scan_pos]
            cel[c].fg = ifg : cel[c].bg = ibg
            c        += 1
            scan_pos += 1
        Loop
        ' advance past newline -- covers both a Chr(10) at a natural line end
        ' and a Chr(10) that sits exactly at a wrap boundary
        If scan_pos < wlen AndAlso st.work[scan_pos] = 10 Then scan_pos += 1
    Next r

    If readonly_f = 0 Then
        vt_internal.cur_visible = 1
        If vis_cur_line >= st.top_ln AndAlso vis_cur_line < st.top_ln + hei Then
            vt_locate(y + vis_cur_line - st.top_ln, x + vis_cur_col)
        End If
    Else
        vt_internal.cur_visible = 0
    End If

    vt_internal.dirty = 1
End Sub

' =============================================================================
    ' vt_tui_editor_handle
    ' Non-blocking event handler for the editor. Call with vt_inkey() each frame.
    ' Pass the same (x, y, wid, hei) as vt_tui_editor_draw.
    ' Modifies st.work, st.cpos, st.top_ln in place. Sets st.dirty on first edit.
    '
    ' In read-only mode (VT_TUI_ED_READONLY in st.flags):
    '   Up/Down/PgUp/PgDn/Home/End scroll the view. All edits are suppressed.
    ' In edit mode:
    '   Navigation keys move the cursor. Printable chars and Enter insert text.
    '   Backspace and Delete remove characters.
    '
    ' Returns VT_FORM_PENDING while editing is ongoing.
    ' Returns VT_FORM_CANCEL when Escape is pressed -- caller decides how to respond.
    ' Mouse wheel scrolls the view (both modes).
    ' All navigation keys are read from the keymap (see vt_tui_keymap_default).
' =============================================================================
Function vt_tui_editor_handle(x As Long, y As Long, wid As Long, hei As Long, _
                               ByRef st As vt_tui_editor_state, k As ULong) As Long
    Dim cur_line      As Long
    Dim cur_col       As Long
    Dim ln_start      As Long
    Dim prev_nl       As Long
    Dim prev_ln_start As Long
    Dim prev_ln_len   As Long
    Dim next_ln_start As Long
    Dim next_ln_len   As Long
    Dim tgt_line      As Long
    Dim new_col       As Long
    Dim ln_ctr        As Long
    Dim readonly_f    As Byte
    Dim i             As Long
    Dim p             As Long
    Dim q             As Long
    Dim sc            As Long
    Dim ch            As UByte
    Dim whl           As Long

    _VT_TUI_GUARD_FN

    readonly_f = IIf((st.flags And VT_TUI_ED_READONLY) <> 0, 1, 0)
    
    ' derive cursor position context (needed for all navigation)
    cur_line = 0
    ln_start = 0
    For i = 0 To st.cpos - 1
        If st.work[i] = 10 Then
            cur_line += 1
            ln_start  = i + 1
        End If
    Next i
    cur_col = st.cpos - ln_start

    ' mouse wheel scroll
    whl = vt_internal.mouse_wheel
    If whl <> 0 Then
        vt_internal.mouse_wheel = 0
        st.top_ln -= whl
        If st.top_ln < 0 Then st.top_ln = 0
        ' snap cpos into the visible area so the cursor-lock clamp in draw
        ' doesn't fight the wheel scroll -- now in visual-line space
        Dim vis_ln As Long
        Dim vis_vc As Long
        vt_tui_ed_vis_pos(st.work, wid, st.cpos, vis_ln, vis_vc)
        If vis_ln < st.top_ln OrElse vis_ln >= st.top_ln + hei Then
            st.cpos = vt_tui_ed_vis_to_byte(st.work, wid, st.top_ln)
        End If
    End If

    ' paste  (Shift+INS or MMB sets cp_paste_pend in vt_pump)
    ' Must come before the k=0 early-out so MMB paste is not swallowed.
    If vt_internal.cp_paste_pend Then
        vt_internal.cp_paste_pend = 0
        If readonly_f = 0 Then
            Dim clip_ptr As ZString Ptr = _VT_DRV_GetClipboardText()
            If clip_ptr <> 0 Then
                Dim clip_str As String = *clip_ptr
                _VT_DRV_free(clip_ptr)
                Dim pi  As Long
                Dim pch As UByte
                For pi = 0 To Len(clip_str) - 1
                    pch = clip_str[pi]
                    If pch = 13 Then Continue For   ' skip CR, LF handled below
                    If pch = 10 Then
                        st.work  = Left(st.work, st.cpos) & Chr(10) & Mid(st.work, st.cpos + 1)
                        st.cpos += 1
                        st.dirty = 1
                    ElseIf pch >= 32 AndAlso pch <= 126 Then
                        st.work  = Left(st.work, st.cpos) & Chr(pch) & Mid(st.work, st.cpos + 1)
                        st.cpos += 1
                        st.dirty = 1
                    End If
                Next pi
            End If
        End If
    End If

    If k = 0 Then Return VT_FORM_PENDING

    sc = VT_SCAN(k)
    ch = VT_CHAR(k)

    If VT_TUI_KEY_IS(k, VT_TUI_ACT_CANCEL) Then Return VT_FORM_CANCEL

    If VT_TUI_KEY_IS(k, VT_TUI_ACT_LEFT) Then
        If st.cpos > 0 Then st.cpos -= 1

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_RIGHT) Then
        If st.cpos < Len(st.work) Then st.cpos += 1

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_HOME) Then
        st.cpos = ln_start

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_END) Then
        p = ln_start
        Do While p < Len(st.work) AndAlso st.work[p] <> 10
            p += 1
        Loop
        st.cpos = p

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_UP) Then
        If cur_line > 0 Then
            prev_nl = -1
            p = ln_start - 2
            Do While p >= 0
                If st.work[p] = 10 Then
                    prev_nl = p
                    Exit Do
                End If
                p -= 1
            Loop
            prev_ln_start = IIf(prev_nl >= 0, prev_nl + 1, 0)
            prev_ln_len   = (ln_start - 1) - prev_ln_start
            new_col = cur_col
            If new_col > prev_ln_len Then new_col = prev_ln_len
            st.cpos = prev_ln_start + new_col
        End If

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_DOWN) Then
        p = ln_start
        Do While p < Len(st.work) AndAlso st.work[p] <> 10
            p += 1
        Loop
        If p < Len(st.work) Then
            next_ln_start = p + 1
            q = next_ln_start
            Do While q < Len(st.work) AndAlso st.work[q] <> 10
                q += 1
            Loop
            next_ln_len = q - next_ln_start
            new_col = cur_col
            If new_col > next_ln_len Then new_col = next_ln_len
            st.cpos = next_ln_start + new_col
        End If

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGUP) Then
        tgt_line = cur_line - hei
        If tgt_line < 0 Then tgt_line = 0
        p      = 0
        ln_ctr = 0
        Do While p < Len(st.work) AndAlso ln_ctr < tgt_line
            If st.work[p] = 10 Then ln_ctr += 1
            p += 1
        Loop
        q = p
        Do While q < Len(st.work) AndAlso st.work[q] <> 10
            q += 1
        Loop
        new_col = cur_col
        If new_col > q - p Then new_col = q - p
        st.cpos = p + new_col

    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGDN) Then
        tgt_line = cur_line + hei
        p      = 0
        ln_ctr = 0
        Do While p < Len(st.work) AndAlso ln_ctr < tgt_line
            If st.work[p] = 10 Then ln_ctr += 1
            p += 1
        Loop
        If p > Len(st.work) Then p = Len(st.work)
        q = p
        Do While q < Len(st.work) AndAlso st.work[q] <> 10
            q += 1
        Loop
        new_col = cur_col
        If new_col > q - p Then new_col = q - p
        st.cpos = p + new_col

    ElseIf sc = VT_KEY_BKSP Then
        If readonly_f = 0 AndAlso st.cpos > 0 Then
            st.work  = Left(st.work, st.cpos - 1) & Mid(st.work, st.cpos + 1)
            st.cpos -= 1
            st.dirty = 1
        End If

    ElseIf sc = VT_KEY_DEL Then
        If readonly_f = 0 AndAlso st.cpos < Len(st.work) Then
            st.work  = Left(st.work, st.cpos) & Mid(st.work, st.cpos + 2)
            st.dirty = 1
        End If

    ElseIf sc = VT_KEY_ENTER Then
        If readonly_f = 0 Then
            st.work  = Left(st.work, st.cpos) & Chr(10) & Mid(st.work, st.cpos + 1)
            st.cpos += 1
            st.dirty = 1
        End If

    ElseIf ch >= 32 Then
        If readonly_f = 0 Then
            st.work  = Left(st.work, st.cpos) & Chr(ch) & Mid(st.work, st.cpos + 1)
            st.cpos += 1
            st.dirty = 1
        End If

    End If

    Return VT_FORM_PENDING
End Function