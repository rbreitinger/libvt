'>>>
    ':topic vt_tui_dialog
    ':short Blocking modal dialog (opt-in)
    ':group Text UI
    'Self-contained blocking modal dialog. Saves the
    'background before drawing and restores it on
    'close. The text is word-wrapped automatically to
    'fit; the window grows to accommodate the wrapped
    'content and the button row. The dialog is centred
    'on screen (default 60 columns, clamped to screen
    'width minus 4).
    'Opt-in: define VT_USE_TUI before the include.
':syntax
Function vt_tui_dialog(caption As String, _
                       txt     As String, _
                       flags   As Long = _
                       VT_DLG_OK) As Long
        ':params
        'caption  Title bar text.
        'txt      Body text. Word-wrapped to fit width.
        'flags    Button set constant, optionally
        '         combined with VT_DLG_NO_ESC.
        ':notes
        'Return: one of VT_RET_OK, VT_RET_CANCEL,
        'VT_RET_YES, VT_RET_NO.
        '
        'Key/mouse bindings:
        '  Tab          Advance focus to next button.
        '  Left/Right   Move focus between buttons.
        '  Enter        Activate the focused button.
        '  Escape       Return VT_RET_CANCEL (unless
        '               VT_DLG_NO_ESC is set).
        '  Click        Activate clicked button immediately.
        ':example
        '' Quit confirmation:
        'If vt_tui_dialog("Quit", _
        '    "Are you sure you want to quit?", _
        '    VT_DLG_YESNO) = VT_RET_YES Then
        '    vt_shutdown()
        'End If
        '
        '' Mandatory choice (Escape disabled):
        'Dim r As Long = vt_tui_dialog("Disk Full", _
        '    "Retry or abort the operation?", _
        '    VT_DLG_OKCANCEL Or VT_DLG_NO_ESC)
        '
        '' Simple info box:
        'vt_tui_dialog("Done", "File saved successfully.")
        ':see
        'vt_tui_window
        'vt_tui_file_dialog
        'c_tuiconsts
    '<<<
    Dim btn_set       As Long
    Dim no_esc        As Byte
    Dim btn_count     As Long
    Dim btn_labels(2) As String
    Dim btn_rets(2)   As Long
    Dim btn_widths(2) As Long
    Dim btn_total_w   As Long
    Dim max_dlg_w     As Long
    Dim min_dlg_w     As Long
    Dim dlg_w         As Long
    Dim dlg_h         As Long
    Dim dlg_x         As Long
    Dim dlg_y         As Long
    Dim inner_w       As Long
    Dim text_w        As Long
    Dim wrapped       As String
    Dim wlines()      As String
    Dim line_count    As Long
    Dim saved()       As vt_cell
    Dim r             As Long
    Dim c             As Long
    Dim i             As Long
    Dim cel           As vt_cell Ptr
    Dim focused       As Long
    Dim dfg           As UByte
    Dim dbg           As UByte
    Dim bfg           As UByte
    Dim bbg           As UByte
    Dim btn_row       As Long
    Dim btn_start_x   As Long
    Dim btn_x         As Long
    Dim tlen          As Long
    Dim k             As ULong
    Dim sc            As Long
    Dim prev_btns     As Long
    Dim cur_btns      As Long
    Dim lmb_down      As Byte
    Dim result        As Long
    Dim pad           As Long
    
    _VT_TUI_GUARD_FN
    vt_internal_tui_autoinit()

    btn_set = flags And 7
    no_esc  = IIf((flags And VT_DLG_NO_ESC) <> 0, 1, 0)

    Select Case btn_set
        Case VT_DLG_OK
            btn_count     = 1
            btn_labels(0) = " OK "
            btn_rets(0)   = VT_RET_OK
        Case VT_DLG_OKCANCEL
            btn_count     = 2
            btn_labels(0) = " OK "
            btn_rets(0)   = VT_RET_OK
            btn_labels(1) = " Cancel "
            btn_rets(1)   = VT_RET_CANCEL
        Case VT_DLG_YESNO
            btn_count     = 2
            btn_labels(0) = " Yes "
            btn_rets(0)   = VT_RET_YES
            btn_labels(1) = " No "
            btn_rets(1)   = VT_RET_NO
        Case VT_DLG_YESNOCANCEL
            btn_count     = 3
            btn_labels(0) = " Yes "
            btn_rets(0)   = VT_RET_YES
            btn_labels(1) = " No "
            btn_rets(1)   = VT_RET_NO
            btn_labels(2) = " Cancel "
            btn_rets(2)   = VT_RET_CANCEL
        Case Else
            btn_count     = 1
            btn_labels(0) = " OK "
            btn_rets(0)   = VT_RET_OK
    End Select

    btn_total_w = 0
    For i = 0 To btn_count - 1
        btn_widths(i) = Len(btn_labels(i)) + 2
        btn_total_w  += btn_widths(i)
    Next i
    btn_total_w += (btn_count - 1) * 2

    max_dlg_w = vt_internal.scr_cols - 4
    If max_dlg_w < 20 Then max_dlg_w = 20
    min_dlg_w = btn_total_w + 6
    If Len(caption) + 4 > min_dlg_w Then min_dlg_w = Len(caption) + 4

    dlg_w = 60
    If dlg_w > max_dlg_w Then dlg_w = max_dlg_w
    If dlg_w < min_dlg_w Then dlg_w = min_dlg_w

    inner_w = dlg_w - 2
    text_w  = inner_w - 2

    wrapped    = vt_str_wordwrap(txt, text_w)
    line_count = vt_str_split(wrapped, Chr(10), wlines())

    dlg_h = line_count + 5

    dlg_x = (vt_internal.scr_cols - dlg_w) \ 2 + 1
    dlg_y = (vt_internal.scr_rows - dlg_h) \ 2 + 1
    If dlg_x < 1 Then dlg_x = 1
    If dlg_y < 1 Then dlg_y = 1

    btn_row     = dlg_y + dlg_h - 2
    btn_start_x = dlg_x + 1 + (inner_w - btn_total_w) \ 2

    vt_internal_tui_save_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())

    dfg       = vt_internal_tui_theme.dlg_fg
    dbg       = vt_internal_tui_theme.dlg_bg
    focused   = 0
    prev_btns = vt_internal.mouse_btns
    result    = VT_RET_CANCEL

    Do
        vt_tui_window(dlg_x, dlg_y, dlg_w, dlg_h, caption)
        vt_tui_rect_fill(dlg_x + 1, dlg_y + 1, inner_w, dlg_h - 2, 32, dfg, dbg)
        
        For r = 0 To line_count - 1
            tlen = Len(wlines(r))
            If tlen > text_w Then tlen = text_w
            pad  = (text_w - tlen) \ 2
            cel  = vt_internal.cells + (dlg_y + 1 + r) * vt_internal.scr_cols + dlg_x + 1 + pad
            For c = 0 To tlen - 1
                cel[c].ch = wlines(r)[c]
                cel[c].fg = dfg : cel[c].bg = dbg
            Next c
        Next r

        btn_x = btn_start_x
        For i = 0 To btn_count - 1
            If i = focused Then
                bfg = VT_TUI_INVERT_FG(dfg) : bbg = VT_TUI_INVERT_BG(dbg)
            Else
                bfg = vt_internal_tui_theme.btn_fg
                bbg = vt_internal_tui_theme.btn_bg
            End If
            vt_internal_tui_draw_button(btn_x, btn_row, btn_labels(i), bfg, bbg)
            btn_x += btn_widths(i) + 2
        Next i

        vt_internal.dirty = 1

        Do
            k        = vt_inkey()
            cur_btns = vt_internal.mouse_btns
            If k <> 0 Then Exit Do
            If (cur_btns And 1) <> (prev_btns And 1) Then Exit Do
            vt_sleep(10)
        Loop

        lmb_down  = VT_TUI_LMB_DOWN(cur_btns, prev_btns)
        prev_btns = cur_btns

        If k <> 0 Then
            If VT_TUI_KEY_IS(k, VT_TUI_ACT_CANCEL) Then
                If no_esc = 0 Then
                    result = VT_RET_CANCEL
                    GoTo dlg_done
                End If
            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_NEXT) Then
                focused += 1
                If focused >= btn_count Then focused = 0
            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_LEFT) Then
                If focused > 0 Then focused -= 1
            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_RIGHT) Then
                If focused < btn_count - 1 Then focused += 1
            ElseIf VT_SCAN(k) = VT_KEY_ENTER Then
                result = btn_rets(focused)
                GoTo dlg_done
            End If
        End If

        If lmb_down Then
            btn_x = btn_start_x
            For i = 0 To btn_count - 1
                If vt_tui_mouse_in_rect(btn_x, btn_row, btn_widths(i), 1) Then
                    result = btn_rets(i)
                    GoTo dlg_done
                End If
                btn_x += btn_widths(i) + 2
            Next i
        End If
    Loop

  dlg_done:
    vt_internal_tui_restore_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())
    Return result
End Function

'>>>
    ':topic vt_tui_file_dialog
    ':short Blocking file/directory picker (opt-in)
    ':group Text UI
    'Self-contained blocking file/directory picker.
    'Saves the background before drawing and restores
    'it on close. Centred on screen, automatically
    'sized (max 70 columns). The listing always
    'includes subdirectories (shown with trailing /)
    'and a .. entry when a parent exists. Files are
    'matched against pattern. All returned paths use
    'forward slashes on both Windows and Linux.
    'Opt-in: define VT_USE_TUI before the include.
':syntax
Function vt_tui_file_dialog(title      As String, _
                            start_path As String, _
                            pattern    As String, _
                            flags      As Long = 0) _
                            As String
        ':params
        'title       Title bar text and confirm button label.
        'start_path  Initial directory. Backslashes are
        '            normalized to forward slashes. Pass ""
        '            or "./" for the current directory.
        'pattern     Filename wildcard, e.g. "*.txt" or "*".
        '            Ignored when VT_TUI_FD_DIRSONLY is set.
        'flags       VT_TUI_FD_DIRSONLY = show only dirs;
        '            Enter or OK on a dir confirms it.
        ':notes
        'Return: full selected path as a String. Directory
        'paths end with /. "" on cancel.
        '
        'Key/mouse bindings:
        '  Up/Down/PgUp/PgDn/Home/End  Navigate list.
        '  Enter on a file    Confirm that file.
        '  Enter on a dir     Navigate into it (or
        '                     confirm in DIRSONLY mode).
        '  Double-click       Navigate dir or confirm file.
        '  Backspace          Delete last char from name
        '                     field, or navigate up a dir
        '                     if name field is empty.
        '  Tab                Activate name field for entry.
        '  Printable char     Append to name field.
        '  F2                 Keyboard OK button equivalent.
        '  Escape             Cancel, return "".
        '  
        ':example
        'Dim path As String = _
        '    vt_tui_file_dialog("Open", "./", "*.bas")
        'If Len(path) > 0 Then
        '    vt_print("Selected: " & path & VT_LF)
        'End If
        '
        '' Directory picker only:
        'path = vt_tui_file_dialog("Choose Folder", _
        '    "./", "*", VT_TUI_FD_DIRSONLY)
        ':see
        'vt_tui_dialog
        'vt_file_list
        'c_tuiconsts
    '<<<
    Dim dlg_w           As Long
    Dim dlg_h           As Long
    Dim dlg_x           As Long
    Dim dlg_y           As Long
    Dim list_hei        As Long
    Dim inner_w         As Long
    Dim item_w          As Long
    Dim list_x          As Long
    Dim list_y          As Long
    Dim path_row        As Long
    Dim name_row        As Long
    Dim btn_row         As Long
    Dim name_x          As Long
    Dim name_w          As Long
    Dim ok_x            As Long
    Dim cancel_x        As Long
    Dim ok_w            As Long
    Dim cancel_w        As Long
    Dim total_btn_w     As Long
    Dim cur_path        As String
    Dim fname           As String
    Dim fname_cpos      As Long
    Dim fname_active    As Byte
    Dim tmp_path        As String
    Dim dir_arr()       As String
    Dim file_arr()      As String
    Dim disp_arr()      As String
    Dim is_dir_arr()    As Byte
    Dim dir_count       As Long
    Dim file_count      As Long
    Dim disp_count      As Long
    Dim has_parent      As Byte
    Dim need_reload     As Byte
    Dim i               As Long
    Dim r               As Long
    Dim c               As Long
    Dim saved()         As vt_cell
    Dim cel             As vt_cell Ptr
    Dim sel             As Long
    Dim top_item        As Long
    Dim max_top         As Long
    Dim need_scroll     As Byte
    Dim thumb_row       As Long
    Dim item_idx        As Long
    Dim sep_pos         As Long
    Dim wfg             As UByte
    Dim wbg             As UByte
    Dim rfg             As UByte
    Dim rbg             As UByte
    Dim ifg             As UByte
    Dim ibg             As UByte
    Dim bfg             As UByte
    Dim bbg             As UByte
    Dim k               As ULong
    Dim sc              As Long
    Dim ch              As UByte
    Dim prev_btns       As Long
    Dim cur_btns        As Long
    Dim lmb_down        As Byte
    Dim clicked_row     As Long
    Dim clicked_idx     As Long
    Dim last_click_idx  As Long
    Dim last_click_time As Double
    Dim whl             As Long
    Dim txt             As String
    Dim tlen            As Long
    Dim lbl_str         As String
    Dim nav_moved       As Byte
    Dim vis_fname_cpos  As Long
    Dim result          As String

    _VT_TUI_GUARD_FN_STR
    vt_internal_tui_autoinit()

    cur_path = vt_str_replace(start_path, "\", "/")
    If Len(cur_path) = 0 Then cur_path = "./"
    If Right(cur_path, 1) <> "/" Then cur_path &= "/"

    list_hei = vt_internal.scr_rows - 10
    If list_hei < 5 Then list_hei = 5
    dlg_h = list_hei + 5
    If dlg_h > vt_internal.scr_rows - 2 Then
        dlg_h    = vt_internal.scr_rows - 2
        list_hei = dlg_h - 5
    End If

    dlg_w = vt_internal.scr_cols - 6
    If dlg_w > 70 Then dlg_w = 70
    If dlg_w < 40 Then dlg_w = 40
    inner_w = dlg_w - 2

    dlg_x = (vt_internal.scr_cols - dlg_w) \ 2 + 1
    dlg_y = (vt_internal.scr_rows - dlg_h) \ 2 + 1
    If dlg_x < 1 Then dlg_x = 1
    If dlg_y < 1 Then dlg_y = 1

    path_row = dlg_y + 1
    list_x   = dlg_x + 1
    list_y   = dlg_y + 2
    name_row = dlg_y + 2 + list_hei
    btn_row  = dlg_y + 3 + list_hei

    name_x = list_x + 6   ' 6 = Len("Name: ")
    name_w = inner_w - 6

    ok_w        = Len(title) + 4
    cancel_w    = 10
    total_btn_w = ok_w + cancel_w + 2
    ok_x        = dlg_x + 1 + (inner_w - total_btn_w) \ 2
    cancel_x    = ok_x + ok_w + 2

    vt_internal_tui_save_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())

    wfg = vt_internal_tui_theme.win_fg
    wbg = vt_internal_tui_theme.win_bg
    ifg = vt_internal_tui_theme.inp_fg
    ibg = vt_internal_tui_theme.inp_bg
    bfg = vt_internal_tui_theme.btn_fg
    bbg = vt_internal_tui_theme.btn_bg

    fname            = ""
    fname_cpos       = 0
    fname_active     = 0
    sel              = 0
    top_item         = 0
    last_click_idx   = -1
    last_click_time  = 0.0
    prev_btns        = vt_internal.mouse_btns
    result           = ""
    need_reload      = 1
    disp_count       = 0

    Do
        ' =====================================================================
        ' reload file list on directory change
        ' =====================================================================
        If need_reload Then
            need_reload = 0
            sel         = 0
            top_item    = 0
            fname       = ""
            fname_cpos  = 0
            fname_active = 0

            tmp_path   = Left(cur_path, Len(cur_path) - 1)
            sep_pos    = InStrRev(tmp_path, "/")
            has_parent = IIf(sep_pos > 0, 1, 0)

            dir_count = vt_file_list(cur_path, "*", dir_arr(), VT_FILE_DIRS_ONLY)
            If dir_count < 0 Then dir_count = 0

            If (flags And VT_TUI_FD_DIRSONLY) Then
                file_count = 0
            Else
                file_count = vt_file_list(cur_path, pattern, file_arr(), 0)
                If file_count < 0 Then file_count = 0
            End If

            disp_count = IIf(has_parent, 1, 0) + dir_count + file_count

            If disp_count > 0 Then
                ReDim disp_arr(disp_count - 1)
                ReDim is_dir_arr(disp_count - 1)
                i = 0
                If has_parent Then
                    disp_arr(0)   = ".."
                    is_dir_arr(0) = 1
                    i = 1
                End If
                For r = 0 To dir_count - 1
                    disp_arr(i)   = dir_arr(r) & "/"
                    is_dir_arr(i) = 1
                    i += 1
                Next r
                For r = 0 To file_count - 1
                    disp_arr(i)   = file_arr(r)
                    is_dir_arr(i) = 0
                    i += 1
                Next r
            End If

            max_top     = disp_count - list_hei
            If max_top < 0 Then max_top = 0
            need_scroll = IIf(disp_count > list_hei, 1, 0)
            item_w      = IIf(need_scroll, inner_w - 1, inner_w)
        End If

        ' =====================================================================
        ' redraw
        ' =====================================================================
        vt_tui_window(dlg_x, dlg_y, dlg_w, dlg_h, title)

        ' path display row
        cel = vt_internal.cells + (path_row - 1) * vt_internal.scr_cols + (list_x - 1)
        txt = cur_path
        If Len(txt) > inner_w Then txt = "..." & Right(txt, inner_w - 3)
        tlen = Len(txt)
        For c = 0 To inner_w - 1
            cel[c].ch = 32 : cel[c].fg = wfg : cel[c].bg = wbg
        Next c
        For c = 0 To tlen - 1
            cel[c].ch = txt[c]
        Next c

        ' list items
        For r = 0 To list_hei - 1
            item_idx = top_item + r
            cel      = vt_internal.cells + (list_y - 1 + r) * vt_internal.scr_cols + (list_x - 1)

            If item_idx = sel AndAlso fname_active = 0 Then
                rfg = VT_TUI_INVERT_FG(wfg) : rbg = VT_TUI_INVERT_BG(wbg)
            Else
                rfg = wfg : rbg = wbg
            End If

            For c = 0 To item_w - 1
                cel[c].ch = 32 : cel[c].fg = rfg : cel[c].bg = rbg
            Next c

            If item_idx >= 0 AndAlso item_idx < disp_count Then
                txt  = disp_arr(item_idx)
                tlen = Len(txt)
                If tlen > item_w Then tlen = item_w
                For c = 0 To tlen - 1
                    cel[c].ch = txt[c]
                Next c
            End If
        Next r

        ' scrollbar
        If need_scroll AndAlso disp_count > list_hei Then
            thumb_row = top_item * (list_hei - 1) \ (disp_count - list_hei)
            vt_internal_tui_draw_scrollbar(list_x + inner_w - 1, list_y, list_hei, thumb_row, wfg, wbg)
        End If

        ' name row: label + input field
        cel = vt_internal.cells + (name_row - 1) * vt_internal.scr_cols + (list_x - 1)
        For c = 0 To inner_w - 1
            cel[c].ch = 32 : cel[c].fg = wfg : cel[c].bg = wbg
        Next c
        lbl_str = "Name: "
        For c = 0 To Len(lbl_str) - 1
            cel[c].ch = lbl_str[c]
        Next c
        For c = 0 To name_w - 1
            cel[6 + c].fg = ifg : cel[6 + c].bg = ibg
            cel[6 + c].ch = 32
        Next c
        txt = fname
        If Len(txt) > name_w Then txt = Right(txt, name_w)
        For c = 0 To Len(txt) - 1
            cel[6 + c].ch = txt[c]
        Next c

        ' cursor in name field when active
        If fname_active Then
            vis_fname_cpos = fname_cpos
            If vis_fname_cpos >= name_w Then vis_fname_cpos = name_w - 1
            vt_internal.cur_visible = 1
            vt_locate(name_row, name_x + vis_fname_cpos)
        Else
            vt_internal.cur_visible = 0
        End If

        ' OK and Cancel buttons
        vt_internal_tui_draw_button(ok_x,     btn_row, " " & title & " ", bfg, bbg)
        vt_internal_tui_draw_button(cancel_x, btn_row, " Cancel ",        bfg, bbg)

        vt_internal.dirty = 1

        ' =====================================================================
        ' wait for input
        ' =====================================================================
        Do
            k        = vt_inkey()
            cur_btns = vt_internal.mouse_btns
            If k <> 0 Then Exit Do
            If (cur_btns And 1) <> (prev_btns And 1) Then Exit Do
            If vt_internal.mouse_wheel <> 0 Then Exit Do
            vt_sleep(10)
        Loop

        lmb_down  = VT_TUI_LMB_DOWN(cur_btns, prev_btns)
        prev_btns = cur_btns

        ' =====================================================================
        ' mouse wheel -- always scrolls the list
        ' =====================================================================
        whl = vt_internal.mouse_wheel
        If whl <> 0 Then
            vt_internal.mouse_wheel = 0
            If vt_tui_mouse_in_rect(list_x, list_y, inner_w, list_hei) Then
                top_item -= whl
                If top_item < 0       Then top_item = 0
                If top_item > max_top Then top_item = max_top
                If sel < top_item              Then sel = top_item
                If sel >= top_item + list_hei  Then sel = top_item + list_hei - 1
            End If
        End If

        ' =====================================================================
        ' keyboard
        ' =====================================================================
        If k <> 0 Then
            sc        = VT_SCAN(k)
            ch        = VT_CHAR(k)
            nav_moved = 0

            ' Tab toggles focus between list and name field
            If VT_TUI_KEY_IS(k, VT_TUI_ACT_NEXT) Then
                fname_active = 1 - fname_active
                fname_cpos   = Len(fname)

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_CANCEL) Then
                GoTo fd_done

            ElseIf fname_active Then
                ' --- name field editing ---
                If VT_TUI_KEY_IS(k, VT_TUI_ACT_LEFT) Then
                    If fname_cpos > 0 Then fname_cpos -= 1
                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_RIGHT) Then
                    If fname_cpos < Len(fname) Then fname_cpos += 1
                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_HOME) Then
                    fname_cpos = 0
                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_END) Then
                    fname_cpos = Len(fname)
                ElseIf sc = VT_KEY_BKSP Then
                    If fname_cpos > 0 Then
                        fname      = Left(fname, fname_cpos - 1) & Mid(fname, fname_cpos + 1)
                        fname_cpos -= 1
                    End If
                ElseIf sc = VT_KEY_DEL Then
                    If fname_cpos < Len(fname) Then
                        fname = Left(fname, fname_cpos) & Mid(fname, fname_cpos + 2)
                    End If
                ElseIf sc = VT_KEY_ENTER OrElse sc = VT_KEY_F2 Then
                    If Len(fname) > 0 Then
                        result = cur_path & fname
                        GoTo fd_done
                    End If
                ElseIf ch >= 32 AndAlso Len(fname) < name_w Then
                    fname      = Left(fname, fname_cpos) & Chr(ch) & Mid(fname, fname_cpos + 1)
                    fname_cpos += 1
                End If

            Else
                ' --- list navigation ---
                If VT_TUI_KEY_IS(k, VT_TUI_ACT_UP) Then
                    If sel > 0 Then
                        sel -= 1
                        If sel < top_item Then top_item = sel
                    End If
                    nav_moved = 1

                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_DOWN) Then
                    If sel < disp_count - 1 Then
                        sel += 1
                        If sel >= top_item + list_hei Then top_item = sel - list_hei + 1
                    End If
                    nav_moved = 1

                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGUP) Then
                    sel -= list_hei
                    If sel < 0 Then sel = 0
                    If sel < top_item Then top_item = sel
                    nav_moved = 1

                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGDN) Then
                    sel += list_hei
                    If sel >= disp_count Then sel = disp_count - 1
                    If sel >= top_item + list_hei Then
                        top_item = sel - list_hei + 1
                        If top_item > max_top Then top_item = max_top
                    End If
                    nav_moved = 1

                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_HOME) Then
                    sel       = 0
                    top_item  = 0
                    nav_moved = 1

                ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_END) Then
                    If disp_count > 0 Then sel = disp_count - 1
                    top_item  = max_top
                    nav_moved = 1

                ElseIf sc = VT_KEY_ENTER Then
                    If disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count Then
                        If is_dir_arr(sel) Then
                            If disp_arr(sel) = ".." Then
                                sep_pos = InStrRev(tmp_path, "/")
                                If sep_pos > 0 Then cur_path = Left(tmp_path, sep_pos)
                                need_reload = 1
                            ElseIf (flags And VT_TUI_FD_DIRSONLY) Then
                                result = cur_path & disp_arr(sel)
                                GoTo fd_done
                            Else
                                cur_path &= Left(disp_arr(sel), Len(disp_arr(sel)) - 1) & "/"
                                need_reload = 1
                            End If
                        Else
                            result = cur_path & disp_arr(sel)
                            GoTo fd_done
                        End If
                    ElseIf Len(fname) > 0 Then
                        result = cur_path & fname
                        GoTo fd_done
                    End If

                ElseIf sc = VT_KEY_F2 Then
                    If (flags And VT_TUI_FD_DIRSONLY) Then
                        If disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count _
                           AndAlso disp_arr(sel) <> ".." Then
                            result = cur_path & disp_arr(sel)
                        Else
                            result = cur_path
                        End If
                        GoTo fd_done
                    ElseIf Len(fname) > 0 Then
                        result = cur_path & fname
                        GoTo fd_done
                    ElseIf disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count Then
                        If is_dir_arr(sel) = 0 Then
                            result = cur_path & disp_arr(sel)
                            GoTo fd_done
                        End If
                    End If

                ElseIf sc = VT_KEY_BKSP Then
                    If Len(fname) > 0 Then
                        fname      = Left(fname, Len(fname) - 1)
                        fname_cpos = Len(fname)
                    ElseIf has_parent Then
                        sep_pos = InStrRev(tmp_path, "/")
                        If sep_pos > 0 Then cur_path = Left(tmp_path, sep_pos)
                        need_reload = 1
                    End If

                ElseIf ch >= 32 AndAlso Len(fname) < name_w Then
                    fname      &= Chr(ch)
                    fname_cpos  = Len(fname)

                End If

                ' update name field for all navigation keys
                If nav_moved AndAlso sel >= 0 AndAlso sel < disp_count Then
                    If (flags And VT_TUI_FD_DIRSONLY) Then
                        If disp_arr(sel) <> ".." Then
                            fname = Left(disp_arr(sel), Len(disp_arr(sel)) - 1)
                        Else
                            fname = ""
                        End If
                    ElseIf is_dir_arr(sel) = 0 Then
                        fname = disp_arr(sel)
                    End If
                    fname_cpos = Len(fname)
                End If

            End If  ' fname_active / list nav
        End If  ' k <> 0

        ' =====================================================================
        ' mouse clicks
        ' =====================================================================
        If lmb_down Then

            ' list area
            If vt_tui_mouse_in_rect(list_x, list_y, item_w, list_hei) Then
                clicked_row = vt_internal.mouse_row - list_y
                clicked_idx = top_item + clicked_row
                If clicked_idx >= 0 AndAlso clicked_idx < disp_count Then
                    fname_active = 0
                    sel = clicked_idx
                    ' update fname on single click
                    If (flags And VT_TUI_FD_DIRSONLY) Then
                        If disp_arr(sel) <> ".." Then
                            fname = Left(disp_arr(sel), Len(disp_arr(sel)) - 1)
                        Else
                            fname = ""
                        End If
                    ElseIf is_dir_arr(sel) = 0 Then
                        fname = disp_arr(sel)
                    End If
                    fname_cpos = Len(fname)

                    If clicked_idx = last_click_idx AndAlso _
                       (Timer() - last_click_time) < 0.5 Then
                        ' double-click
                        If is_dir_arr(clicked_idx) Then
                            If disp_arr(clicked_idx) = ".." Then
                                sep_pos = InStrRev(tmp_path, "/")
                                If sep_pos > 0 Then cur_path = Left(tmp_path, sep_pos)
                            ElseIf (flags And VT_TUI_FD_DIRSONLY) Then
                                result = cur_path & disp_arr(clicked_idx)
                                GoTo fd_done
                            Else
                                cur_path &= Left(disp_arr(clicked_idx), Len(disp_arr(clicked_idx)) - 1) & "/"
                            End If
                            need_reload     = 1
                            last_click_idx  = -1
                            last_click_time = 0.0
                        Else
                            result = cur_path & disp_arr(clicked_idx)
                            GoTo fd_done
                        End If
                    Else
                        last_click_idx  = clicked_idx
                        last_click_time = Timer()
                    End If
                End If
            End If

            ' name field: activate inline editing
            If vt_tui_mouse_in_rect(name_x, name_row, name_w, 1) Then
                fname_active = 1
                ' snap cursor to click column, clamped to actual text
                fname_cpos = vt_internal.mouse_col - name_x
                If fname_cpos > Len(fname) Then fname_cpos = Len(fname)
                If fname_cpos < 0 Then fname_cpos = 0
            End If

            ' OK button
            If vt_tui_mouse_in_rect(ok_x, btn_row, ok_w, 1) Then
                If (flags And VT_TUI_FD_DIRSONLY) Then
                    If disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count _
                       AndAlso disp_arr(sel) <> ".." Then
                        result = cur_path & disp_arr(sel)
                    Else
                        result = cur_path
                    End If
                    GoTo fd_done
                ElseIf Len(fname) > 0 Then
                    result = cur_path & fname
                    GoTo fd_done
                ElseIf disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count Then
                    If is_dir_arr(sel) = 0 Then
                        result = cur_path & disp_arr(sel)
                        GoTo fd_done
                    End If
                End If
            End If

            ' Cancel button
            If vt_tui_mouse_in_rect(cancel_x, btn_row, cancel_w, 1) Then
                GoTo fd_done
            End If

        End If  ' lmb_down
    Loop

  fd_done:
    vt_internal.cur_visible = 0
    vt_internal_tui_restore_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())
    Return result
End Function