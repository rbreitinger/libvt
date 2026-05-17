' =============================================================================
' vt_tui.bas - TUI opt-in extension for the VT Virtual Text Screen Library
' =============================================================================
#Include Once "vt_strings.bas"
#Include Once "vt_file.bas"
#Include Once "vt_tui.bi"

' =============================================================================
' Internal helpers
' =============================================================================

' -----------------------------------------------------------------------------
' vt_internal_tui_save_rect
' Saves a 1-based (ox, oy) rectangle of wid x hei cells into buf().
' ReDims buf to wid * hei - 1. No ready guard -- callers already checked.
' -----------------------------------------------------------------------------
Private Sub vt_internal_tui_save_rect(ox As Long, oy As Long, wid As Long, hei As Long, buf() As vt_cell)
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
Private Sub vt_internal_tui_restore_rect(ox As Long, oy As Long, wid As Long, hei As Long, buf() As vt_cell)
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
Private Sub vt_internal_tui_draw_button(x As Long, y As Long, lbl As String, fg As UByte, bg As UByte)
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
Private Sub vt_internal_tui_draw_scrollbar(x As Long, y As Long, hei As Long, thumb As Long, fg As UByte, bg As UByte)
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
Private Sub vt_internal_tui_draw_bar(row As Long, groups() As String, open_grp As Long)
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

'>>>
':topic vt_tui_theme
':short Set the TUI colour theme (opt-in)
':group Text UI
'Set the colour theme used by all TUI widgets.
'All colours are EGA palette indices (0-15).
'The theme is a single global struct -- there is
'no per-widget override. vt_tui_theme_default
'restores the built-in DOS/BIOS defaults.
'vt_tui_theme sets all fields in one call.
'Neither function requires vt_screen first.
'Auto-init: if neither theme function nor the
'keymap functions are called before the first
'draw call, both the default DOS/BIOS theme and
'the default Windows-style keymap are applied
'automatically.
'Opt-in: define VT_USE_TUI before the include.
'
'Default values:
'  window body:   VT_BLACK on VT_LIGHT_GREY
'  title bar:     VT_WHITE on VT_BLUE
'  status/menu:   VT_BLACK on VT_CYAN
'  button:        VT_BLACK on VT_LIGHT_GREY
'  dialog body:   VT_BLACK on VT_LIGHT_GREY
'  input/editor:  VT_WHITE on VT_DARK_GREY
'
'Focused buttons, selected list items, and open
'menu group headers are rendered with fg and bg
'XOR'd with 15 (full colour inversion). This is
'not configurable.
':syntax
Sub vt_tui_theme(win_fg       As UByte = 16, win_bg       As UByte = 16, _
                 title_fg     As UByte = 16, title_bg     As UByte = 16, _
                 bar_fg       As UByte = 16, bar_bg       As UByte = 16, _
                 btn_fg       As UByte = 16, btn_bg       As UByte = 16, _
                 dlg_fg       As UByte = 16, dlg_bg       As UByte = 16, _
                 inp_fg       As UByte = 16, inp_bg       As UByte = 16, _
                 border_style As UByte = 16 _
                )
        ':params
        'win_fg/bg    Window body text and background.
        'title_fg/bg  Title bar text and background.
        '             Also progress bar filled colour.
        'bar_fg/bg    Status/menu bar text and background.
        'btn_fg/bg    Button text and background.
        'dlg_fg/bg    Dialog body text and background.
        '             Also dropdown menu item rows.
        'inp_fg/bg    Input field and editor colours.
        '             Also progress bar empty colour.
        'border_style 0 = single-line CP437 (default).
        '             1 = double-line CP437.
        ':example
        '' Restore DOS blue-scheme defaults:
        'vt_tui_theme_default()
        '
        '' Custom dark theme:
        'vt_tui_theme(VT_LIGHT_GREY, VT_BLACK, _
        '             VT_WHITE,      VT_DARK_GREY, _
        '             VT_BLACK,      VT_CYAN, _
        '             VT_LIGHT_GREY, VT_DARK_GREY, _
        '             VT_LIGHT_GREY, VT_BLACK, _
        '             VT_WHITE,      VT_DARK_GREY, _
        '             0)
        ':see
        'vt_tui_keymap
        'c_tuiconsts
    '<<<
    If win_fg       <> 16 Then vt_internal_tui_theme.win_fg       = win_fg
    If win_bg       <> 16 Then vt_internal_tui_theme.win_bg       = win_bg
    If title_fg     <> 16 Then vt_internal_tui_theme.title_fg     = title_fg
    If title_bg     <> 16 Then vt_internal_tui_theme.title_bg     = title_bg
    If bar_fg       <> 16 Then vt_internal_tui_theme.bar_fg       = bar_fg
    If bar_bg       <> 16 Then vt_internal_tui_theme.bar_bg       = bar_bg
    If btn_fg       <> 16 Then vt_internal_tui_theme.btn_fg       = btn_fg
    If btn_bg       <> 16 Then vt_internal_tui_theme.btn_bg       = btn_bg
    If dlg_fg       <> 16 Then vt_internal_tui_theme.dlg_fg       = dlg_fg
    If dlg_bg       <> 16 Then vt_internal_tui_theme.dlg_bg       = dlg_bg
    If inp_fg       <> 16 Then vt_internal_tui_theme.inp_fg       = inp_fg
    If inp_bg       <> 16 Then vt_internal_tui_theme.inp_bg       = inp_bg
    If border_style <> 16 Then vt_internal_tui_theme.border_style = border_style
    vt_internal_tui_inited = 1
End Sub

' =============================================================================
' vt_tui_keymap_default
' Resets all keymap slots to standard Windows-like TUI bindings.
' Called automatically on first draw if the user never sets up the keymap.
' No ready guard -- pure array write, screen not required.
' =============================================================================
Sub vt_tui_keymap_default()
    vt_internal_tui_keymap(VT_TUI_ACT_NEXT)   = VT_TUI_MKKEY(VT_KEY_TAB,   0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_PREV)   = VT_TUI_MKKEY(VT_KEY_TAB,   1, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_CANCEL) = VT_TUI_MKKEY(VT_KEY_ESC,   0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_UP)     = VT_TUI_MKKEY(VT_KEY_UP,    0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_DOWN)   = VT_TUI_MKKEY(VT_KEY_DOWN,  0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_LEFT)   = VT_TUI_MKKEY(VT_KEY_LEFT,  0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_RIGHT)  = VT_TUI_MKKEY(VT_KEY_RIGHT, 0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_PGUP)   = VT_TUI_MKKEY(VT_KEY_PGUP,  0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_PGDN)   = VT_TUI_MKKEY(VT_KEY_PGDN,  0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_HOME)   = VT_TUI_MKKEY(VT_KEY_HOME,  0, 0, 0)
    vt_internal_tui_keymap(VT_TUI_ACT_END)    = VT_TUI_MKKEY(VT_KEY_END,   0, 0, 0)
    vt_internal_tui_keymap_inited = 1
End Sub

'>>>
':topic vt_tui_keymap
':short Control TUI widget navigation key bindings
':group Text UI
'Control the navigation key bindings used by all
'TUI widgets. The keymap is a shared array indexed
'by VT_TUI_ACT_* constants. Default bindings
'mirror standard Windows TUI conventions and are
'applied automatically on the first draw call if
'neither function has been called. vt_tui_keymap
'overrides a single slot. vt_tui_keymap_default
'resets all slots to defaults. Neither function
'requires vt_screen first.
'Space (toggle for checkboxes/radio) is matched
'on the character value, not via the keymap, so
'it cannot be rebound.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_keymap(action As Long, k As ULong)
        ':params
        'action  VT_TUI_ACT_* constant for the slot.
        'k       Packed key value from VT_TUI_MKKEY()
        '        or captured from vt_inkey(). Pass 0
        '        to unbind the action.
        ':example
        '' Remap PgUp/PgDn to Ctrl+Up/Ctrl+Down:
        'vt_tui_keymap VT_TUI_ACT_PGUP, _
        '              VT_TUI_MKKEY(VT_KEY_UP,   0, 1, 0)
        'vt_tui_keymap VT_TUI_ACT_PGDN, _
        '              VT_TUI_MKKEY(VT_KEY_DOWN, 0, 1, 0)
        '' Restore default bindings
        'vt_tui_keymap_default()
        ':see
        'vt_tui_theme
        'c_tuiconsts
    '<<<
    If action >= 0 AndAlso action < VT_TUI_ACT_COUNT Then
        vt_internal_tui_keymap(action) = k
    End If
End Sub

' -----------------------------------------------------------------------------
' vt_internal_tui_autoinit
' Auto-applies default theme and keymap on first draw if the user never called
' either setup function. Avoids all-black-on-black / unbound-key surprises.
' No ready guard -- pure struct write, screen not required.
' -----------------------------------------------------------------------------
Private Sub vt_internal_tui_autoinit()
    If vt_internal_tui_inited = 0 Then
        vt_tui_theme_default()
    End If
    If vt_internal_tui_keymap_inited = 0 Then
        vt_tui_keymap_default()
    End If
End Sub

'>>>
':topic vt_tui_rect_fill
':short Fill a rectangle with a character and colour
':group Text UI
'Fill a 1-based rectangle with a single character
'and colour. This is the base drawing primitive --
'all other widgets use it internally to clear
'their area. Use character code 32 (space) for
'a solid colour block.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_rect_fill(x   As Long,  y   As Long, _
                     wid As Long,  hei As Long, _
                     ch  As UByte, _
                     fg  As UByte, bg  As UByte)
        ':params
        'x, y     1-based column and row, top-left corner.
        'wid, hei Width and height in cells.
        'ch       CP437 character code. Use 32 for solid.
        'fg, bg   Foreground and background colour indices.
        ':example
        '' Clear a region to dark grey:
        'vt_tui_rect_fill(1, 1, 40, 10, _
        '                 32, VT_LIGHT_GREY, VT_DARK_GREY)
        '
        '' Solid red banner row:
        'vt_tui_rect_fill(1, 1, 80, 1, 32, VT_BLACK, VT_RED)
        ':see
        'vt_tui_window
        'vt_tui_*line
    '<<<
    Dim r   As Long
    Dim c   As Long
    Dim cel As vt_cell Ptr

    _VT_TUI_GUARD_SUB

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

'>>>
':topic vt_tui_*line
':short Draw a horizontal or vertical separator line
':group Text UI
'Draw a horizontal or vertical separator line
'using CP437 box-drawing characters. The character
'is chosen automatically from the active theme's
'border_style: single-line or double-line.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_hline(x   As Long, y   As Long, _
                 wid As Long, _
                 fg  As UByte, bg As UByte)

        ':params
        'x, y     1-based start column and row.
        'wid/hei  Length of the line in cells.
        'fg, bg   Foreground and background colour indices.
        ':notes
        'vt_tui_vline is the same, just traversing vertical.
        ':example
        '' Horizontal divider across 80-column screen:
        'vt_tui_hline(1, 13, 80, VT_DARK_GREY, VT_BLACK)
        '
        '' Vertical divider at column 40:
        'vt_tui_vline(40, 1, 25, VT_DARK_GREY, VT_BLACK)
        ':see
        'vt_tui_rect_fill
        'vt_tui_window
    '<<<
    Dim c   As Long
    Dim cel As vt_cell Ptr
    Dim hch As UByte

    _VT_TUI_GUARD_SUB
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

Sub vt_tui_vline(x As Long, y As Long, hei As Long, fg As UByte, bg As UByte)
    Dim r   As Long
    Dim cel As vt_cell Ptr
    Dim vch As UByte

    _VT_TUI_GUARD_SUB
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

' wrapper
Sub vt_tui_draw_button(x As Long, y As Long, lbl As String, fg As UByte, bg As UByte)
    vt_internal_tui_draw_button(x, y, lbl, fg, bg)
End Sub

'>>>
':topic vt_tui_label_draw
':short Draw a single-row text label at a position
':group Text UI
'Draw a single-row text label at an arbitrary
'1-based position. The label is clipped or padded
'to exactly wid cells: text shorter than wid is
'padded with the background colour; text longer
'is silently truncated. No state struct required --
'the function is purely passive and should be
'called each frame like any other draw primitive.
'The same functionality is available inside a
'vt_tui_form by setting an item's
'.kind = VT_FORM_LABEL. Label items in a form are
'never focused and are skipped by Tab/Shift+Tab.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_label_draw(x     As Long, _
                      y     As Long, _
                      wid   As Long, _
                      txt   As String, _
                      align As Long, _
                      fg    As UByte, _
                      bg    As UByte)
        ':params
        'x, y   1-based column and row.
        'wid    Field width in cells. Clipped or padded.
        'txt    Label text. Truncated if longer than wid.
        'align  VT_ALIGN_LEFT (0), VT_ALIGN_CENTER (1),
        '       or VT_ALIGN_RIGHT (2).
        'fg, bg Foreground and background colour indices
        '       for the entire field including padding.
        ':example
        '' Left-aligned label:
        'vt_tui_label_draw(4, 3, 10, "Name:", _
        '    VT_ALIGN_LEFT, VT_BLACK, VT_LIGHT_GREY)
        '
        '' Centred heading:
        'vt_tui_label_draw(3, 2, 44, "User Config", _
        '    VT_ALIGN_CENTER, VT_BLUE, VT_LIGHT_GREY)
        ':see
        'vt_tui_form_draw
        'c_tuiconsts
    '<<<
    Dim cel    As vt_cell Ptr
    Dim tlen   As Long
    Dim offset As Long
    Dim c      As Long

    _VT_TUI_GUARD_SUB

    If wid <= 0 Then Exit Sub

    tlen = Len(txt)
    If tlen > wid Then tlen = wid   ' truncate to field width

    Select Case align
        Case VT_ALIGN_RIGHT
            offset = wid - tlen
        Case VT_ALIGN_CENTER
            offset = (wid - tlen) \ 2
        Case Else   ' VT_ALIGN_LEFT
            offset = 0
    End Select

    cel = vt_internal.cells + (y - 1) * vt_internal.scr_cols + (x - 1)

    ' fill entire field width with background first
    For c = 0 To wid - 1
        cel[c].ch = 32 : cel[c].fg = fg : cel[c].bg = bg
    Next c

    ' write text at aligned offset
    For c = 0 To tlen - 1
        cel[offset + c].ch = txt[c]
        ' fg/bg already set in fill pass -- no need to repeat
    Next c

    vt_internal.dirty = 1
End Sub

'>>>
':topic vt_tui_window
':short Draw window chrome: border and title bar
':group Text UI
'Draw window chrome: a border, a title bar, and
'optionally a close button and drop shadow. Does
'NOT save or restore the background and does NOT
'block. The window interior is filled with the
'theme's win_fg/win_bg colours.
'VT_TUI_WIN_CLOSEBTN renders [x] visually only.
'To detect clicks on it use:
'vt_tui_mouse_in_rect(x + wid - 4, y, 3, 1).
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_window(x     As Long, _
                  y     As Long, _
                  wid   As Long, _
                  hei   As Long, _
                  title As String, _
                  flags As Long = 0)
        ':params
        'x, y      1-based column and row, top-left.
        'wid, hei  Outer width and height including border.
        'title     Text centred in the title bar.
        '          Truncated if too long.
        'flags     VT_TUI_WIN_CLOSEBTN and/or
        '          VT_TUI_WIN_SHADOW.
        ':example
        '' Centred 40x12 window with shadow:
        'Dim wx As Long = (80 - 40) \ 2 + 1
        'Dim wy As Long = (25 - 12) \ 2 + 1
        'vt_tui_window(wx, wy, 40, 12, "Settings", _
        '              VT_TUI_WIN_SHADOW)
        ':see
        'vt_tui_rect_fill
        'vt_tui_*line
        'vt_tui_mouse_in_rect
        'c_tuiconsts
    '<<<
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

    _VT_TUI_GUARD_SUB
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

'>>>
':topic vt_tui_statusbar
':short Draw a status/hint bar on a screen row
':group Text UI
'Fill an entire screen row with the theme's
'bar_bg colour and print caption left-aligned in
'bar_fg. Typical use: the last row for a keyboard
'hint bar, or row 2 below a menu bar.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_statusbar(row     As Long, _
                     caption As String)
        ':params
        'row      1-based screen row to fill (full width).
        'caption  Text printed left-aligned. Clipped to
        '         screen width.
        ':example
        'vt_tui_statusbar 25, _
        '    " F1=Help  F10=Menu  Esc=Quit"
        ':see
        'vt_tui_window
        'vt_tui_menubar_draw
    '<<<
    Dim cel  As vt_cell Ptr
    Dim c    As Long
    Dim clen As Long
    Dim bfg  As UByte
    Dim bbg  As UByte

    _VT_TUI_GUARD_SUB
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

'>>>
':topic vt_tui_progress
':short Draw a horizontal progress bar
':group Text UI
'Draw a horizontal progress bar at an arbitrary
'screen position. The filled portion uses the
'theme's title_bg colour; the empty portion uses
'inp_bg. Both halves use space (32) as the
'character so colour alone carries the bar. Pass
'VT_TUI_PROG_LABEL to render a centred nn% label;
'label fg inverts per-cell so it reads correctly
'across both halves.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_progress(x       As Long, _
                    y       As Long, _
                    wid     As Long, _
                    value   As Long, _
                    max_val As Long, _
                    flags   As Long = 0)
        ':params
        'x, y     1-based column and row.
        'wid      Width of the bar in cells.
        'value    Current progress. Clamped to [0..max_val].
        'max_val  Maximum value. Must be > 0.
        'flags    VT_TUI_PROG_LABEL = show nn% label.
        ':example
        'For i As Long = 0 To 100
        '    vt_tui_progress(5, 10, 40, i, 100, _
        '                    VT_TUI_PROG_LABEL)
        '    vt_sleep(20)
        'Next i
        ':see
        'vt_tui_window
        'c_tuiconsts
    '<<<
    Dim cel      As vt_cell Ptr
    Dim c        As Long
    Dim filled   As Long
    Dim full_bg  As UByte
    Dim empty_bg As UByte
    Dim lbl      As String
    Dim llen     As Long
    Dim lstart   As Long
    Dim cur_bg   As UByte

    _VT_TUI_GUARD_SUB
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

'>>>
':topic vt_tui_mouse_in_rect
':short Mouse hit-test helper for TUI widgets
':group Text UI
'Returns 1 if the current mouse position is
'inside the given 1-based rectangle, 0 otherwise.
'Returns 0 immediately if the library is not
'ready or the mouse is disabled. Reads the
'internal mouse state updated by vt_inkey --
'call this after polling input, not before.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Function vt_tui_mouse_in_rect(x   As Long, _
                              y   As Long, _
                              wid As Long, _
                              hei As Long) _
                              As Byte
        ':params
        'x, y       1-based top-left corner of hit area.
        'wid, hei   Width and height in cells.
        ':notes
        'Return values:
        '  1  Mouse cursor is inside the rectangle.
        '  0  Outside, mouse disabled, or not ready.
        ':example
        '' Hover over a 10-cell button at row 5:
        'If vt_tui_mouse_in_rect(10, 5, 10, 1) Then
        '    ' highlight the button
        'End If
        ':see
        'vt_tui_window
        'vt_getmouse
    '<<<
    _VT_TUI_GUARD_FN
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
' Form internal helpers
' =============================================================================

' -----------------------------------------------------------------------------
' vt_internal_tui_form_radio_select
' Sets checked=1 on cur_item and clears all other RADIO items sharing the same
' group_id. group_id=0 is treated as "no group" -- only the item itself is set.
' -----------------------------------------------------------------------------
Private Sub vt_internal_tui_form_radio_select(items() As vt_tui_form_item, _
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
Private Sub vt_internal_tui_form_scroll(ByRef itm As vt_tui_form_item)
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
Private Sub vt_internal_tui_form_enter_input(ByRef itm As vt_tui_form_item)
    itm.cpos     = Len(itm.val)
    itm.view_off = itm.cpos - itm.wid + 1
    If itm.view_off < 0 Then itm.view_off = 0
End Sub

'>>>
':topic vt_tui_listbox_*
':short Non-blocking scrollable list widget
':group Text UI
'Non-blocking scrollable list. Two-function
'design: vt_tui_listbox_draw renders the list
'passively each frame; vt_tui_listbox_handle
'processes one key or mouse event and returns
'immediately. The caller owns the
'vt_tui_listbox_state struct and loops until
'vt_tui_listbox_handle returns a value other
'than VT_FORM_PENDING. A scrollbar is drawn
'automatically on the right edge when the item
'count exceeds the visible height.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_listbox_draw(x       As Long, _
                        y       As Long, _
                        wid     As Long, _
                        hei     As Long, _
                        items() As String, _
                        ByRef st As _
                        vt_tui_listbox_state)

        ':params
        'x, y     1-based column and row, top-left corner.
        'wid, hei Width and visible height in cells.
        '         Scrollbar occupies rightmost cell.
        'items()  Items to display. Any lower bound.
        'st       Caller-owned state. Pass same struct to
        '         both functions every frame.
        'k        Key value from vt_inkey() this frame.
        ':notes
        'Return (vt_tui_listbox_handle):
        '  >= 0           Confirmed 0-based item index.
        '  VT_FORM_PENDING(-2)  Still navigating.
        '  VT_FORM_CANCEL(-1)   Escape pressed.
        '
        'vt_tui_listbox_state fields:
        '  sel             As Long   ' highlighted index
        '  top_item        As Long   ' first visible; init 0
        '  last_click_item As Long   ' init to -1
        '  last_click_time As Double ' init to 0.0
        '  prev_btns       As Long   ' init to 0
        '
        'Key/mouse bindings:
        '  Up/Down          Move selection one item.
        '  PgUp/PgDn        Move by hei items.
        '  Home/End         Jump to first/last item.
        '  Enter            Confirm selection.
        '  Escape           Return VT_FORM_CANCEL.
        '  Click            Highlight clicked item.
        '  Double-click     Confirm clicked item.
        '  Scroll wheel     Scroll the view.
        ':example
        'Dim opts(2) As String
        'opts(0) = "Easy" : opts(1) = "Normal"
        'opts(2) = "Hard"
        '
        'Dim st As vt_tui_listbox_state
        'st.sel = 0 : st.top_item = 0
        'st.last_click_item = -1
        'st.last_click_time = 0.0
        'st.prev_btns = 0
        '
        'vt_tui_window(18, 6, 24, 7, " Difficulty ")
        'Dim picked As Long = VT_FORM_PENDING
        'Dim k As ULong
        'Do While picked = VT_FORM_PENDING
        '    k = vt_inkey()
        '    picked = vt_tui_listbox_handle( _
        '        19, 7, 22, 5, opts(), st, k)
        '    vt_tui_listbox_draw(19, 7, 22, 5, opts(), st)
        '    vt_sleep(16)
        'Loop
        'If picked >= 0 Then
        '    vt_print "Chose: " & opts(picked) & VT_LF
        'End If
        ':see
        'vt_tui_window
        'vt_tui_dialog
        'c_tuiconsts
    '<<<
    Dim item_count  As Long
    Dim item_base   As Long
    Dim need_scroll As Byte
    Dim item_wid    As Long
    Dim max_top     As Long
    Dim thumb_row   As Long
    Dim r           As Long
    Dim c           As Long
    Dim item_idx    As Long
    Dim cel         As vt_cell Ptr
    Dim wfg         As UByte
    Dim wbg         As UByte
    Dim rfg         As UByte
    Dim rbg         As UByte
    Dim txt         As String
    Dim tlen        As Long

    _VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    item_count = UBound(items) - LBound(items) + 1
    If item_count <= 0 Then Exit Sub

    item_base   = LBound(items)
    max_top     = item_count - hei
    If max_top < 0 Then max_top = 0
    need_scroll = IIf(item_count > hei, 1, 0)
    item_wid    = IIf(need_scroll, wid - 1, wid)

    ' clamp state
    If st.sel < 0           Then st.sel = 0
    If st.sel >= item_count Then st.sel = item_count - 1
    If st.top_item < 0      Then st.top_item = 0
    If st.top_item > max_top Then st.top_item = max_top

    wfg = vt_internal_tui_theme.win_fg
    wbg = vt_internal_tui_theme.win_bg

    For r = 0 To hei - 1
        item_idx = st.top_item + r
        cel      = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)

        If item_idx = st.sel Then
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

    If need_scroll Then
        If item_count > hei Then
            thumb_row = st.top_item * (hei - 1) \ (item_count - hei)
        Else
            thumb_row = 0
        End If
        vt_internal_tui_draw_scrollbar(x + wid - 1, y, hei, thumb_row, wfg, wbg)
    End If

    vt_internal.dirty = 1
End Sub

' =============================================================================
' vt_tui_listbox_handle
' Non-blocking event handler for a listbox. Call with vt_inkey() each frame.
' Pass the same (x, y, wid, hei, items()) as vt_tui_listbox_draw.
' Modifies st.sel and st.top_item in place.
'
' Returns the confirmed 0-based index on Enter or double-click (>= 0).
' Returns VT_FORM_PENDING (-2) while the user is still navigating.
' Returns VT_FORM_CANCEL (-1) when Escape is pressed.
'
' Navigation: Up/Down move selection, PgUp/PgDn/Home/End scroll.
' Mouse: single-click highlights, double-click confirms. Wheel scrolls view.
' All navigation keys are read from the keymap (see vt_tui_keymap_default).
' =============================================================================
Function vt_tui_listbox_handle(x As Long, y As Long, wid As Long, hei As Long, _
                                items() As String, ByRef st As vt_tui_listbox_state, _
                                k As ULong) As Long
    Dim item_count   As Long
    Dim item_base    As Long
    Dim max_top      As Long
    Dim need_scroll  As Byte
    Dim item_wid     As Long
    Dim cur_btns     As Long
    Dim lmb_down     As Byte
    Dim clicked_row  As Long
    Dim clicked_item As Long
    Dim whl          As Long

    _VT_TUI_GUARD_FN

    item_count = UBound(items) - LBound(items) + 1
    If item_count <= 0 Then Return VT_FORM_PENDING

    item_base   = LBound(items)
    max_top     = item_count - hei
    If max_top < 0 Then max_top = 0
    need_scroll = IIf(item_count > hei, 1, 0)
    item_wid    = IIf(need_scroll, wid - 1, wid)

    ' --- mouse ---
    cur_btns = vt_internal.mouse_btns
    lmb_down = VT_TUI_LMB_DOWN(cur_btns, st.prev_btns)
    st.prev_btns = cur_btns

    whl = vt_internal.mouse_wheel
    If whl <> 0 Then
        vt_internal.mouse_wheel = 0
        st.top_item -= whl
        If st.top_item < 0        Then st.top_item = 0
        If st.top_item > max_top  Then st.top_item = max_top
        If st.sel < st.top_item              Then st.sel = st.top_item
        If st.sel >= st.top_item + hei Then st.sel = st.top_item + hei - 1
    End If

    If lmb_down AndAlso vt_internal.mouse_on <> 0 Then
        If vt_tui_mouse_in_rect(x, y, item_wid, hei) Then
            clicked_row  = vt_internal.mouse_row - y
            clicked_item = st.top_item + clicked_row
            If clicked_item >= 0 AndAlso clicked_item < item_count Then
                If clicked_item = st.last_click_item AndAlso _
                   (Timer() - st.last_click_time) < 0.5 Then
                    Return clicked_item
                End If
                st.sel             = clicked_item
                st.last_click_item = clicked_item
                st.last_click_time = Timer()
                If st.sel < st.top_item Then st.top_item = st.sel
                If st.sel >= st.top_item + hei Then st.top_item = st.sel - hei + 1
            End If
        End If
    End If

    ' --- keyboard ---
    If k = 0 Then Return VT_FORM_PENDING

    If VT_TUI_KEY_IS(k, VT_TUI_ACT_CANCEL) Then Return VT_FORM_CANCEL

    If VT_TUI_KEY_IS(k, VT_TUI_ACT_UP) Then
        If st.sel > 0 Then
            st.sel -= 1
            If st.sel < st.top_item Then st.top_item = st.sel
        End If
    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_DOWN) Then
        If st.sel < item_count - 1 Then
            st.sel += 1
            If st.sel >= st.top_item + hei Then st.top_item = st.sel - hei + 1
        End If
    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGUP) Then
        st.sel -= hei
        If st.sel < 0 Then st.sel = 0
        If st.sel < st.top_item Then st.top_item = st.sel
    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_PGDN) Then
        st.sel += hei
        If st.sel >= item_count Then st.sel = item_count - 1
        If st.sel >= st.top_item + hei Then st.top_item = st.sel - hei + 1
        If st.top_item > max_top Then st.top_item = max_top
    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_HOME) Then
        st.sel      = 0
        st.top_item = 0
    ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_END) Then
        st.sel      = item_count - 1
        st.top_item = max_top
    ElseIf VT_SCAN(k) = VT_KEY_ENTER Then
        Return st.sel
    End If

    Return VT_FORM_PENDING
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
                       ByRef st As _
                       vt_tui_editor_state)
                       
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
    Dim cur_line    As Long
    Dim cur_col     As Long
    Dim ln_start    As Long
    Dim vis_start   As Long
    Dim scan_pos    As Long
    Dim vis_cur_col As Long
    Dim ln_ctr      As Long
    Dim readonly_f  As Byte
    Dim i           As Long
    Dim r           As Long
    Dim c           As Long
    Dim cel         As vt_cell Ptr
    Dim ifg         As UByte
    Dim ibg         As UByte

    _VT_TUI_GUARD_SUB
    vt_internal_tui_autoinit()

    readonly_f = IIf((st.flags And VT_TUI_ED_READONLY) <> 0, 1, 0)
    ifg        = vt_internal_tui_theme.inp_fg
    ibg        = vt_internal_tui_theme.inp_bg

    ' derive cur_line, cur_col, ln_start from cpos
    cur_line = 0
    ln_start = 0
    For i = 0 To st.cpos - 1
        If st.work[i] = 10 Then
            cur_line += 1
            ln_start  = i + 1
        End If
    Next i
    cur_col = st.cpos - ln_start

    ' clamp top_ln
    If readonly_f Then
        ' cursor is irrelevant in readonly -- clamp by total line count instead
        Dim total_lns As Long = 1
        For i = 0 To Len(st.work) - 1
            If st.work[i] = 10 Then total_lns += 1
        Next i
        Dim max_top As Long = total_lns - hei
        If max_top < 0 Then max_top = 0
        If st.top_ln > max_top Then st.top_ln = max_top
        If st.top_ln < 0 Then st.top_ln = 0
    Else
        If cur_line < st.top_ln Then st.top_ln = cur_line
        If cur_line >= st.top_ln + hei Then st.top_ln = cur_line - hei + 1
        If st.top_ln < 0 Then st.top_ln = 0
    End If

    ' find byte offset of top_ln
    vis_start = 0
    If st.top_ln > 0 Then
        ln_ctr = 0
        For i = 0 To Len(st.work) - 1
            If st.work[i] = 10 Then
                ln_ctr += 1
                If ln_ctr = st.top_ln Then
                    vis_start = i + 1
                    Exit For
                End If
            End If
        Next i
    End If

    ' draw visible lines
    scan_pos = vis_start
    For r = 0 To hei - 1
        cel = vt_internal.cells + (y - 1 + r) * vt_internal.scr_cols + (x - 1)
        For c = 0 To wid - 1
            cel[c].ch = 32 : cel[c].fg = ifg : cel[c].bg = ibg
        Next c
        c = 0
        Do While scan_pos < Len(st.work) AndAlso st.work[scan_pos] <> 10 AndAlso c < wid
            cel[c].ch = st.work[scan_pos]
            cel[c].fg = ifg : cel[c].bg = ibg
            c        += 1
            scan_pos += 1
        Loop
        Do While scan_pos < Len(st.work) AndAlso st.work[scan_pos] <> 10
            scan_pos += 1
        Loop
        If scan_pos < Len(st.work) Then scan_pos += 1
    Next r

    If readonly_f = 0 Then
        vt_internal.cur_visible = 1
        If cur_line >= st.top_ln AndAlso cur_line < st.top_ln + hei Then
            vis_cur_col = cur_col
            If vis_cur_col >= wid Then vis_cur_col = wid - 1
            vt_locate(y + cur_line - st.top_ln, x + vis_cur_col)
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
        ' snap cpos to top of visible area so cursor-lock clamp doesn't fight wheel
        If cur_line < st.top_ln OrElse cur_line >= st.top_ln + hei Then
            p = 0
            Dim ln_c2 As Long = 0
            Do While p < Len(st.work) AndAlso ln_c2 < st.top_ln
                If st.work[p] = 10 Then ln_c2 += 1
                p += 1
            Loop
            st.cpos = p
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

'>>>
':topic vt_tui_menubar_*
':short Horizontal TUI menu bar (opt-in)
':group Text UI
'Horizontal menu bar. Two-function design:
'vt_tui_menubar_draw renders the bar passively
'(non-blocking, call once per frame);
'vt_tui_menubar_handle is non-blocking while no
'menu is open and blocks with its own inner event
'loop while a dropdown is open. No nested submenus
'in v1. No item-level hotkeys in v1.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_menubar_draw(row      As Long, _
                        groups() As String)

        ':params
        'row       1-based screen row for the menu bar.
        'groups()  Group header labels, e.g. "File","Edit".
        'items()   Flat array of all items across all groups
        '          in group order.
        'counts()  Item count per group, parallel to groups.
        'k         Key value from vt_inkey() this frame.
        ':notes
        'Return (vt_tui_menubar_handle):
        '  group*1000 + item_index (both 1-based) when an
        '  item is activated. Use VT_TUI_MENU_GROUP(r) and
        '  VT_TUI_MENU_ITEM(r) to unpack.
        '  0  While idle or after Escape closes dropdown.
        '
        'Opening/navigating dropdowns:
        '  Alt + first letter    Open that group's dropdown.
        '  Click on group header Open that group's dropdown.
        '  Up/Down (open)        Move selection (wraps).
        '  Left/Right (open)     Switch to adjacent group.
        '  Enter (open)          Activate selected item.
        '  Click on item         Activate that item.
        '  Click elsewhere       Close dropdown, return 0.
        '  Escape                Close dropdown, return 0.
        '  
        ':example
        'Dim groups(2) As String
        'groups(0)="File" : groups(1)="Edit"
        'groups(2)="Help"
        '
        'Dim items(6) As String
        'items(0)="New" : items(1)="Open"
        'items(2)="Save" : items(3)="Quit"
        'items(4)="Cut" : items(5)="Copy"
        'items(6)="About"
        '
        'Dim counts(2) As Long
        'counts(0)=4 : counts(1)=2 : counts(2)=1
        '
        'Dim k As ULong
        'Do
        '    k = vt_inkey()
        '    vt_tui_menubar_draw(1, groups())
        '    Dim r As Long = vt_tui_menubar_handle( _
        '        1, groups(), items(), counts(), k)
        '    If r <> 0 Then
        '        Select Case VT_TUI_MENU_GROUP(r)
        '            Case 1
        '                If VT_TUI_MENU_ITEM(r) = 4 Then
        '                    vt_shutdown()
        '                End If
        '        End Select
        '    End If
        '    vt_sleep(16)
        'Loop
        ':see
        'vt_tui_statusbar
        'vt_tui_window
        'hk_alt
        'c_tuiconsts
    '<<<
    _VT_TUI_GUARD_SUB
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
' Alt+first-letter opens a group. The letter is read from VT_CHAR(k).
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
    Dim alt_ch          As UByte   ' letter from Alt+key combo (outer trigger)
    Dim alt_ch2         As UByte   ' letter from Alt+key combo (inner dropdown)

    _VT_TUI_GUARD_FN
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

    ' Alt + first letter: VT_CHAR(k) holds the letter because vt_core
    ' encodes it in the keyrec before delivery.
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
'>>>
':topic vt_tui_form_offset
':short Shift all form item positions by an offset
':group Text UI
'Shift all item positions in a form array by
'(ox, oy). Call once during setup - after filling
'the items array and before entering the main loop
'- to convert window-body-relative coordinates
'to absolute screen coordinates.
'Convention: lay out items with .x/.y relative to
'the inner window body, where (1,1) is the top-
'left cell inside the border. Pass the window's
'outer corner as ox, oy. Because items start at
'local 1 and the border consumes exactly one cell,
'the arithmetic works out without any manual +1.
':notes
'vt_tui_form_offset mutates .x and .y
'permanently. Call it only once per items array.
'Calling it twice will shift everything twice.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_form_offset(items() As vt_tui_form_item, _
                       ox As Long, oy As Long)
        ':params
        'items()  The form array to shift in place.
        'ox, oy   Screen column and row of the window's
        '         outer top-left corner (same values
        '         passed to vt_tui_window).
        ':example
        'Const WIN_X = 21, WIN_Y = 5
        '' fill items() with .x/.y relative to inner body
        '' (1,1) = top-left inside the border
        'vt_tui_form_offset(items(), WIN_X, WIN_Y)
        'vt_tui_window(WIN_X, WIN_Y, 40, 16, " Settings ")
        ':see
        'vt_tui_form_*
        'vt_tui_window
    '<<<
    Dim i          As Long
    Dim item_count As Long
    Dim item_base  As Long
    item_count = UBound(items) - LBound(items) + 1
    item_base  = LBound(items)
    For i = 0 To item_count - 1
        items(item_base + i).x += ox
        items(item_base + i).y += oy
    Next i
End Sub

'>>>
':topic vt_tui_form_*
':short Non-blocking form widget (opt-in)
':group Text UI
'Non-blocking form widget. Two-function design:
'vt_tui_form_draw renders all items passively
'each frame; vt_tui_form_handle processes one
'key or mouse event and returns immediately. The
'caller owns the vt_tui_form_item array and loops
'until vt_tui_form_handle returns a value other
'than VT_FORM_PENDING. VT_USE_TUI automatically
'pulls in VT_USE_STRINGS and VT_USE_FILE.
'NOTE: call vt_tui_form_draw LAST in your loop,
'after any status bars or labels that use
'vt_locate, so the text cursor is placed correctly
'in the focused input field.
'Opt-in: define VT_USE_TUI before the include.
':syntax
Sub vt_tui_form_draw(items()       As _
                     vt_tui_form_item, _
                     ByRef focused As Long)

        ':params
        'items()  Form items array. Any lower bound.
        'focused  0-based index of the focused item.
        '         Updated by form_handle on focus changes.
        'k        Key value from vt_inkey() this frame.
        'flags    VT_FORM_NO_ESC = Escape does nothing.
        ':notes
        'Return (vt_tui_form_handle):
        '  VT_FORM_PENDING(-2)  Still editing.
        '  VT_FORM_CANCEL(-1)   Escape pressed.
        '  >= 0                 Activated button .ret value.
        'Test for done with: result <> VT_FORM_PENDING
        '
        'vt_tui_form_item fields:
        '  kind     As UByte  ' VT_FORM_INPUT/BUTTON etc.
        '  x        As Long   ' 1-based column
        '  y        As Long   ' 1-based row
        '  wid      As Long   ' input/label: field width
        '  val      As String ' input: text; button: label
        '  ret      As Long   ' button: return value
        '  max_len  As Long   ' input: max chars (0=wid)
        '  checked  As Byte   ' checkbox/radio: 0 or 1
        '  group_id As Long   ' radio: mutual-exclusion id
        '  cpos     As Long   ' init to Len(val) for prefill
        '  view_off As Long   ' init to 0 (internal)
        '  align    As Long   ' label: VT_ALIGN_*
        '  lbl_fg   As UByte  ' label: foreground colour
        '  lbl_bg   As UByte  ' label: background colour
        '
        'Key/mouse bindings:
        '  Tab/Shift+Tab  Advance/retreat focus (wraps).
        '                 VT_FORM_LABEL items skipped.
        '  Enter on input No-op; use Tab to leave field.
        '  Enter on button Activate, return .ret.
        '  Enter/Space on checkbox  Toggle .checked.
        '  Enter/Space on radio     Select, clear group.
        '  Left/Right on input      Move text cursor.
        '  Left/Right on button     Move to adjacent item.
        '  Home/End on input        Start/end of text.
        '  Backspace/Del on input   Delete left/right.
        '  Printable on input       Insert at cursor.
        '  Click on input           Focus + cursor snap.
        '  Click on button          Activate immediately.
        '  Click on checkbox        Focus and toggle.
        '  Click on radio           Focus and select.
        '  Escape                   Return VT_FORM_CANCEL.
        '
        ':example
        'Dim fitems(3) As vt_tui_form_item
        '
        'fitems(0).kind    = VT_FORM_INPUT
        'fitems(0).x = 23 : fitems(0).y = 7
        'fitems(0).wid     = 20
        'fitems(0).val     = "Player one"
        'fitems(0).max_len = 20
        'fitems(0).cpos    = Len(fitems(0).val)
        '
        'fitems(1).kind    = VT_FORM_CHECKBOX
        'fitems(1).x = 23 : fitems(1).y = 9
        'fitems(1).val     = "Enable sound"
        'fitems(1).checked = 1
        '
        'fitems(2).kind = VT_FORM_BUTTON
        'fitems(2).x = 23 : fitems(2).y = 12
        'fitems(2).val  = "  OK  "
        'fitems(2).ret  = VT_RET_OK
        '
        'fitems(3).kind = VT_FORM_BUTTON
        'fitems(3).x = 33 : fitems(3).y = 12
        'fitems(3).val  = "Cancel"
        'fitems(3).ret  = VT_RET_CANCEL
        '
        'Dim focused As Long = 0
        'Dim result  As Long = VT_FORM_PENDING
        'Dim k As ULong
        '
        'vt_tui_window 21, 5, 40, 12, " Settings "
        'Do
        '    k = vt_inkey()
        '    result = vt_tui_form_handle(fitems(), focused, k)
        '    vt_tui_statusbar(25, " Tab=Next  Esc=Cancel ")
        '    vt_tui_form_draw(fitems(), focused)
        '    vt_sleep(16)
        'Loop While result = VT_FORM_PENDING
        ':see
        'vt_tui_form_offset
        'vt_tui_window
        'vt_tui_label_draw
        'c_tuiconsts
    '<<<
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

    _VT_TUI_GUARD_SUB
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
                cel[1].fg = glyph_fg  : cel[1].bg = glyph_bg
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
                cel[1].fg = glyph_fg  : cel[1].bg = glyph_bg
                cel[2].ch = Asc(")")  : cel[2].fg = glyph_fg : cel[2].bg = glyph_bg
                cel[3].ch = 32        : cel[3].fg = glyph_fg : cel[3].bg = glyph_bg
                lbl_len = Len(items(item_base + i).val)
                For lbl_c = 0 To lbl_len - 1
                    cel[4 + lbl_c].ch = items(item_base + i).val[lbl_c]
                    cel[4 + lbl_c].fg = glyph_fg : cel[4 + lbl_c].bg = glyph_bg
                Next lbl_c
                
            Case VT_FORM_LABEL
                vt_tui_label_draw(items(item_base + i).x, items(item_base + i).y, _
                                  items(item_base + i).wid, items(item_base + i).val, _
                                  items(item_base + i).align, _
                                  items(item_base + i).lbl_fg, items(item_base + i).lbl_bg)
                                  
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
' Modifies items() state and focused in place.
' focused is passed by reference -- the caller's variable is updated on focus
' changes so the next vt_tui_form_draw call reflects the new active item.
'
' Returns VT_FORM_PENDING (-2) while the form is still active.
' Returns VT_FORM_CANCEL (-1) when Escape is pressed (unless VT_FORM_NO_ESC set).
' Returns the .ret value of a button when it is activated (Enter or click).
'
' Tab / Shift+Tab       -- advance / retreat focus through all items (wraps)
' Enter on button       -- activate that button, return its .ret
' Enter / Space on
'   checkbox / radio    -- toggle or select
' Enter on input        -- no-op (Tab is the focus navigation key)
' Left / Right in input -- cursor movement within the field
' Left / Right on button-- move focus to the adjacent button
' Home / End in input   -- cursor to start / end
' Backspace / Del       -- edit focused input
' Printable char        -- insert into focused input (respects max_len)
' Mouse click input     -- focus it, cursor snaps to click column
' Mouse click button    -- activate immediately, return its .ret
' Mouse click checkbox /
'   radio               -- focus and toggle / select
' Escape                -- return VT_FORM_CANCEL (unless VT_FORM_NO_ESC set)
' All navigation keys are read from the keymap (see vt_tui_keymap_default).
' =============================================================================
Function vt_tui_form_handle(items() As vt_tui_form_item, ByRef focused As Long, _
                             k As ULong, flags As Long = 0) As Long
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
    Dim tab_steps   As Long

    _VT_TUI_GUARD_FN
    vt_internal_tui_autoinit()

    item_count = UBound(items) - LBound(items) + 1
    item_base  = LBound(items)
    If item_count <= 0 Then Return VT_FORM_PENDING

    If focused < 0           Then focused = 0
    If focused >= item_count Then focused = item_count - 1
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
    ' paste  (Shift+INS or MMB sets cp_paste_pend in vt_pump)
    ' Must come before the k=0 early-out so MMB paste is not swallowed.
    ' =========================================================================

    'FIX: copypaste duplicated logic
    If vt_internal.cp_paste_pend AndAlso items(cur_item).kind = VT_FORM_INPUT Then
        vt_internal.cp_paste_pend = 0
        Dim clip_ptr As ZString Ptr = _VT_DRV_GetClipboardText()
        If clip_ptr <> 0 Then
            Dim clip_str As String = *clip_ptr
            _VT_DRV_free(clip_ptr)
            Dim mx_p As Long = items(cur_item).max_len
            If mx_p < 1 Then mx_p = items(cur_item).wid
            Dim pi   As Long
            Dim pch  As UByte
            For pi = 0 To Len(clip_str) - 1
                pch = clip_str[pi]
                ' accept printable ASCII only -- CR/LF and high bytes silently dropped
                If pch >= 32 AndAlso pch <= 126 Then
                    If Len(items(cur_item).val) < mx_p Then
                        items(cur_item).val  = Left(items(cur_item).val, items(cur_item).cpos) & _
                                               Chr(pch) & _
                                               Mid(items(cur_item).val, items(cur_item).cpos + 1)
                        items(cur_item).cpos += 1
                    End If
                End If
            Next pi
            vt_internal_tui_form_scroll(items(cur_item))
        End If
    End If

    If k = 0 Then Return VT_FORM_PENDING

    ' =========================================================================
    ' keyboard
    ' =========================================================================
    If k = 0 Then Return VT_FORM_PENDING

    sc = VT_SCAN(k)
    ch = VT_CHAR(k)

    ' Escape: cancel unless VT_FORM_NO_ESC is set
    If VT_TUI_KEY_IS(k, VT_TUI_ACT_CANCEL) Then
        If (flags And VT_FORM_NO_ESC) = 0 Then Return VT_FORM_CANCEL
        Return VT_FORM_PENDING
    End If

    ' Tab / Shift+Tab: advance or retreat focus, skipping VT_FORM_LABEL items
    If VT_TUI_KEY_IS(k, VT_TUI_ACT_NEXT) OrElse VT_TUI_KEY_IS(k, VT_TUI_ACT_PREV) Then
        If VT_TUI_KEY_IS(k, VT_TUI_ACT_PREV) Then
            new_focus = focused - 1
            If new_focus < 0 Then new_focus = item_count - 1
            tab_steps = 0
            Do While items(item_base + new_focus).kind = VT_FORM_LABEL _
                      AndAlso tab_steps < item_count
                new_focus -= 1
                If new_focus < 0 Then new_focus = item_count - 1
                tab_steps += 1
            Loop
        Else
            new_focus = focused + 1
            If new_focus >= item_count Then new_focus = 0
            tab_steps = 0
            Do While items(item_base + new_focus).kind = VT_FORM_LABEL _
                      AndAlso tab_steps < item_count
                new_focus += 1
                If new_focus >= item_count Then new_focus = 0
                tab_steps += 1
            Loop
        End If
        focused  = new_focus
        cur_item = item_base + focused
        If items(cur_item).kind = VT_FORM_INPUT Then
            vt_internal_tui_form_enter_input(items(cur_item))
        End If
        Return VT_FORM_PENDING
    End If

    ' =========================================================================
    ' per-item key dispatch
    ' =========================================================================
    Select Case items(cur_item).kind

        ' =====================================================================
        Case VT_FORM_INPUT
        ' =====================================================================
            mx = items(cur_item).max_len
            If mx < 1 Then mx = items(cur_item).wid

            If VT_TUI_KEY_IS(k, VT_TUI_ACT_LEFT) Then
                If items(cur_item).cpos > 0 Then items(cur_item).cpos -= 1
                vt_internal_tui_form_scroll(items(cur_item))

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_RIGHT) Then
                If items(cur_item).cpos < Len(items(cur_item).val) Then
                    items(cur_item).cpos += 1
                End If
                vt_internal_tui_form_scroll(items(cur_item))

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_HOME) Then
                items(cur_item).cpos = 0
                vt_internal_tui_form_scroll(items(cur_item))

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_END) Then
                items(cur_item).cpos = Len(items(cur_item).val)
                vt_internal_tui_form_scroll(items(cur_item))

            ElseIf sc = VT_KEY_BKSP Then
                If items(cur_item).cpos > 0 Then
                    items(cur_item).val  = Left(items(cur_item).val, items(cur_item).cpos - 1) & _
                                           Mid(items(cur_item).val, items(cur_item).cpos + 1)
                    items(cur_item).cpos -= 1
                    vt_internal_tui_form_scroll(items(cur_item))
                End If

            ElseIf sc = VT_KEY_DEL Then
                If items(cur_item).cpos < Len(items(cur_item).val) Then
                    items(cur_item).val = Left(items(cur_item).val, items(cur_item).cpos) & _
                                          Mid(items(cur_item).val, items(cur_item).cpos + 2)
                End If

            ElseIf sc = VT_KEY_ENTER Then
                ' Enter on input: no-op. Use Tab / Shift+Tab to move focus.

            ElseIf ch >= 32 AndAlso Len(items(cur_item).val) < mx Then
                items(cur_item).val  = Left(items(cur_item).val, items(cur_item).cpos) & _
                                       Chr(ch) & _
                                       Mid(items(cur_item).val, items(cur_item).cpos + 1)
                items(cur_item).cpos += 1
                vt_internal_tui_form_scroll(items(cur_item))

            End If

        ' =====================================================================
        Case VT_FORM_BUTTON
        ' =====================================================================
            If sc = VT_KEY_ENTER Then
                Return items(cur_item).ret

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_LEFT) Then
                new_focus = focused - 1
                If new_focus < 0 Then new_focus = item_count - 1
                tab_steps = 0
                Do While items(item_base + new_focus).kind = VT_FORM_LABEL _
                          AndAlso tab_steps < item_count
                    new_focus -= 1
                    If new_focus < 0 Then new_focus = item_count - 1
                    tab_steps += 1
                Loop
                focused  = new_focus
                cur_item = item_base + focused
                If items(cur_item).kind = VT_FORM_INPUT Then
                    vt_internal_tui_form_enter_input(items(cur_item))
                End If

            ElseIf VT_TUI_KEY_IS(k, VT_TUI_ACT_RIGHT) Then
                new_focus = focused + 1
                If new_focus >= item_count Then new_focus = 0
                tab_steps = 0
                Do While items(item_base + new_focus).kind = VT_FORM_LABEL _
                          AndAlso tab_steps < item_count
                    new_focus += 1
                    If new_focus >= item_count Then new_focus = 0
                    tab_steps += 1
                Loop
                focused  = new_focus
                cur_item = item_base + focused
                If items(cur_item).kind = VT_FORM_INPUT Then
                    vt_internal_tui_form_enter_input(items(cur_item))
                End If

            End If

        ' =====================================================================
        Case VT_FORM_CHECKBOX
        ' =====================================================================
            ' Enter or Space toggles. Left/Right are no-ops: use Tab to navigate.
            If sc = VT_KEY_ENTER OrElse ch = 32 Then
                items(cur_item).checked = 1 - items(cur_item).checked
            End If

        ' =====================================================================
        Case VT_FORM_RADIO
        ' =====================================================================
            ' Enter or Space selects. Left/Right are no-ops: use Tab to navigate.
            If sc = VT_KEY_ENTER OrElse ch = 32 Then
                vt_internal_tui_form_radio_select(items(), item_base, item_count, cur_item)
            End If

    End Select

    Return VT_FORM_PENDING
End Function
