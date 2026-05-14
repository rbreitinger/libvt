' =============================================================================
' vt_tui.bi - TUI opt-in extension for the VT Virtual Text Screen Library
' =============================================================================

' Guard macros -- place at top of any Sub/Function that draws or reads input.
' Theme setters and pure variable writers do NOT need these.
#Define _VT_TUI_GUARD_SUB     If vt_internal.ready = 0 Then Exit Sub
#Define _VT_TUI_GUARD_FN      If vt_internal.ready = 0 Then Return 0
#Define _VT_TUI_GUARD_FN_STR  If vt_internal.ready = 0 Then Return ""
#Define VT_TUI_INVERT_FG(fg)  ((fg) Xor 15)
#Define VT_TUI_INVERT_BG(bg)  ((bg) Xor 15)

' Left mouse button edge detection: 1 on the frame the LMB transitions from
' up to down, 0 otherwise. cur/prev are the current and previous mouse_btns.
#Define VT_TUI_LMB_DOWN(cur, prev)  IIf(((cur) And 1) <> 0 AndAlso ((prev) And 1) = 0, 1, 0)

' -----------------------------------------------------------------------------
' Key comparison infrastructure.
' VT_TUI_KEY_MASK isolates scancode (bits 16-27) and modifier bits (29-31).
' The char byte (0-7) and repeat flag (28) are deliberately excluded so that
' auto-repeat events and typed characters do not interfere with action matching.
'
' VT_TUI_MKKEY(scan, sh, ct, al) builds a packed ULong for keymap storage.
'   scan = VT_KEY_* scancode constant
'   sh/ct/al = 1 if Shift/Ctrl/Alt must be held, 0 otherwise
'
' VT_TUI_KEY_IS(k, act) -- true when key k matches keymap slot for action act.
' Slot value 0 never matches a real key (vt_inkey returns 0 for "no key").
' -----------------------------------------------------------------------------
Const   VT_TUI_KEY_MASK As ULong = &hEFFF0000  ' bits 16-27 (scan) + bits 29-31 (mods)
#Define VT_TUI_MKKEY(scan, sh, ct, al)    CULng((CULng(scan) Shl 16) Or (CULng(sh) Shl 29) Or (CULng(ct) Shl 30) Or (CULng(al) Shl 31))
#Define VT_TUI_KEY_IS(k, act)             ((k) <> 0 AndAlso ((k) And VT_TUI_KEY_MASK) = (vt_internal_tui_keymap(act) And VT_TUI_KEY_MASK))

'>>>
':topic c_tuiconsts
':short TUI constants/Types (opt-in: VT_USE_TUI)
':group Text UI
'Available when #define VT_USE_TUI is placed
'before #include once "vt/vt.bi".
'
':params
'Dialog Return Codes:
Const VT_RET_CANCEL = 0
Const VT_RET_OK     = 1
Const VT_RET_YES    = 2
Const VT_RET_NO     = 3
'
'Dialog button set flags:
Const VT_DLG_OK          = 1 ' Single OK button
Const VT_DLG_OKCANCEL    = 2 ' OK + Cancel
Const VT_DLG_YESNO       = 3 ' Yes + No
Const VT_DLG_YESNOCANCEL = 4 ' Yes + No + Cancel
Const VT_DLG_NO_ESC      = 8 ' No ESC, mandatory choice
'
'Form item kinds:
Const VT_FORM_INPUT      = 0 ' Single-line text input
Const VT_FORM_BUTTON     = 1 ' Push button
Const VT_FORM_CHECKBOX   = 2 ' Toggleable checkbox
Const VT_FORM_RADIO      = 3 ' Radio Button
Const VT_FORM_LABEL      = 4 ' Static text label
'
'Widget flags:
Const VT_TUI_WIN_CLOSEBTN = 1 ' Render [x] Button
Const VT_TUI_WIN_SHADOW   = 2 ' Drop Shadow
Const VT_TUI_PROG_LABEL   = 1 ' Show nn% on bar
Const VT_TUI_FD_DIRS      = 1 ' Include subdirs in list
Const VT_TUI_FD_DIRSONLY  = 2 ' Dirs only in picker
Const VT_TUI_ED_READONLY  = 1 ' view/scroll only, no editing
'
'Label Alignment:
Const VT_ALIGN_LEFT       = 0 ' (default)
Const VT_ALIGN_CENTER     = 1
Const VT_ALIGN_RIGHT      = 2
'
'Form return codes:
Const VT_FORM_PENDING     = -2 ' Still active
Const VT_FORM_CANCEL      = -1 ' Escape was pressed
'(>= 0)                          Button .ret value 
'
'Form flags:
Const VT_FORM_NO_ESC      = 1  ' Escape does nothing
'
'Menu extraction macros:
#Define VT_TUI_MENU_GROUP(r)  ((r) \ 1000)
    '1-based group index from menu return.
#Define VT_TUI_MENU_ITEM(r)   ((r) Mod 1000)
    '1-based item index within that group.
'
'
' Keymap action constants:
Enum VT_TUI_ACT
    VT_TUI_ACT_NEXT   ' Tab        - focus forward
    VT_TUI_ACT_PREV   ' Shift+Tab  - focus backward
    VT_TUI_ACT_CANCEL ' Escape     - cancel / close
    VT_TUI_ACT_UP     ' Up arrow   - list / editor navigation
    VT_TUI_ACT_DOWN   ' Down arrow
    VT_TUI_ACT_LEFT   ' Left arrow - cursor in input, adjacent focus on buttons
    VT_TUI_ACT_RIGHT  ' Right arrow
    VT_TUI_ACT_PGUP   ' PgUp
    VT_TUI_ACT_PGDN   ' PgDn
    VT_TUI_ACT_HOME   ' Home
    VT_TUI_ACT_END    ' End
    VT_TUI_ACT_COUNT  ' sentinel only
End Enum
'
'Key builder/test macros:
'  VT_TUI_MKKEY(scan, sh, ct, al)
'      Build a packed ULong from scancode and
'      Shift/Ctrl/Alt flags (0 or 1).
'  VT_TUI_KEY_IS(k, act)
'      True when key k matches the keymap slot
'      for action act. Always use this -- never
'      compare scancodes directly.
':see
'vt_tui_dialog
'vt_tui_form_*
'vt_tui_listbox_*
'vt_tui_menubar_*
'vt_tui_keymap
'<<<

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
Dim Shared vt_internal_tui_inited         As Byte  ' theme initialized
Dim Shared vt_internal_tui_keymap_inited  As Byte  ' keymap initialised
Dim Shared vt_internal_tui_menu_prev_btns As Long
Dim Shared vt_internal_tui_form_prev_btns As Long
Dim Shared vt_internal_tui_keymap(VT_TUI_ACT_COUNT - 1) As ULong

' =============================================================================
' vt_tui_form_item
' Describes one element of a form. Caller owns the array and all .val strings.
' .cpos and .view_off are managed internally by vt_tui_form_handle -- set them
' to 0 when initialising your items array and do not modify them afterward.
' Button width on screen is always Len(.val) + 2 (the enclosing [ and ]).
' Checkbox/radio width on screen is always Len(.val) + 4 (glyph + space + label).
' =============================================================================
Type vt_tui_form_item
    kind     As UByte   ' VT_FORM_INPUT / BUTTON / CHECKBOX / RADIO
    x        As Long    ' 1-based column
    y        As Long    ' 1-based row
    wid      As Long    ' input: visible field width; ignored for buttons/checkbox/radio
    val      As String  ' input: current text; button/checkbox/radio: label
    ret      As Long    ' button: return value on activation; others: unused
    max_len  As Long    ' input: max chars allowed (0 = use wid); others: unused
    cpos     As Long    ' internal: byte cursor offset -- managed by form_handle
    view_off As Long    ' internal: horizontal scroll offset -- managed by form_handle
    checked  As Byte    ' checkbox/radio: 0=unchecked, 1=checked; others: unused
    group_id As Long    ' radio: items with same group_id are mutually exclusive.
                        ' 0 = no group. unused for input/button/checkbox.
    align    As Long    ' VT_FORM_LABEL: VT_ALIGN_LEFT/CENTER/RIGHT; others: unused (0)
    lbl_fg   As UByte   ' VT_FORM_LABEL: foreground colour; others: unused (0)
    lbl_bg   As UByte   ' VT_FORM_LABEL: background colour; others: unused (0)
End Type

' =============================================================================
' vt_tui_listbox_state
' Caller-owned mutable state for a non-blocking listbox widget.
' Init before first use: sel=0, top_item=0, last_click_item=-1,
'                        last_click_time=0.0, prev_btns=0
' Read .sel at any time to know the current highlighted item (0-based).
' vt_tui_listbox_handle returns >= 0 (confirmed index) on Enter or double-click,
' VT_FORM_PENDING while the user is still navigating, VT_FORM_CANCEL on Escape.
' =============================================================================
Type vt_tui_listbox_state
    sel             As Long
    top_item        As Long
    last_click_item As Long
    last_click_time As Double
    prev_btns       As Long   ' internal: previous mouse button state for edge detection
End Type

' =============================================================================
' vt_tui_editor_state
' Caller-owned mutable state for a non-blocking multi-line editor/viewer.
' Init before first use: set .work to initial text, .cpos=0, .top_ln=0,
'                        .dirty=0, .flags as needed (VT_TUI_ED_READONLY etc.)
' .dirty is set to 1 on the first character edit and never cleared by the widget.
' vt_tui_editor_handle returns VT_FORM_PENDING while editing is ongoing,
' or VT_FORM_CANCEL when Escape is pressed (caller decides how to respond).
' =============================================================================
Type vt_tui_editor_state
    work    As String   ' live text buffer (Chr(10) newlines)
    cpos    As Long     ' byte cursor offset into work
    top_ln  As Long     ' 0-based index of the first visible line
    dirty   As Byte     ' 0 until first edit, then 1 (never cleared by widget)
    flags   As Long     ' VT_TUI_ED_READONLY etc. -- set once on init
End Type
