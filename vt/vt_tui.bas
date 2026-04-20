' =============================================================================
' vt_tui.bas - TUI opt-in extension for the VT Virtual Text Screen Library
' =============================================================================
#Include Once "vt_strings.bas"
#Include Once "vt_file.bas"

#Define VT_TUI_INVERT_FG(fg)  ((fg) Xor 15)
#Define VT_TUI_INVERT_BG(bg)  ((bg) Xor 15)

' Guard macros -- place at top of any Sub/Function that draws or reads input.
' Theme setters and pure variable writers do NOT need these.
#Define VT_TUI_GUARD_SUB     If vt_internal.ready = 0 Then Exit Sub
#Define VT_TUI_GUARD_FN      If vt_internal.ready = 0 Then Return 0
#Define VT_TUI_GUARD_FN_STR  If vt_internal.ready = 0 Then Return ""

' Left mouse button edge detection: 1 on the frame the LMB transitions from
' up to down, 0 otherwise. cur/prev are the current and previous mouse_btns.
#Define VT_TUI_LMB_DOWN(cur, prev)  IIf(((cur) And 1) <> 0 AndAlso ((prev) And 1) = 0, 1, 0)

' =============================================================================
' Return codes
' =============================================================================
Enum VT_TUI_RET
    VT_RET_CANCEL   ' 0
    VT_RET_OK       ' 1
    VT_RET_YES      ' 2
    VT_RET_NO       ' 3
End Enum

' =============================================================================
' Dialog button set flags  (combinable: VT_DLG_YESNOCANCEL Or VT_DLG_NO_ESC)
' =============================================================================
Const VT_DLG_OK          = 1
Const VT_DLG_OKCANCEL    = 2
Const VT_DLG_YESNO       = 3
Const VT_DLG_YESNOCANCEL = 4
Const VT_DLG_NO_ESC      = 8   ' Escape does nothing -- mandatory choice

' =============================================================================
' Widget flags
' =============================================================================
Const VT_TUI_WIN_CLOSEBTN = 1   ' vt_tui_window: render [x] in title bar
Const VT_TUI_WIN_SHADOW   = 2
Const VT_TUI_PROG_LABEL   = 1   ' vt_tui_progress: print centred nn% label
Const VT_TUI_FD_DIRS      = 1   ' vt_tui_file_dialog: include subdirs in list
Const VT_TUI_FD_DIRSONLY  = 2   ' vt_tui_file_dialog: subdirs only
Const VT_TUI_ED_READONLY  = 1   ' vt_tui_editor: view/scroll only, no editing

' =============================================================================
' Form item kinds
' =============================================================================
Const VT_FORM_INPUT    = 0   ' single-line text input
Const VT_FORM_BUTTON   = 1   ' push button
Const VT_FORM_CHECKBOX = 2  ' toggleable  [ ] / [x]
Const VT_FORM_RADIO    = 3  ' radio in group  ( ) / (*)

' Form return codes (vt_tui_form_handle)
Const VT_FORM_PENDING = -2  ' still editing -- call again next frame
Const VT_FORM_CANCEL  = -1  ' Escape was pressed
' any value >= 0 is the .ret of the activated button (incl. VT_RET_CANCEL = 0)

' =============================================================================
' Menu return value extraction macros
' return value = group * 1000 + item_index,  0 = cancelled
' =============================================================================
#Define VT_TUI_MENU_GROUP(r)  ((r) \ 1000)
#Define VT_TUI_MENU_ITEM(r)   ((r) Mod 1000)

' =============================================================================
' Theme
' =============================================================================
Type vt_internal_tui_theme_state
    win_fg       As UByte   ' window body text
    win_bg       As UByte   ' window body background
    title_fg     As UByte   ' title bar text
    title_bg     As UByte   ' title bar background
    bar_fg       As UByte   ' status bar text
    bar_bg       As UByte   ' status bar background
    btn_fg       As UByte   ' button normal text
    btn_bg       As UByte   ' button normal background
    dlg_fg       As UByte   ' dialog body text
    dlg_bg       As UByte   ' dialog body background
    inp_fg       As UByte   ' input field text
    inp_bg       As UByte   ' input field background
    border_style As UByte   ' 0 = single line (CP437), 1 = double line (CP437)
End Type

Dim Shared vt_internal_tui_theme          As vt_internal_tui_theme_state
Dim Shared vt_internal_tui_inited         As Byte
Dim Shared vt_internal_tui_menu_prev_btns As Long
Dim Shared vt_internal_tui_form_prev_btns As Long

' =============================================================================
' vt_tui_form_item
' Describes one element of a form. Caller owns the array and all .val strings.
' .cpos and .view_off are managed internally by vt_tui_form_handle -- set them
' to 0 when initialising your items array and do not modify them afterward.
' Button width on screen is always Len(.val) + 2 (the enclosing [ and ]).
' Future kinds (checkboxes, radio buttons, etc.) extend this same Type.
' =============================================================================
Type vt_tui_form_item
    kind     As UByte   ' VT_FORM_INPUT or VT_FORM_BUTTON
    x        As Long    ' 1-based column
    y        As Long    ' 1-based row
    wid      As Long    ' input: visible field width; ignored for buttons
    val      As String  ' input: current text; button: label e.g. " OK "
    ret      As Long    ' button: return value on activation; input: unused
    max_len  As Long    ' input: max chars allowed (0 = use wid); button: unused
    cpos     As Long    ' internal: byte cursor offset -- managed by form_handle
    view_off As Long    ' internal: horizontal scroll offset -- managed by form_handle
    checked  As Byte    ' checkbox/radio: 0=unchecked, 1=checked. unused for input/button.
    group_id As Long    ' radio only: items with same group_id are mutually exclusive.
                        ' 0 = no group (use for checkboxes). unused for input/button.
End Type

' -----------------------------------------------------------------------------
' vt_tui_theme_default - reset theme to DOS/BIOS defaults
' No ready guard -- pure struct write, screen not required.
' -----------------------------------------------------------------------------
Sub vt_tui_theme_default()
    vt_internal_tui_theme.win_fg       = VT_BLACK
    vt_internal_tui_theme.win_bg       = VT_LIGHT_GREY
    vt_internal_tui_theme.title_fg     = VT_WHITE
    vt_internal_tui_theme.title_bg     = VT_BLUE
    vt_internal_tui_theme.bar_fg       = VT_BLACK
    vt_internal_tui_theme.bar_bg       = VT_CYAN
    vt_internal_tui_theme.btn_fg       = VT_BLACK
    vt_internal_tui_theme.btn_bg       = VT_LIGHT_GREY
    vt_internal_tui_theme.dlg_fg       = VT_BLACK
    vt_internal_tui_theme.dlg_bg       = VT_LIGHT_GREY
    vt_internal_tui_theme.inp_fg       = VT_WHITE
    vt_internal_tui_theme.inp_bg       = VT_DARK_GREY
    vt_internal_tui_theme.border_style = 0
    vt_internal_tui_inited             = 1
End Sub

' -----------------------------------------------------------------------------
' vt_tui_theme - set all theme values in one call
' No ready guard -- pure struct write, screen not required.
' -----------------------------------------------------------------------------
Sub vt_tui_theme(win_fg As UByte, win_bg As UByte, _
                 title_fg As UByte, title_bg As UByte, _
                 bar_fg As UByte, bar_bg As UByte, _
                 btn_fg As UByte, btn_bg As UByte, _
                 dlg_fg As UByte, dlg_bg As UByte, _
                 inp_fg As UByte, inp_bg As UByte, _
                 border_style As UByte)
    vt_internal_tui_theme.win_fg       = win_fg
    vt_internal_tui_theme.win_bg       = win_bg
    vt_internal_tui_theme.title_fg     = title_fg
    vt_internal_tui_theme.title_bg     = title_bg
    vt_internal_tui_theme.bar_fg       = bar_fg
    vt_internal_tui_theme.bar_bg       = bar_bg
    vt_internal_tui_theme.btn_fg       = btn_fg
    vt_internal_tui_theme.btn_bg       = btn_bg
    vt_internal_tui_theme.dlg_fg       = dlg_fg
    vt_internal_tui_theme.dlg_bg       = dlg_bg
    vt_internal_tui_theme.inp_fg       = inp_fg
    vt_internal_tui_theme.inp_bg       = inp_bg
    vt_internal_tui_theme.border_style = border_style
    vt_internal_tui_inited             = 1
End Sub

' -----------------------------------------------------------------------------
' Internal: auto-apply default theme on first draw if user never called either
' theme function. Avoids all-black-on-black surprise.
' No ready guard -- pure struct write, screen not required.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_autoinit()
    If vt_internal_tui_inited = 0 Then vt_tui_theme_default()
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_save_rect
' Saves a 1-based (ox, oy) rectangle of wid x hei cells into buf().
' ReDims buf to wid * hei - 1. No ready guard -- callers already checked.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_save_rect(ox As Long, oy As Long, wid As Long, hei As Long, _
                               buf() As vt_cell)
    Dim r   As Long
    Dim c   As Long
    Dim src As vt_cell Ptr
    ReDim buf(wid * hei - 1)
    For r = 0 To hei - 1
        src = vt_internal.cells + (oy - 1 + r) * vt_internal.scr_cols + (ox - 1)
        For c = 0 To wid - 1
            buf(r * wid + c) = src[c]
        Next c
    Next r
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_restore_rect
' Restores a previously saved 1-based (ox, oy) rectangle from buf().
' Sets dirty. No ready guard -- callers already checked.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_restore_rect(ox As Long, oy As Long, wid As Long, hei As Long, _
                                  buf() As vt_cell)
    Dim r   As Long
    Dim c   As Long
    Dim cel As vt_cell Ptr
    For r = 0 To hei - 1
        cel = vt_internal.cells + (oy - 1 + r) * vt_internal.scr_cols + (ox - 1)
        For c = 0 To wid - 1
            cel[c] = buf(r * wid + c)
        Next c
    Next r
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_draw_button
' Draws [lbl] at 1-based (x, y) in fg/bg. Width = Len(lbl) + 2.
' No ready guard, no dirty -- callers handle both.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_draw_button(x As Long, y As Long, lbl As String, _
                                 fg As UByte, bg As UByte)
    Dim cel  As vt_cell Ptr
    Dim c    As Long
    Dim llen As Long
    llen = Len(lbl)
    cel  = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)
    cel[0].ch = Asc("[") : cel[0].fg = fg : cel[0].bg = bg
    For c = 0 To llen - 1
        cel[c + 1].ch = lbl[c] : cel[c + 1].fg = fg : cel[c + 1].bg = bg
    Next c
    cel[llen + 1].ch = Asc("]") : cel[llen + 1].fg = fg : cel[llen + 1].bg = bg
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_draw_scrollbar
' Draws a vertical scrollbar at 1-based (x, y) of hei rows.
' thumb is the 0-based row index of the scroll thumb.
' Uses CP437 219 (solid) for thumb, 177 (stipple) for track.
' No ready guard, no dirty -- callers handle both.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_draw_scrollbar(x As Long, y As Long, hei As Long, _
                                    thumb As Long, fg As UByte, bg As UByte)
    Dim cel As vt_cell Ptr
    Dim r   As Long
    cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)
    For r = 0 To hei - 1
        cel->ch = IIf(r = thumb, 219, 177) : cel->fg = fg : cel->bg = bg
        cel    += vt_internal.scr_cols
    Next r
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_draw_bar
' Draws the menubar row. open_grp = -1 for passive (no highlight),
' 0..n-1 highlights that group with inverted colours.
' Sets dirty. No ready guard -- callers already checked.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_draw_bar(row As Long, groups() As String, open_grp As Long)
    Dim cel         As vt_cell Ptr
    Dim c           As Long
    Dim i           As Long
    Dim gx          As Long
    Dim glen        As Long
    Dim bfg         As UByte
    Dim bbg         As UByte
    Dim rfg         As UByte
    Dim rbg         As UByte
    Dim group_count As Long
    Dim grp_base    As Long

    bfg         = vt_internal_tui_theme.bar_fg
    bbg         = vt_internal_tui_theme.bar_bg
    group_count = UBound(groups) - LBound(groups) + 1
    grp_base    = LBound(groups)

    cel = vt_internal.cells + (row - 1) * vt_internal.scr_cols
    For c = 0 To vt_internal.scr_cols - 1
        cel[c].ch = 32 : cel[c].fg = bfg : cel[c].bg = bbg
    Next c

    gx = 0
    For i = 0 To group_count - 1
        glen = Len(groups(grp_base + i))
        If i = open_grp Then
            rfg = VT_TUI_INVERT_FG(bfg) : rbg = VT_TUI_INVERT_BG(bbg)
        Else
            rfg = bfg : rbg = bbg
        End If
        If gx < vt_internal.scr_cols Then
            cel[gx].ch = 32 : cel[gx].fg = rfg : cel[gx].bg = rbg : gx += 1
        End If
        For c = 0 To glen - 1
            If gx >= vt_internal.scr_cols Then Exit For
            cel[gx].ch = groups(grp_base + i)[c]
            cel[gx].fg = rfg : cel[gx].bg = rbg
            gx += 1
        Next c
        If gx < vt_internal.scr_cols Then
            cel[gx].ch = 32 : cel[gx].fg = rfg : cel[gx].bg = rbg : gx += 1
        End If
        If gx >= vt_internal.scr_cols Then Exit For
    Next i

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_rect_fill
' Fills a 1-based (x,y) rectangle of size wid x hei with ch, fg, bg.
' Base primitive -- all other widget drawing calls this internally.
' =============================================================================
Sub vt_tui_rect_fill(x As Long, y As Long, wid As Long, hei As Long, _
                     ch As UByte, fg As UByte, bg As UByte)
    Dim r   As Long
    Dim c   As Long
    Dim cel As vt_cell Ptr

    VT_TUI_GUARD_SUB

    For r = 0 To hei - 1
        cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
        For c = 0 To wid - 1
            cel[c].ch = ch
            cel[c].fg = fg
            cel[c].bg = bg
        Next c
    Next r
    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_hline
' Draws a horizontal separator line at (x, y) of length wid.
' Character chosen from theme border_style: single=196, double=205.
' =============================================================================
Sub vt_tui_hline(x As Long, y As Long, wid As Long, fg As UByte, bg As UByte)
    Dim c   As Long
    Dim cel As vt_cell Ptr
    Dim hch As UByte

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    hch = IIf(vt_internal_tui_theme.border_style = 0, 196, 205)

    cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)
    For c = 0 To wid - 1
        cel[c].ch = hch
        cel[c].fg = fg
        cel[c].bg = bg
    Next c
    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_vline
' Draws a vertical separator line at (x, y) of length hei.
' Character chosen from theme border_style: single=179, double=186.
' =============================================================================
Sub vt_tui_vline(x As Long, y As Long, hei As Long, fg As UByte, bg As UByte)
    Dim r   As Long
    Dim cel As vt_cell Ptr
    Dim vch As UByte

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    vch = IIf(vt_internal_tui_theme.border_style = 0, 179, 186)

    For r = 0 To hei - 1
        cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
        cel->ch = vch
        cel->fg = fg
        cel->bg = bg
    Next r
    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_window
' Draws window chrome: border + title bar + optional [x] and/or shadow.
' Does not save/restore background. Does not block.
' Flags: VT_TUI_WIN_CLOSEBTN -- renders [x] at right end of title bar.
'        VT_TUI_WIN_SHADOW   -- draws a one-cell drop shadow (right + bottom).
' Shadow uses CP437 177 in dark grey on black -- visible on any background.
' =============================================================================
Sub vt_tui_window(x As Long, y As Long, wid As Long, hei As Long, _
                  title As String, flags As Long = 0)
    Dim cel     As vt_cell Ptr
    Dim r       As Long
    Dim c       As Long
    Dim tfg     As UByte
    Dim tbg     As UByte
    Dim wfg     As UByte
    Dim wbg     As UByte
    Dim tl_ch   As UByte
    Dim tr_ch   As UByte
    Dim bl_ch   As UByte
    Dim br_ch   As UByte
    Dim h_ch    As UByte
    Dim v_ch    As UByte
    Dim inner_w As Long
    Dim avail   As Long
    Dim ttl     As String
    Dim tlen    As Long
    Dim tstart  As Long
    Dim shx     As Long
    Dim shy     As Long

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    tfg     = vt_internal_tui_theme.title_fg
    tbg     = vt_internal_tui_theme.title_bg
    wfg     = vt_internal_tui_theme.win_fg
    wbg     = vt_internal_tui_theme.win_bg
    inner_w = wid - 2

    If vt_internal_tui_theme.border_style = 0 Then
        tl_ch = 218 : tr_ch = 191 : bl_ch = 192 : br_ch = 217
        h_ch  = 196 : v_ch  = 179
    Else
        tl_ch = 201 : tr_ch = 187 : bl_ch = 200 : br_ch = 188
        h_ch  = 205 : v_ch  = 186
    End If

    ' --- shadow drawn first so window paints over the overlap corner ---
    If (flags And VT_TUI_WIN_SHADOW) Then
        ' right strip: col x+wid, rows y+1 .. y+hei-1
        shx = x + wid
        shy = y + 1
        If shx <= vt_internal.scr_cols Then
            For r = 0 To hei - 1
                If shy + r <= vt_internal.scr_rows Then
                    cel = vt_internal.cells + (shy - 1 + r) * vt_internal.scr_cols + (shx - 1)
                    cel->ch = 177 : cel->fg = VT_DARK_GREY : cel->bg = VT_BLACK
                End If
            Next r
        End If
        ' bottom strip: row y+hei, cols x+1 .. x+wid
        shx = x + 1
        shy = y + hei
        If shy <= vt_internal.scr_rows Then
            cel = vt_internal.cells + (shy - 1) * vt_internal.scr_cols + (shx - 1)
            For c = 0 To wid - 1
                If shx + c <= vt_internal.scr_cols Then
                    cel[c].ch = 177 : cel[c].fg = VT_DARK_GREY : cel[c].bg = VT_BLACK
                End If
            Next c
        End If
    End If

    ' --- body fill ---
    If hei > 2 Then
        vt_tui_rect_fill(x + 1, y + 1, inner_w, hei - 2, 32, wfg, wbg)
    End If

    ' --- top border row ---
    cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)
    cel[0].ch = tl_ch : cel[0].fg = wfg : cel[0].bg = wbg
    For c = 1 To inner_w
        cel[c].ch = 32 : cel[c].fg = tfg : cel[c].bg = tbg
    Next c
    cel[inner_w + 1].ch = tr_ch : cel[inner_w + 1].fg = wfg : cel[inner_w + 1].bg = wbg

    ' --- optional close button [x] right-aligned in title bar ---
    If (flags And VT_TUI_WIN_CLOSEBTN) AndAlso inner_w >= 5 Then
        cel[inner_w - 2].ch = Asc("[") : cel[inner_w - 2].fg = tfg : cel[inner_w - 2].bg = tbg
        cel[inner_w - 1].ch = Asc("x") : cel[inner_w - 1].fg = tfg : cel[inner_w - 1].bg = tbg
        cel[inner_w    ].ch = Asc("]") : cel[inner_w    ].fg = tfg : cel[inner_w    ].bg = tbg
        avail = inner_w - 4
    Else
        avail = inner_w
    End If

    ' --- title: centered within avail, truncated if needed ---
    ttl = title
    If Len(ttl) > avail Then ttl = Left(ttl, avail)
    tlen   = Len(ttl)
    tstart = (avail - tlen) \ 2 + 1
    For c = 0 To tlen - 1
        cel[tstart + c].ch = ttl[c]
    Next c

    ' --- left and right border columns ---
    For r = 1 To hei - 2
        cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
        cel[0          ].ch = v_ch : cel[0          ].fg = wfg : cel[0          ].bg = wbg
        cel[inner_w + 1].ch = v_ch : cel[inner_w + 1].fg = wfg : cel[inner_w + 1].bg = wbg
    Next r

    ' --- bottom border row ---
    cel = vt_internal.cells + (y - 2 + hei) * vt_internal.scr_cols + (x - 1)
    cel[0].ch = bl_ch : cel[0].fg = wfg : cel[0].bg = wbg
    For c = 1 To inner_w
        cel[c].ch = h_ch : cel[c].fg = wfg : cel[c].bg = wbg
    Next c
    cel[inner_w + 1].ch = br_ch : cel[inner_w + 1].fg = wfg : cel[inner_w + 1].bg = wbg

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_statusbar
' Fills the entire row with bar_bg and prints caption left-aligned in bar_fg.
' =============================================================================
Sub vt_tui_statusbar(row As Long, caption As String)
    Dim cel  As vt_cell Ptr
    Dim c    As Long
    Dim clen As Long
    Dim bfg  As UByte
    Dim bbg  As UByte

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    bfg  = vt_internal_tui_theme.bar_fg
    bbg  = vt_internal_tui_theme.bar_bg
    clen = Len(caption)
    If clen > vt_internal.scr_cols Then clen = vt_internal.scr_cols

    cel = vt_internal.cells + (row - 1) * vt_internal.scr_cols

    For c = 0 To vt_internal.scr_cols - 1
        cel[c].ch = 32 : cel[c].fg = bfg : cel[c].bg = bbg
    Next c
    For c = 0 To clen - 1
        cel[c].ch = caption[c]
    Next c

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_progress
' Horizontal progress bar at (x, y) of width wid.
' Filled block: solid title_bg colour.  Empty block: solid inp_bg colour.
' Flag VT_TUI_PROG_LABEL: prints " nn% " centred on the bar.
' Label uses inverted bg colour for contrast against both halves.
' =============================================================================
Sub vt_tui_progress(x As Long, y As Long, wid As Long, _
                    value As Long, max_val As Long, flags As Long = 0)
    Dim cel      As vt_cell Ptr
    Dim c        As Long
    Dim filled   As Long
    Dim full_bg  As UByte
    Dim empty_bg As UByte
    Dim lbl      As String
    Dim llen     As Long
    Dim lstart   As Long
    Dim cur_bg   As UByte

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    full_bg  = vt_internal_tui_theme.title_bg
    empty_bg = vt_internal_tui_theme.inp_bg

    If max_val <= 0 Then max_val = 1
    If value < 0 Then value = 0
    If value > max_val Then value = max_val

    filled = wid * value \ max_val

    cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)

    For c = 0 To wid - 1
        cel[c].ch = 32
        If c < filled Then
            cel[c].fg = full_bg : cel[c].bg = full_bg
        Else
            cel[c].fg = empty_bg : cel[c].bg = empty_bg
        End If
    Next c

    If (flags And VT_TUI_PROG_LABEL) Then
        lbl    = " " & (value * 100 \ max_val) & "% "
        llen   = Len(lbl)
        lstart = (wid - llen) \ 2
        If lstart < 0 Then lstart = 0
        For c = 0 To llen - 1
            If lstart + c < wid Then
                If lstart + c < filled Then
                    cur_bg = full_bg
                Else
                    cur_bg = empty_bg
                End If
                cel[lstart + c].ch = lbl[c]
                cel[lstart + c].bg = cur_bg
                cel[lstart + c].fg = VT_TUI_INVERT_FG(cur_bg)
            End If
        Next c
    End If

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_mouse_in_rect
' Hit-test helper. Returns 1 if the current mouse position is inside the
' 1-based rectangle (x, y, wid, hei), 0 otherwise.
' Returns 0 early if library is not ready or mouse is disabled.
' =============================================================================
Function vt_tui_mouse_in_rect(x As Long, y As Long, _
                               wid As Long, hei As Long) As Byte
    VT_TUI_GUARD_FN
    If vt_internal.mouse_on = 0 Then Return 0

    If vt_internal.mouse_col >= x AndAlso _
       vt_internal.mouse_col <= x + wid - 1 AndAlso _
       vt_internal.mouse_row >= y AndAlso _
       vt_internal.mouse_row <= y + hei - 1 Then
        Return 1
    End If
    Return 0
End Function

' =============================================================================
' vt_tui_input_field
' Single-line text input at an arbitrary screen position. Blocking.
' Enter confirms -- returns the edited string.
' Escape cancels  -- returns initial unchanged.
' Uses theme inp_fg / inp_bg for the field colours.
' Supports max_len > wid: buffer holds up to max_len chars with
' horizontal scrolling; only wid cells are drawn on screen.
' =============================================================================
Function vt_tui_input_field(x As Long, y As Long, wid As Long, _
                             initial As String, max_len As Long) As String
    Dim buf          As String
    Dim cpos         As Long
    Dim view_off     As Long
    Dim save_cur_vis As Byte
    Dim ifg          As UByte
    Dim ibg          As UByte
    Dim k            As ULong
    Dim sc           As Long
    Dim ch           As UByte
    Dim c            As Long
    Dim draw_len     As Long
    Dim vis_cpos     As Long
    Dim cel          As vt_cell Ptr

    VT_TUI_GUARD_FN_STR
    vt_internal_tui_autoinit()

    If max_len < 1 Then max_len = wid

    ifg = vt_internal_tui_theme.inp_fg
    ibg = vt_internal_tui_theme.inp_bg

    buf  = initial
    If Len(buf) > max_len Then buf = Left(buf, max_len)
    cpos     = Len(buf)   ' cursor starts at end of preloaded text
    view_off = 0

    save_cur_vis            = vt_internal.cur_visible
    vt_internal.cur_visible = 1

    Do
        ' keep cursor inside the visible window
        If cpos < view_off             Then view_off = cpos
        If cpos > view_off + wid - 1   Then view_off = cpos - wid + 1
        If view_off < 0                Then view_off = 0

        ' draw field: always wid cells wide, inp colour, then overlay text
        cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)
        For c = 0 To wid - 1
            cel[c].ch = 32 : cel[c].fg = ifg : cel[c].bg = ibg
        Next c
        draw_len = Len(buf) - view_off
        If draw_len > wid Then draw_len = wid
        If draw_len < 0   Then draw_len = 0
        For c = 0 To draw_len - 1
            cel[c].ch = buf[view_off + c]
        Next c

        ' position text cursor at the caret column
        vis_cpos = cpos - view_off
        vt_locate(y, x + vis_cpos)
        vt_internal.dirty = 1

        Do
            k = vt_inkey()
            If k <> 0 Then Exit Do
            vt_sleep 10
        Loop

        sc = VT_SCAN(k)
        ch = VT_CHAR(k)

        Select Case sc
            Case VT_KEY_ENTER
                vt_internal.cur_visible = save_cur_vis
                Return buf

            Case VT_KEY_ESC
                vt_internal.cur_visible = save_cur_vis
                Return initial

            Case VT_KEY_LEFT
                If cpos > 0 Then cpos -= 1

            Case VT_KEY_RIGHT
                If cpos < Len(buf) Then cpos += 1

            Case VT_KEY_HOME
                cpos = 0

            Case VT_KEY_END
                cpos = Len(buf)

            Case VT_KEY_BKSP
                If cpos > 0 Then
                    buf  = Left(buf, cpos - 1) & Mid(buf, cpos + 1)
                    cpos -= 1
                End If

            Case VT_KEY_DEL
                If cpos < Len(buf) Then
                    buf = Left(buf, cpos) & Mid(buf, cpos + 2)
                End If

            Case Else
                If ch >= 32 AndAlso Len(buf) < max_len Then
                    buf  = Left(buf, cpos) & Chr(ch) & Mid(buf, cpos + 1)
                    cpos += 1
                End If
        End Select
    Loop
End Function

' =============================================================================
' vt_tui_listbox
' Scrollable item list. Blocking.
' Returns 0-based index of the selected item, or -1 on cancel (Escape).
' Keyboard: Up/Down navigate, PgUp/PgDn/Home/End scroll, Enter confirms, Esc cancels.
' Mouse:    click to highlight, double-click to confirm.
'           wheel scrolls the view without moving selection.
' Scrollbar drawn on right edge when item count exceeds visible height.
' =============================================================================
Function vt_tui_listbox(x As Long, y As Long, wid As Long, hei As Long, _
                        items() As String, flags As Long = 0) As Long

    Dim item_count      As Long
    Dim item_base       As Long
    Dim sel             As Long
    Dim top_item        As Long
    Dim max_top         As Long
    Dim need_scroll     As Byte
    Dim item_wid        As Long
    Dim r               As Long
    Dim c               As Long
    Dim item_idx        As Long
    Dim cel             As vt_cell Ptr
    Dim wfg             As UByte
    Dim wbg             As UByte
    Dim rfg             As UByte
    Dim rbg             As UByte
    Dim k               As ULong
    Dim sc              As Long
    Dim txt             As String
    Dim tlen            As Long
    Dim thumb_row       As Long
    Dim prev_btns       As Long
    Dim cur_btns        As Long
    Dim lmb_down        As Byte
    Dim clicked_row     As Long
    Dim clicked_item    As Long
    Dim last_click_item As Long
    Dim last_click_time As Double
    Dim whl             As Long

    VT_TUI_GUARD_FN
    vt_internal_tui_autoinit()

    item_count = UBound(items) - LBound(items) + 1
    If item_count <= 0 Then Return -1

    item_base   = LBound(items)
    sel         = 0
    top_item    = 0
    max_top     = item_count - hei
    If max_top < 0 Then max_top = 0
    need_scroll = IIf(item_count > hei, 1, 0)
    item_wid    = IIf(need_scroll, wid - 1, wid)

    wfg = vt_internal_tui_theme.win_fg
    wbg = vt_internal_tui_theme.win_bg

    ' init from current state to avoid phantom click on entry
    prev_btns       = vt_internal.mouse_btns
    last_click_item = -1
    last_click_time = 0.0

    Do
        ' --- draw items ---
        For r = 0 To hei - 1
            item_idx = top_item + r
            cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)

            If item_idx = sel Then
                rfg = VT_TUI_INVERT_FG(wfg) : rbg = VT_TUI_INVERT_BG(wbg)
            Else
                rfg = wfg : rbg = wbg
            End If

            For c = 0 To item_wid - 1
                cel[c].ch = 32 : cel[c].fg = rfg : cel[c].bg = rbg
            Next c

            If item_idx >= 0 AndAlso item_idx < item_count Then
                txt  = items(item_base + item_idx)
                tlen = Len(txt)
                If tlen > item_wid Then tlen = item_wid
                For c = 0 To tlen - 1
                    cel[c].ch = txt[c]
                Next c
            End If
        Next r

        ' --- scrollbar ---
        If need_scroll Then
            thumb_row = top_item * (hei - 1) \ (item_count - hei)
            vt_internal_tui_draw_scrollbar(x + wid - 1, y, hei, thumb_row, wfg, wbg)
        End If

        vt_internal.dirty = 1

        ' --- wait ---
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

        ' --- mouse wheel ---
        whl = vt_internal.mouse_wheel
        If whl <> 0 Then
            vt_internal.mouse_wheel = 0
            top_item -= whl
            If top_item < 0       Then top_item = 0
            If top_item > max_top Then top_item = max_top
            If sel < top_item            Then sel = top_item
            If sel >= top_item + hei Then sel = top_item + hei - 1
        End If

        ' --- keyboard ---
        If k <> 0 Then
            sc = VT_SCAN(k)
            Select Case sc
                Case VT_KEY_UP
                    If sel > 0 Then
                        sel -= 1
                        If sel < top_item Then top_item = sel
                    End If

                Case VT_KEY_DOWN
                    If sel < item_count - 1 Then
                        sel += 1
                        If sel >= top_item + hei Then top_item = sel - hei + 1
                    End If

                Case VT_KEY_PGUP
                    sel -= hei
                    If sel < 0 Then sel = 0
                    If sel < top_item Then top_item = sel

                Case VT_KEY_PGDN
                    sel += hei
                    If sel >= item_count Then sel = item_count - 1
                    If sel >= top_item + hei Then top_item = sel - hei + 1
                    If top_item > max_top Then top_item = max_top

                Case VT_KEY_HOME
                    sel      = 0
                    top_item = 0

                Case VT_KEY_END
                    sel      = item_count - 1
                    top_item = max_top

                Case VT_KEY_ENTER
                    Return sel

                Case VT_KEY_ESC
                    Return -1
            End Select
        End If

        ' --- mouse click ---
        If lmb_down Then
            If vt_tui_mouse_in_rect(x, y, item_wid, hei) Then
                clicked_row  = vt_internal.mouse_row - y
                clicked_item = top_item + clicked_row
                If clicked_item >= 0 AndAlso clicked_item < item_count Then
                    If clicked_item = last_click_item AndAlso _
                       (Timer() - last_click_time) < 0.5 Then
                        Return clicked_item
                    End If
                    sel             = clicked_item
                    last_click_item = clicked_item
                    last_click_time = Timer()
                    If sel < top_item Then top_item = sel
                    If sel >= top_item + hei Then top_item = sel - hei + 1
                End If
            End If
        End If
    Loop
End Function

' =============================================================================
' vt_tui_dialog
' Self-contained blocking modal dialog. Saves and restores the background.
' Auto-sizes: word-wraps text, centers on screen, minimum size for buttons.
' Returns VT_RET_OK / VT_RET_CANCEL / VT_RET_YES / VT_RET_NO.
' Keyboard: Tab / Left / Right move between buttons, Enter confirms,
'           Escape = VT_RET_CANCEL unless VT_DLG_NO_ESC is set.
' Mouse: click a button to activate it.
' =============================================================================
Function vt_tui_dialog(caption As String, txt As String, _
                       flags As Long = VT_DLG_OK) As Long
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

    VT_TUI_GUARD_FN
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

    vt_internal_tui_save_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())

    dfg       = vt_internal_tui_theme.dlg_fg
    dbg       = vt_internal_tui_theme.dlg_bg
    focused   = 0
    ' init from current state to avoid phantom click on entry
    prev_btns = vt_internal.mouse_btns
    result    = VT_RET_CANCEL

    btn_row     = dlg_y + dlg_h - 2
    btn_start_x = dlg_x + 1 + (inner_w - btn_total_w) \ 2

    Do
        vt_tui_window(dlg_x, dlg_y, dlg_w, dlg_h, caption)
        vt_tui_rect_fill(dlg_x + 1, dlg_y + 1, inner_w, dlg_h - 2, 32, dfg, dbg)

        For r = 0 To line_count - 1
            cel  = vt_internal.cells + (dlg_y + 1 + r) * vt_internal.scr_cols + dlg_x
            tlen = Len(wlines(r))
            If tlen > text_w Then tlen = text_w
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
            sc = VT_SCAN(k)
            Select Case sc
                Case VT_KEY_TAB
                    focused += 1
                    If focused >= btn_count Then focused = 0

                Case VT_KEY_LEFT
                    If focused > 0 Then focused -= 1

                Case VT_KEY_RIGHT
                    If focused < btn_count - 1 Then focused += 1

                Case VT_KEY_ENTER
                    result = btn_rets(focused)
                    GoTo dlg_done

                Case VT_KEY_ESC
                    If no_esc = 0 Then
                        result = VT_RET_CANCEL
                        GoTo dlg_done
                    End If
            End Select
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

' =============================================================================
' vt_tui_file_dialog
' Self-contained blocking file picker. Saves and restores the background.
' Always shows ".." when a parent exists, directories with trailing "\" for nav.
' Flag VT_TUI_FD_DIRSONLY: no file entries shown; Enter/F2/OK confirms a dir.
' Double-click a directory to navigate into it (or confirm in DIRSONLY mode).
' Double-click a file or Enter on a file entry to confirm.
' F2 = keyboard confirm equivalent to the OK button.
' title parameter sets the confirm button label ("Open", "Save", etc.)
' Returns the full selected path, or "" on cancel.
' Navigation keys (Up/Down/PgUp/PgDn/Home/End) update the name field with
' the selected entry whenever applicable.
' =============================================================================
Function vt_tui_file_dialog(title As String, start_path As String, _
                             pattern As String, flags As Long = 0) As String

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
    Dim result          As String

    VT_TUI_GUARD_FN_STR
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

    fname           = ""
    sel             = 0
    top_item        = 0
    last_click_idx  = -1
    last_click_time = 0.0
    ' init from current state to avoid phantom click on entry
    prev_btns       = vt_internal.mouse_btns
    result          = ""
    need_reload     = 1
    disp_count      = 0

    Do
        ' =====================================================================
        ' reload file list on directory change
        ' =====================================================================
        If need_reload Then
            need_reload = 0
            sel         = 0
            top_item    = 0
            fname       = ""

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

            If item_idx = sel Then
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

        ' name row
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
        Next c
        txt = fname
        If Len(txt) > name_w Then txt = Right(txt, name_w)
        For c = 0 To Len(txt) - 1
            cel[6 + c].ch = txt[c]
        Next c

        ' OK and Cancel buttons
        vt_internal_tui_draw_button(ok_x,     btn_row, " " & title & " ", bfg, bbg)
        vt_internal_tui_draw_button(cancel_x, btn_row, " Cancel ",         bfg, bbg)

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
        ' mouse wheel
        ' =====================================================================
        whl = vt_internal.mouse_wheel
        If whl <> 0 Then
            vt_internal.mouse_wheel = 0
            If vt_tui_mouse_in_rect(list_x, list_y, inner_w, list_hei) Then
                top_item -= whl
                If top_item < 0       Then top_item = 0
                If top_item > max_top Then top_item = max_top
                If sel < top_item             Then sel = top_item
                If sel >= top_item + list_hei Then sel = top_item + list_hei - 1
            End If
        End If

        ' =====================================================================
        ' keyboard
        ' =====================================================================
        If k <> 0 Then
            sc        = VT_SCAN(k)
            ch        = VT_CHAR(k)
            nav_moved = 0

            Select Case sc
                Case VT_KEY_UP
                    If sel > 0 Then
                        sel -= 1
                        If sel < top_item Then top_item = sel
                    End If
                    nav_moved = 1

                Case VT_KEY_DOWN
                    If sel < disp_count - 1 Then
                        sel += 1
                        If sel >= top_item + list_hei Then top_item = sel - list_hei + 1
                    End If
                    nav_moved = 1

                Case VT_KEY_PGUP
                    sel -= list_hei
                    If sel < 0 Then sel = 0
                    If sel < top_item Then top_item = sel
                    nav_moved = 1

                Case VT_KEY_PGDN
                    sel += list_hei
                    If sel >= disp_count Then sel = disp_count - 1
                    If sel >= top_item + list_hei Then
                        top_item = sel - list_hei + 1
                        If top_item > max_top Then top_item = max_top
                    End If
                    nav_moved = 1

                Case VT_KEY_HOME
                    sel      = 0
                    top_item = 0
                    nav_moved = 1

                Case VT_KEY_END
                    If disp_count > 0 Then sel = disp_count - 1
                    top_item  = max_top
                    nav_moved = 1

                Case VT_KEY_ENTER
                    If disp_count > 0 AndAlso sel >= 0 AndAlso sel < disp_count Then
                        If is_dir_arr(sel) Then
                            If disp_arr(sel) = ".." Then
                                sep_pos = InStrRev(tmp_path, "/")
                                If sep_pos > 0 Then cur_path = Left(tmp_path, sep_pos)
                                need_reload = 1
                            ElseIf (flags And VT_TUI_FD_DIRSONLY) Then
                                ' in dir-pick mode, Enter on a dir confirms it
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

                Case VT_KEY_F2
                    ' keyboard confirm equivalent to OK button
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

                Case VT_KEY_BKSP
                    If Len(fname) > 0 Then
                        fname = Left(fname, Len(fname) - 1)
                    ElseIf has_parent Then
                        sep_pos = InStrRev(tmp_path, "/")
                        If sep_pos > 0 Then cur_path = Left(tmp_path, sep_pos)
                        need_reload = 1
                    End If

                Case VT_KEY_TAB
                    fname = vt_tui_input_field(name_x, name_row, name_w, fname, name_w)

                Case VT_KEY_ESC
                    GoTo fd_done

                Case Else
                    If ch >= 32 AndAlso Len(fname) < name_w Then
                        fname &= Chr(ch)
                    End If

            End Select

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
            End If
        End If

        ' =====================================================================
        ' mouse clicks
        ' =====================================================================
        If lmb_down Then

            ' list area
            If vt_tui_mouse_in_rect(list_x, list_y, item_w, list_hei) Then
                clicked_row = vt_internal.mouse_row - list_y
                clicked_idx = top_item + clicked_row
                If clicked_idx >= 0 AndAlso clicked_idx < disp_count Then
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

            ' name field
            If vt_tui_mouse_in_rect(name_x, name_row, name_w, 1) Then
                fname = vt_tui_input_field(name_x, name_row, name_w, fname, name_w)
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
        End If
    Loop

fd_done:
    vt_internal_tui_restore_rect(dlg_x, dlg_y, dlg_w, dlg_h, saved())
    Return result
End Function

' =============================================================================
' vt_tui_editor
' Multi-line text editor / viewer widget. Blocking.
' Text stored as one String, newlines as Chr(10).
' F10 or Ctrl+Enter confirms -- returns edited text.
' Escape cancels          -- returns original txt unchanged.
' Flag VT_TUI_ED_READONLY: view and scroll only, no editing.
' No horizontal scrolling -- lines exceeding wid are truncated in display.
' No undo in v1.
' Uses inp_fg/inp_bg for cell colours to ensure cursor contrast.
' =============================================================================
Function vt_tui_editor(x As Long, y As Long, wid As Long, hei As Long, _
                       txt As String, flags As Long = 0) As String

    Dim work          As String
    Dim cpos          As Long
    Dim top_ln        As Long
    Dim readonly_f    As Byte
    Dim cur_line      As Long
    Dim cur_col       As Long
    Dim ln_start      As Long
    Dim i             As Long
    Dim r             As Long
    Dim c             As Long
    Dim p             As Long
    Dim q             As Long
    Dim vis_start     As Long
    Dim scan_pos      As Long
    Dim prev_nl       As Long
    Dim prev_ln_start As Long
    Dim prev_ln_len   As Long
    Dim next_ln_start As Long
    Dim next_ln_len   As Long
    Dim tgt_line      As Long
    Dim new_col       As Long
    Dim vis_cur_col   As Long
    Dim ln_ctr        As Long
    Dim k             As ULong
    Dim sc            As Long
    Dim ch            As UByte
    Dim cel           As vt_cell Ptr
    Dim ifg           As UByte
    Dim ibg           As UByte
    Dim save_cur_vis  As Byte

    VT_TUI_GUARD_FN_STR
    vt_internal_tui_autoinit()

    work         = txt
    cpos         = 0
    top_ln       = 0
    readonly_f   = IIf((flags And VT_TUI_ED_READONLY) <> 0, 1, 0)
    ifg          = vt_internal_tui_theme.inp_fg
    ibg          = vt_internal_tui_theme.inp_bg
    save_cur_vis = vt_internal.cur_visible
    vt_internal.cur_visible = IIf(readonly_f, 0, 1)

    Do
        ' =====================================================================
        ' derive cur_line, cur_col, ln_start from cpos
        ' =====================================================================
        cur_line = 0
        ln_start = 0
        For i = 0 To cpos - 1
            If work[i] = 10 Then
                cur_line += 1
                ln_start  = i + 1
            End If
        Next i
        cur_col = cpos - ln_start

        If cur_line < top_ln Then top_ln = cur_line
        If cur_line >= top_ln + hei Then top_ln = cur_line - hei + 1
        If top_ln < 0 Then top_ln = 0

        ' =====================================================================
        ' find byte offset of top_ln (vis_start)
        ' =====================================================================
        vis_start = 0
        If top_ln > 0 Then
            ln_ctr = 0
            For i = 0 To Len(work) - 1
                If work[i] = 10 Then
                    ln_ctr += 1
                    If ln_ctr = top_ln Then
                        vis_start = i + 1
                        Exit For
                    End If
                End If
            Next i
        End If

        ' =====================================================================
        ' draw visible lines using inp colours for cursor contrast
        ' =====================================================================
        scan_pos = vis_start
        For r = 0 To hei - 1
            cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
            For c = 0 To wid - 1
                cel[c].ch = 32 : cel[c].fg = ifg : cel[c].bg = ibg
            Next c
            c = 0
            Do While scan_pos < Len(work) AndAlso work[scan_pos] <> 10 AndAlso c < wid
                cel[c].ch = work[scan_pos]
                cel[c].fg = ifg : cel[c].bg = ibg
                c        += 1
                scan_pos += 1
            Loop
            Do While scan_pos < Len(work) AndAlso work[scan_pos] <> 10
                scan_pos += 1
            Loop
            If scan_pos < Len(work) Then scan_pos += 1
        Next r

        If readonly_f = 0 Then
            If cur_line >= top_ln AndAlso cur_line < top_ln + hei Then
                vis_cur_col = cur_col
                If vis_cur_col >= wid Then vis_cur_col = wid - 1
                vt_locate(y + cur_line - top_ln, x + vis_cur_col)
            End If
        End If

        vt_internal.dirty = 1

        ' =====================================================================
        ' wait for key
        ' =====================================================================
        Do
            k = vt_inkey()
            If k <> 0 Then Exit Do
            vt_sleep(10)
        Loop

        sc = VT_SCAN(k)
        ch = VT_CHAR(k)

        ' =====================================================================
        ' key dispatch
        ' =====================================================================
        Select Case sc

            Case VT_KEY_ESC
                vt_internal.cur_visible = save_cur_vis
                Return txt

            Case VT_KEY_F10
                vt_internal.cur_visible = save_cur_vis
                Return work

            Case VT_KEY_ENTER
                If VT_CTRL(k) <> 0 Then
                    vt_internal.cur_visible = save_cur_vis
                    Return work
                End If
                If readonly_f = 0 Then
                    work = Left(work, cpos) & Chr(10) & Mid(work, cpos + 1)
                    cpos += 1
                End If

            Case VT_KEY_LEFT
                If cpos > 0 Then cpos -= 1

            Case VT_KEY_RIGHT
                If cpos < Len(work) Then cpos += 1

            Case VT_KEY_HOME
                cpos = ln_start

            Case VT_KEY_END
                p = ln_start
                Do While p < Len(work) AndAlso work[p] <> 10
                    p += 1
                Loop
                cpos = p

            Case VT_KEY_UP
                If cur_line > 0 Then
                    prev_nl = -1
                    p = ln_start - 2
                    Do While p > 0
                        If work[p - 1] = 10 Then
                            prev_nl = p - 1
                            Exit Do
                        End If
                        p -= 1
                    Loop
                    prev_ln_start = IIf(prev_nl >= 0, prev_nl + 1, 0)
                    prev_ln_len   = (ln_start - 1) - prev_ln_start
                    new_col = cur_col
                    If new_col > prev_ln_len Then new_col = prev_ln_len
                    cpos = prev_ln_start + new_col
                End If

            Case VT_KEY_DOWN
                p = ln_start
                Do While p < Len(work) AndAlso work[p] <> 10
                    p += 1
                Loop
                If p < Len(work) Then
                    next_ln_start = p + 1
                    q = next_ln_start
                    Do While q < Len(work) AndAlso work[q] <> 10
                        q += 1
                    Loop
                    next_ln_len = q - next_ln_start
                    new_col = cur_col
                    If new_col > next_ln_len Then new_col = next_ln_len
                    cpos = next_ln_start + new_col
                End If

            Case VT_KEY_PGUP
                tgt_line = cur_line - hei
                If tgt_line < 0 Then tgt_line = 0
                p      = 0
                ln_ctr = 0
                Do While p < Len(work) AndAlso ln_ctr < tgt_line
                    If work[p] = 10 Then ln_ctr += 1
                    p += 1
                Loop
                q = p
                Do While q < Len(work) AndAlso work[q] <> 10
                    q += 1
                Loop
                new_col = cur_col
                If new_col > q - p Then new_col = q - p
                cpos = p + new_col

            Case VT_KEY_PGDN
                tgt_line = cur_line + hei
                p      = 0
                ln_ctr = 0
                Do While p < Len(work) AndAlso ln_ctr < tgt_line
                    If work[p] = 10 Then ln_ctr += 1
                    p += 1
                Loop
                If p > Len(work) Then p = Len(work)
                q = p
                Do While q < Len(work) AndAlso work[q] <> 10
                    q += 1
                Loop
                new_col = cur_col
                If new_col > q - p Then new_col = q - p
                cpos = p + new_col

            Case VT_KEY_BKSP
                If readonly_f = 0 AndAlso cpos > 0 Then
                    work = Left(work, cpos - 1) & Mid(work, cpos + 1)
                    cpos -= 1
                End If

            Case VT_KEY_DEL
                If readonly_f = 0 AndAlso cpos < Len(work) Then
                    work = Left(work, cpos) & Mid(work, cpos + 2)
                End If

            Case Else
                If readonly_f = 0 AndAlso ch >= 32 Then
                    work = Left(work, cpos) & Chr(ch) & Mid(work, cpos + 1)
                    cpos += 1
                End If

        End Select
    Loop
End Function

' =============================================================================
' vt_tui_menubar_draw
' Renders the menu bar row passively. Call once per frame in your main loop.
' Does not block. Does not save/restore background.
' =============================================================================
Sub vt_tui_menubar_draw(row As Long, groups() As String)
    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()
    vt_internal_tui_draw_bar(row, groups(), -1)
End Sub

' =============================================================================
' vt_tui_menubar_handle
' Call with vt_inkey() result on every frame of your main loop.
' Non-blocking while no menu is open.
' Blocks with its own event loop while a dropdown is open.
' Returns 0 while nothing selected.
' Returns group * 1000 + item when an item is activated (both 1-based).
' Use VT_TUI_MENU_GROUP() / VT_TUI_MENU_ITEM() macros to extract.
' groups()  -- group header labels
' items()   -- flat array of all items, in group order
' counts()  -- item count per group, parallel to groups()
' Alt+first-letter opens a group. The letter is read from VT_CHAR(k) --
' vt_core (SDL2) and vt_tty (Linux/Windows) both set it in the keyrec.
' =============================================================================
Function vt_tui_menubar_handle(row As Long, groups() As String, _
                               items() As String, counts() As Long, _
                               k As ULong) As Long

    Dim group_count     As Long
    Dim grp_base        As Long
    Dim items_base      As Long
    Dim counts_base     As Long
    Dim open_grp        As Long
    Dim sel             As Long
    Dim grp_x           As Long
    Dim item_off        As Long
    Dim item_cnt        As Long
    Dim drop_x          As Long
    Dim drop_y          As Long
    Dim drop_w          As Long
    Dim drop_h          As Long
    Dim change_grp      As Long
    Dim menu_result     As Long
    Dim saved()         As vt_cell
    Dim cel             As vt_cell Ptr
    Dim r               As Long
    Dim c               As Long
    Dim i               As Long
    Dim dfg             As UByte
    Dim dbg             As UByte
    Dim rfg             As UByte
    Dim rbg             As UByte
    Dim glen            As Long
    Dim txt             As String
    Dim tlen            As Long
    Dim sc              As Long
    Dim gl              As UByte
    Dim triggered       As Byte
    Dim new_grp         As Long
    Dim cur_btns        As Long
    Dim lmb_down        As Byte
    Dim gx_scan         As Long
    Dim gx_end          As Long
    Dim prev_inner_btns As Long
    Dim alt_ch          As UByte            ' letter from Alt+key combo (outer trigger)
    Dim alt_ch2         As UByte            ' letter from Alt+key combo (inner dropdown)

    VT_TUI_GUARD_FN
    vt_internal_tui_autoinit()

    group_count = UBound(groups) - LBound(groups) + 1
    grp_base    = LBound(groups)
    items_base  = LBound(items)
    counts_base = LBound(counts)

    dfg = vt_internal_tui_theme.dlg_fg
    dbg = vt_internal_tui_theme.dlg_bg

    ' =========================================================================
    ' non-blocking trigger detection
    ' =========================================================================
    cur_btns = vt_internal.mouse_btns
    lmb_down = VT_TUI_LMB_DOWN(cur_btns, vt_internal_tui_menu_prev_btns)
    vt_internal_tui_menu_prev_btns = cur_btns

    triggered = 0
    open_grp  = 0

    ' Alt + first letter: VT_CHAR(k) holds the letter because vt_core (SDL2)
    ' and vt_tty (Linux/Windows) both encode it in the keyrec before delivery.
    If VT_ALT(k) <> 0 Then
        alt_ch = VT_CHAR(k)
        If alt_ch >= 65 AndAlso alt_ch <= 90 Then alt_ch += 32  ' normalize to lowercase
        For i = 0 To group_count - 1
            If Len(groups(grp_base + i)) > 0 Then
                gl = groups(grp_base + i)[0]
                If gl >= 65 AndAlso gl <= 90 Then gl += 32
                If gl >= 97 AndAlso gl <= 122 AndAlso alt_ch = gl Then
                    triggered = 1
                    open_grp  = i
                    Exit For
                End If
            End If
        Next i
    End If

    ' left mouse click on bar row
    If triggered = 0 AndAlso lmb_down AndAlso vt_internal.mouse_on <> 0 Then
        If vt_internal.mouse_row = row Then
            gx_scan = 1
            For i = 0 To group_count - 1
                glen    = Len(groups(grp_base + i))
                gx_end  = gx_scan + glen + 1
                If vt_internal.mouse_col >= gx_scan AndAlso _
                   vt_internal.mouse_col <= gx_end Then
                    triggered = 1
                    open_grp  = i
                    Exit For
                End If
                gx_scan = gx_end + 1
            Next i
        End If
    End If

    If triggered = 0 Then Return 0

    ' =========================================================================
    ' blocking dropdown loop
    ' =========================================================================
    sel         = 0
    menu_result = 0

    Do  ' outer: per-group setup

        grp_x = 1
        For i = 0 To open_grp - 1
            grp_x += Len(groups(grp_base + i)) + 2
        Next i

        item_off = items_base
        For i = 0 To open_grp - 1
            item_off += counts(counts_base + i)
        Next i
        item_cnt = counts(counts_base + open_grp)

        drop_w = 0
        For i = 0 To item_cnt - 1
            If Len(items(item_off + i)) > drop_w Then drop_w = Len(items(item_off + i))
        Next i
        drop_w += 2
        If drop_w < 10 Then drop_w = 10

        drop_x = grp_x
        drop_y = row + 1
        drop_h = item_cnt

        If drop_x + drop_w - 1 > vt_internal.scr_cols Then
            drop_x = vt_internal.scr_cols - drop_w + 1
        End If
        If drop_x < 1 Then drop_x = 1

        If drop_h > 0 Then
            vt_internal_tui_save_rect(drop_x, drop_y, drop_w, drop_h, saved())
        End If

        If item_cnt > 0 Then
            If sel >= item_cnt Then sel = item_cnt - 1
            If sel < 0 Then sel = 0
        End If

        change_grp      = -1
        prev_inner_btns = vt_internal.mouse_btns

        Do  ' inner: item navigation

            vt_internal_tui_draw_bar(row, groups(), open_grp)

            ' draw dropdown items
            For r = 0 To drop_h - 1
                cel = vt_internal.cells + (drop_y - 1 + r) * vt_internal.scr_cols + (drop_x - 1)
                If r = sel Then
                    rfg = VT_TUI_INVERT_FG(dfg) : rbg = VT_TUI_INVERT_BG(dbg)
                Else
                    rfg = dfg : rbg = dbg
                End If
                For c = 0 To drop_w - 1
                    cel[c].ch = 32 : cel[c].fg = rfg : cel[c].bg = rbg
                Next c
                txt  = items(item_off + r)
                tlen = Len(txt)
                If tlen > drop_w - 2 Then tlen = drop_w - 2
                For c = 0 To tlen - 1
                    cel[c + 1].ch = txt[c]
                Next c
            Next r

            vt_internal.dirty = 1

            ' wait for key or mouse button change
            Do
                k        = vt_inkey()
                cur_btns = vt_internal.mouse_btns
                If k <> 0 Then Exit Do
                If (cur_btns And 1) <> (prev_inner_btns And 1) Then Exit Do
                vt_sleep(10)
            Loop

            lmb_down        = VT_TUI_LMB_DOWN(cur_btns, prev_inner_btns)
            prev_inner_btns = cur_btns

            ' mouse: click on a dropdown item
            If lmb_down AndAlso vt_tui_mouse_in_rect(drop_x, drop_y, drop_w, drop_h) Then
                sel         = vt_internal.mouse_row - drop_y
                menu_result = (open_grp + 1) * 1000 + (sel + 1)
                GoTo menu_confirm
            End If

            ' mouse: click on bar row
            If lmb_down AndAlso vt_internal.mouse_row = row Then
                new_grp = -1
                gx_scan = 1
                For i = 0 To group_count - 1
                    glen    = Len(groups(grp_base + i))
                    gx_end  = gx_scan + glen + 1
                    If vt_internal.mouse_col >= gx_scan AndAlso _
                       vt_internal.mouse_col <= gx_end Then
                        new_grp = i
                        Exit For
                    End If
                    gx_scan = gx_end + 1
                Next i
                If new_grp >= 0 AndAlso new_grp <> open_grp Then
                    change_grp = new_grp
                    Exit Do
                End If
                GoTo menu_done
            End If

            ' mouse: click anywhere else
            If lmb_down Then GoTo menu_done

            ' keyboard
            If k <> 0 Then
                sc = VT_SCAN(k)

                Select Case sc
                    Case VT_KEY_ESC
                        GoTo menu_done

                    Case VT_KEY_ENTER
                        If item_cnt > 0 Then
                            menu_result = (open_grp + 1) * 1000 + (sel + 1)
                            GoTo menu_confirm
                        End If

                    Case VT_KEY_UP
                        If item_cnt > 0 Then
                            sel -= 1
                            If sel < 0 Then sel = item_cnt - 1
                        End If

                    Case VT_KEY_DOWN
                        If item_cnt > 0 Then
                            sel += 1
                            If sel >= item_cnt Then sel = 0
                        End If

                    Case VT_KEY_LEFT
                        change_grp = (open_grp + group_count - 1) Mod group_count
                        Exit Do

                    Case VT_KEY_RIGHT
                        change_grp = (open_grp + 1) Mod group_count
                        Exit Do

                    Case Else
                        ' Alt+letter while a dropdown is open: switch to the
                        ' matching group. VT_CHAR(k) holds the letter.
                        If VT_ALT(k) <> 0 Then
                            alt_ch2 = VT_CHAR(k)
                            If alt_ch2 >= 65 AndAlso alt_ch2 <= 90 Then alt_ch2 += 32
                            For i = 0 To group_count - 1
                                If Len(groups(grp_base + i)) > 0 Then
                                    gl = groups(grp_base + i)[0]
                                    If gl >= 65 AndAlso gl <= 90 Then gl += 32
                                    If gl >= 97 AndAlso gl <= 122 _
                                       AndAlso alt_ch2 = gl AndAlso i <> open_grp Then
                                        change_grp = i
                                        Exit For
                                    End If
                                End If
                            Next i
                            If change_grp >= 0 Then Exit Do
                        End If

                End Select
            End If
        Loop  ' inner

        ' restore background before switching group
        If drop_h > 0 Then
            vt_internal_tui_restore_rect(drop_x, drop_y, drop_w, drop_h, saved())
        End If

        If change_grp < 0 Then Return 0
        open_grp = change_grp
        sel      = 0
    Loop While 1

menu_confirm:
    If drop_h > 0 Then
        vt_internal_tui_restore_rect(drop_x, drop_y, drop_w, drop_h, saved())
    End If
    Return menu_result

menu_done:
    If drop_h > 0 Then
        vt_internal_tui_restore_rect(drop_x, drop_y, drop_w, drop_h, saved())
    End If
    Return 0
End Function

' =============================================================================
' FORMS 
' =============================================================================

' -----------------------------------------------------------------------------
' vt_internal_tui_form_radio_select
' Sets checked=1 on cur_item and clears all other RADIO items sharing the same
' group_id. group_id=0 is treated as "no group" -- only the item itself is set.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_form_radio_select(items() As vt_tui_form_item, _
                                       item_base As Long, item_count As Long, _
                                       cur_item As Long)
    Dim i   As Long
    Dim gid As Long
    gid = items(cur_item).group_id
    If gid = 0 Then
        items(cur_item).checked = 1
        Exit Sub
    End If
    For i = 0 To item_count - 1
        If items(item_base + i).kind = VT_FORM_RADIO AndAlso _
           items(item_base + i).group_id = gid Then
            items(item_base + i).checked = 0
        End If
    Next i
    items(cur_item).checked = 1
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_form_scroll
' Recalculates view_off after cpos changes in an input item so the cursor
' always stays inside the visible window. Call after every cpos mutation.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_form_scroll(ByRef itm As vt_tui_form_item)
    If itm.cpos < itm.view_off Then
        itm.view_off = itm.cpos
    End If
    If itm.cpos > itm.view_off + itm.wid - 1 Then
        itm.view_off = itm.cpos - itm.wid + 1
    End If
    If itm.view_off < 0 Then itm.view_off = 0
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_form_enter_input
' Called whenever focus lands on an input item. Places cursor at end of text
' and scrolls the view so the cursor is visible.
' -----------------------------------------------------------------------------
Sub vt_internal_tui_form_enter_input(ByRef itm As vt_tui_form_item)
    itm.cpos     = Len(itm.val)
    itm.view_off = itm.cpos - itm.wid + 1
    If itm.view_off < 0 Then itm.view_off = 0
End Sub

' =============================================================================
' vt_tui_form_draw
' Passive, non-blocking. Draw all form items and position the text cursor.
' Call once per frame after drawing your window chrome and static labels.
' focused is the 0-based index of the currently active item.
' Cursor visibility is set automatically: visible for inputs, hidden for buttons.
' =============================================================================
Sub vt_tui_form_draw(items() As vt_tui_form_item, ByRef focused As Long)
    Dim item_count As Long
    Dim item_base  As Long
    Dim i          As Long
    Dim c          As Long
    Dim cel        As vt_cell Ptr
    Dim ifg        As UByte
    Dim ibg        As UByte
    Dim bfg        As UByte
    Dim bbg        As UByte
    Dim dfg        As UByte
    Dim dbg        As UByte
    Dim draw_len   As Long
    Dim vis_cpos   As Long
    Dim glyph_fg   As UByte
    Dim glyph_bg   As UByte
    Dim lbl_len    As Long
    Dim lbl_c      As Long

    VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    ifg = vt_internal_tui_theme.inp_fg
    ibg = vt_internal_tui_theme.inp_bg
    bfg = vt_internal_tui_theme.btn_fg
    bbg = vt_internal_tui_theme.btn_bg
    dfg = vt_internal_tui_theme.dlg_fg
    dbg = vt_internal_tui_theme.dlg_bg

    item_count = UBound(items) - LBound(items) + 1
    item_base  = LBound(items)

    For i = 0 To item_count - 1
        Select Case items(item_base + i).kind

            Case VT_FORM_INPUT
                cel = vt_internal.cells + (items(item_base + i).y - 1) * vt_internal.scr_cols _
                                        + (items(item_base + i).x - 1)
                For c = 0 To items(item_base + i).wid - 1
                    cel[c].ch = 32 : cel[c].fg = ifg : cel[c].bg = ibg
                Next c
                draw_len = Len(items(item_base + i).val) - items(item_base + i).view_off
                If draw_len > items(item_base + i).wid Then draw_len = items(item_base + i).wid
                If draw_len < 0 Then draw_len = 0
                For c = 0 To draw_len - 1
                    cel[c].ch = items(item_base + i).val[items(item_base + i).view_off + c]
                Next c

            Case VT_FORM_BUTTON
                ' focused button uses inverted dialogue colours for clear highlight
                If i = focused Then
                    vt_internal_tui_draw_button(items(item_base + i).x, items(item_base + i).y, _
                                                items(item_base + i).val, _
                                                VT_TUI_INVERT_FG(dfg), VT_TUI_INVERT_BG(dbg))
                Else
                    vt_internal_tui_draw_button(items(item_base + i).x, items(item_base + i).y, _
                                                items(item_base + i).val, bfg, bbg)
                End If
            
            Case VT_FORM_CHECKBOX
                cel = vt_internal.cells + (items(item_base + i).y - 1) * vt_internal.scr_cols _
                                        + (items(item_base + i).x - 1)
                If i = focused Then
                    glyph_fg = VT_TUI_INVERT_FG(dfg) : glyph_bg = VT_TUI_INVERT_BG(dbg)
                Else
                    glyph_fg = dfg : glyph_bg = dbg
                End If
                cel[0].ch = Asc("[")  : cel[0].fg = glyph_fg : cel[0].bg = glyph_bg
                cel[1].ch = IIf(items(item_base + i).checked, Asc("x"), 32)
                cel[1].fg = glyph_fg : cel[1].bg = glyph_bg
                cel[2].ch = Asc("]")  : cel[2].fg = glyph_fg : cel[2].bg = glyph_bg
                cel[3].ch = 32        : cel[3].fg = glyph_fg : cel[3].bg = glyph_bg
                lbl_len = Len(items(item_base + i).val)
                For lbl_c = 0 To lbl_len - 1
                    cel[4 + lbl_c].ch = items(item_base + i).val[lbl_c]
                    cel[4 + lbl_c].fg = glyph_fg : cel[4 + lbl_c].bg = glyph_bg
                Next lbl_c

            Case VT_FORM_RADIO
                cel = vt_internal.cells + (items(item_base + i).y - 1) * vt_internal.scr_cols _
                                        + (items(item_base + i).x - 1)
                If i = focused Then
                    glyph_fg = VT_TUI_INVERT_FG(dfg) : glyph_bg = VT_TUI_INVERT_BG(dbg)
                Else
                    glyph_fg = dfg : glyph_bg = dbg
                End If
                cel[0].ch = Asc("(")  : cel[0].fg = glyph_fg : cel[0].bg = glyph_bg
                cel[1].ch = IIf(items(item_base + i).checked, Asc("*"), 32)
                cel[1].fg = glyph_fg : cel[1].bg = glyph_bg
                cel[2].ch = Asc(")")  : cel[2].fg = glyph_fg : cel[2].bg = glyph_bg
                cel[3].ch = 32        : cel[3].fg = glyph_fg : cel[3].bg = glyph_bg
                lbl_len = Len(items(item_base + i).val)
                For lbl_c = 0 To lbl_len - 1
                    cel[4 + lbl_c].ch = items(item_base + i).val[lbl_c]
                    cel[4 + lbl_c].fg = glyph_fg : cel[4 + lbl_c].bg = glyph_bg
                Next lbl_c
                
        End Select
    Next i

    ' cursor visibility and position for the focused item
    If focused >= 0 AndAlso focused < item_count Then
        If items(item_base + focused).kind = VT_FORM_INPUT Then
            vt_internal.cur_visible = 1
            vis_cpos = items(item_base + focused).cpos - items(item_base + focused).view_off
            vt_locate(items(item_base + focused).y, items(item_base + focused).x + vis_cpos)
        Else
            vt_internal.cur_visible = 0
        End If
    End If

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_form_handle
' Non-blocking event handler. Call with vt_inkey() result each frame.
' Modifies items().val/.cpos/.view_off and focused in place.
' focused is passed by reference -- the caller's variable is updated on focus
' changes so the next vt_tui_form_draw call reflects the new active item.
'
' Returns VT_FORM_PENDING (-2) while the form is still active.
' Returns VT_FORM_CANCEL (-1) when Escape is pressed.
' Returns the .ret value of a button when it is activated (Enter or click).
'
' Tab / Shift+Tab     -- advance / retreat focus through all items (wraps)
' Enter on input      -- advance focus (same as Tab)
' Enter on button     -- activate that button, return its .ret
' Left / Right        -- cursor movement within focused input
'                        or adjacent-item focus when on a button
' Home / End          -- cursor to start / end of focused input
' Backspace / Del     -- edit focused input
' Printable char      -- insert into focused input (respects max_len)
' Mouse click input   -- focus it, cursor snaps to click column
' Mouse click button  -- activate immediately, return its .ret
' Escape              -- return VT_FORM_CANCEL from any item
' =============================================================================
Function vt_tui_form_handle(items() As vt_tui_form_item, ByRef focused As Long, _
                             k As ULong) As Long
    Dim item_count  As Long
    Dim item_base   As Long
    Dim i           As Long
    Dim sc          As Long
    Dim ch          As UByte
    Dim cur_btns    As Long
    Dim lmb_down    As Byte
    Dim new_focus   As Long
    Dim cur_item    As Long
    Dim mx          As Long
    Dim btn_wid     As Long
    Dim clicked_col As Long

    VT_TUI_GUARD_FN
    vt_internal_tui_autoinit()

    item_count = UBound(items) - LBound(items) + 1
    item_base  = LBound(items)
    If item_count <= 0 Then Return VT_FORM_PENDING

    If focused < 0            Then focused = 0
    If focused >= item_count  Then focused = item_count - 1
    cur_item = item_base + focused

    ' =========================================================================
    ' mouse
    ' =========================================================================
    cur_btns = vt_internal.mouse_btns
    lmb_down = VT_TUI_LMB_DOWN(cur_btns, vt_internal_tui_form_prev_btns)
    vt_internal_tui_form_prev_btns = cur_btns

    If lmb_down AndAlso vt_internal.mouse_on <> 0 Then
        For i = 0 To item_count - 1
            Select Case items(item_base + i).kind

                Case VT_FORM_INPUT
                    If vt_tui_mouse_in_rect(items(item_base + i).x, items(item_base + i).y, _
                                            items(item_base + i).wid, 1) Then
                        focused  = i
                        cur_item = item_base + focused
                        ' snap cursor to click column, clamped to actual text
                        clicked_col = vt_internal.mouse_col - items(cur_item).x
                        items(cur_item).cpos = items(cur_item).view_off + clicked_col
                        If items(cur_item).cpos > Len(items(cur_item).val) Then
                            items(cur_item).cpos = Len(items(cur_item).val)
                        End If
                        If items(cur_item).cpos < 0 Then items(cur_item).cpos = 0
                        Exit For
                    End If

                Case VT_FORM_BUTTON
                    btn_wid = Len(items(item_base + i).val) + 2
                    If vt_tui_mouse_in_rect(items(item_base + i).x, items(item_base + i).y, _
                                            btn_wid, 1) Then
                        Return items(item_base + i).ret
                    End If
                
                Case VT_FORM_CHECKBOX
                    If vt_tui_mouse_in_rect(items(item_base + i).x, items(item_base + i).y, _
                                            Len(items(item_base + i).val) + 4, 1) Then
                        focused  = i
                        cur_item = item_base + focused
                        items(cur_item).checked = 1 - items(cur_item).checked
                        Exit For
                    End If

                Case VT_FORM_RADIO
                    If vt_tui_mouse_in_rect(items(item_base + i).x, items(item_base + i).y, _
                                            Len(items(item_base + i).val) + 4, 1) Then
                        focused  = i
                        cur_item = item_base + focused
                        vt_internal_tui_form_radio_select(items(), item_base, item_count, cur_item)
                        Exit For
                    End If
                    
            End Select
        Next i
    End If

    ' =========================================================================
    ' keyboard
    ' =========================================================================
    If k = 0 Then Return VT_FORM_PENDING

    sc = VT_SCAN(k)
    ch = VT_CHAR(k)

    ' Escape always cancels regardless of which item is focused
    If sc = VT_KEY_ESC Then Return VT_FORM_CANCEL

    ' Tab / Shift+Tab: advance or retreat focus through all items
    If sc = VT_KEY_TAB Then
        If VT_SHIFT(k) <> 0 Then
            new_focus = focused - 1
            If new_focus < 0 Then new_focus = item_count - 1
        Else
            new_focus = focused + 1
            If new_focus >= item_count Then new_focus = 0
        End If
        focused  = new_focus
        cur_item = item_base + focused
        If items(cur_item).kind = VT_FORM_INPUT Then
            vt_internal_tui_form_enter_input(items(cur_item))
        End If
        Return VT_FORM_PENDING
    End If

    ' item-kind dispatch
    Select Case items(cur_item).kind

        ' =====================================================================
        Case VT_FORM_INPUT
        ' =====================================================================
            mx = items(cur_item).max_len
            If mx < 1 Then mx = items(cur_item).wid

            Select Case sc
                Case VT_KEY_ENTER
                    ' Enter advances focus to the next item (same as Tab)
                    new_focus = focused + 1
                    If new_focus >= item_count Then new_focus = 0
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case VT_KEY_LEFT
                    If items(cur_item).cpos > 0 Then items(cur_item).cpos -= 1
                    vt_internal_tui_form_scroll(items(cur_item))

                Case VT_KEY_RIGHT
                    If items(cur_item).cpos < Len(items(cur_item).val) Then
                        items(cur_item).cpos += 1
                    End If
                    vt_internal_tui_form_scroll(items(cur_item))

                Case VT_KEY_HOME
                    items(cur_item).cpos = 0
                    vt_internal_tui_form_scroll(items(cur_item))

                Case VT_KEY_END
                    items(cur_item).cpos = Len(items(cur_item).val)
                    vt_internal_tui_form_scroll(items(cur_item))

                Case VT_KEY_BKSP
                    If items(cur_item).cpos > 0 Then
                        items(cur_item).val  = Left(items(cur_item).val, items(cur_item).cpos - 1) & _
                                               Mid(items(cur_item).val, items(cur_item).cpos + 1)
                        items(cur_item).cpos -= 1
                        vt_internal_tui_form_scroll(items(cur_item))
                    End If

                Case VT_KEY_DEL
                    If items(cur_item).cpos < Len(items(cur_item).val) Then
                        items(cur_item).val = Left(items(cur_item).val, items(cur_item).cpos) & _
                                              Mid(items(cur_item).val, items(cur_item).cpos + 2)
                    End If

                Case Else
                    If ch >= 32 AndAlso Len(items(cur_item).val) < mx Then
                        items(cur_item).val  = Left(items(cur_item).val, items(cur_item).cpos) & _
                                               Chr(ch) & _
                                               Mid(items(cur_item).val, items(cur_item).cpos + 1)
                        items(cur_item).cpos += 1
                        vt_internal_tui_form_scroll(items(cur_item))
                    End If

            End Select

        ' =====================================================================
        Case VT_FORM_BUTTON
        ' =====================================================================
            Select Case sc
                Case VT_KEY_ENTER
                    Return items(cur_item).ret

                Case VT_KEY_LEFT
                    ' Left on a button retreats to the previous item
                    new_focus = focused - 1
                    If new_focus < 0 Then new_focus = item_count - 1
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case VT_KEY_RIGHT
                    ' Right on a button advances to the next item
                    new_focus = focused + 1
                    If new_focus >= item_count Then new_focus = 0
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

            End Select
            
        ' =====================================================================
        Case VT_FORM_CHECKBOX
        ' =====================================================================
            Select Case sc
                Case VT_KEY_ENTER
                    items(cur_item).checked = 1 - items(cur_item).checked

                Case VT_KEY_LEFT
                    new_focus = focused - 1
                    If new_focus < 0 Then new_focus = item_count - 1
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case VT_KEY_RIGHT
                    new_focus = focused + 1
                    If new_focus >= item_count Then new_focus = 0
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case Else
                    If ch = 32 Then items(cur_item).checked = 1 - items(cur_item).checked

            End Select

        ' =====================================================================
        Case VT_FORM_RADIO
        ' =====================================================================
            Select Case sc
                Case VT_KEY_ENTER
                    vt_internal_tui_form_radio_select(items(), item_base, item_count, cur_item)

                Case VT_KEY_LEFT
                    new_focus = focused - 1
                    If new_focus < 0 Then new_focus = item_count - 1
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case VT_KEY_RIGHT
                    new_focus = focused + 1
                    If new_focus >= item_count Then new_focus = 0
                    focused  = new_focus
                    cur_item = item_base + focused
                    If items(cur_item).kind = VT_FORM_INPUT Then
                        vt_internal_tui_form_enter_input(items(cur_item))
                    End If

                Case Else
                    If ch = 32 Then
                        vt_internal_tui_form_radio_select(items(), item_base, item_count, cur_item)
                    End If

            End Select

    End Select

    Return VT_FORM_PENDING
End Function
