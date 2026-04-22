' ex_tui_form3.bas
' Tests the updated vt_tui_form_draw / vt_tui_form_handle:
'   - All five item kinds: INPUT, BUTTON, CHECKBOX, RADIO, LABEL
'   - VT_FORM_NO_ESC flag (toggled live via the "Lock" checkbox)
'   - Keymap Tab / Shift+Tab / arrow navigation
'   - Enter on INPUT is a strict no-op (Tab moves focus)
'   - Labels demonstrate all three alignment modes:
'       VT_ALIGN_CENTER -- header row
'       VT_ALIGN_LEFT   -- field name labels (default)
'       VT_ALIGN_RIGHT  -- hint line at bottom of window
'
' Layout inside a 46x13 window (inner body cols 3-46, rows 2-12):
'   Row  2: [centered]  "User Configuration"
'   Row  3: "Name   :"  [__________________]
'   Row  5: "Option :"  [x] Enable feature
'   Row  6: "Mode   :"  (*) Fast  ( ) Safe  ( ) Off
'   Row  8: "Lock   :"  [ ] Disable Escape
'   Row 10: [  OK  ]   [Cancel]
'   Row 12: [right]  "Tab to navigate"
' ---------------------------------------------------------------------------
#Define VT_USE_TUI
#Include "../vt/vt.bi"

Enum ItemEnum
    ' --- labels (never focused, Tab skips them) ---
    ITEM_LBL_HEADER     ' row 2,  centered -- window section title
    ITEM_LBL_NAME       ' row 3,  left     -- field label
    ITEM_LBL_OPTION     ' row 5,  left     -- field label
    ITEM_LBL_MODE       ' row 6,  left     -- field label
    ITEM_LBL_LOCK       ' row 8,  left     -- field label
    ITEM_LBL_HINT       ' row 12, right    -- navigation hint
    ' --- interactive items ---
    ITEM_NAME
    ITEM_ENABLE
    ITEM_FAST
    ITEM_SAFE
    ITEM_OFF
    ITEM_LOCK
    ITEM_OK
    ITEM_CANCEL
    ITEM_COUNT
End Enum

Dim items(ITEM_COUNT - 1) As vt_tui_form_item
Dim focused   As Long
Dim k         As ULong
Dim res       As Long
Dim running   As Long
Dim frm_flags As Long
Dim lock_hint As String
Dim message   As String

' ---------------------------------------------------------------------------
' Labels
' ---------------------------------------------------------------------------

' Header: centered across the inner window body (x=3, wid=44)
items(ITEM_LBL_HEADER).kind   = VT_FORM_LABEL
items(ITEM_LBL_HEADER).x      = 3
items(ITEM_LBL_HEADER).y      = 2
items(ITEM_LBL_HEADER).wid    = 44
items(ITEM_LBL_HEADER).val    = "User Configuration"
items(ITEM_LBL_HEADER).align  = VT_ALIGN_CENTER
items(ITEM_LBL_HEADER).lbl_fg = VT_BLUE
items(ITEM_LBL_HEADER).lbl_bg = VT_LIGHT_GREY

' Field labels: left-aligned (VT_ALIGN_LEFT = 0, no need to assign)
items(ITEM_LBL_NAME).kind   = VT_FORM_LABEL
items(ITEM_LBL_NAME).x      = 4
items(ITEM_LBL_NAME).y      = 3
items(ITEM_LBL_NAME).wid    = 8
items(ITEM_LBL_NAME).val    = "Name   :"
items(ITEM_LBL_NAME).lbl_fg = VT_BLACK
items(ITEM_LBL_NAME).lbl_bg = VT_LIGHT_GREY

items(ITEM_LBL_OPTION).kind   = VT_FORM_LABEL
items(ITEM_LBL_OPTION).x      = 4
items(ITEM_LBL_OPTION).y      = 5
items(ITEM_LBL_OPTION).wid    = 8
items(ITEM_LBL_OPTION).val    = "Option :"
items(ITEM_LBL_OPTION).lbl_fg = VT_BLACK
items(ITEM_LBL_OPTION).lbl_bg = VT_LIGHT_GREY

items(ITEM_LBL_MODE).kind   = VT_FORM_LABEL
items(ITEM_LBL_MODE).x      = 4
items(ITEM_LBL_MODE).y      = 6
items(ITEM_LBL_MODE).wid    = 8
items(ITEM_LBL_MODE).val    = "Mode   :"
items(ITEM_LBL_MODE).lbl_fg = VT_BLACK
items(ITEM_LBL_MODE).lbl_bg = VT_LIGHT_GREY

items(ITEM_LBL_LOCK).kind   = VT_FORM_LABEL
items(ITEM_LBL_LOCK).x      = 4
items(ITEM_LBL_LOCK).y      = 8
items(ITEM_LBL_LOCK).wid    = 8
items(ITEM_LBL_LOCK).val    = "Lock   :"
items(ITEM_LBL_LOCK).lbl_fg = VT_BLACK
items(ITEM_LBL_LOCK).lbl_bg = VT_LIGHT_GREY

' Hint: right-aligned at the bottom of the window body
items(ITEM_LBL_HINT).kind   = VT_FORM_LABEL
items(ITEM_LBL_HINT).x      = 3
items(ITEM_LBL_HINT).y      = 12
items(ITEM_LBL_HINT).wid    = 44
items(ITEM_LBL_HINT).val    = "Tab to navigate"
items(ITEM_LBL_HINT).align  = VT_ALIGN_RIGHT
items(ITEM_LBL_HINT).lbl_fg = VT_DARK_GREY
items(ITEM_LBL_HINT).lbl_bg = VT_LIGHT_GREY

' ---------------------------------------------------------------------------
' Interactive items
' ---------------------------------------------------------------------------

' Name INPUT
items(ITEM_NAME).kind    = VT_FORM_INPUT
items(ITEM_NAME).x       = 13
items(ITEM_NAME).y       = 3
items(ITEM_NAME).wid     = 20
items(ITEM_NAME).val     = "World"
items(ITEM_NAME).max_len = 20
items(ITEM_NAME).cpos    = Len(items(ITEM_NAME).val)  ' cursor at end of pre-filled text

' Enable CHECKBOX
items(ITEM_ENABLE).kind    = VT_FORM_CHECKBOX
items(ITEM_ENABLE).x       = 13
items(ITEM_ENABLE).y       = 5
items(ITEM_ENABLE).val     = "Enable feature"
items(ITEM_ENABLE).checked = 1

' Mode RADIO group (group_id = 1)
items(ITEM_FAST).kind     = VT_FORM_RADIO
items(ITEM_FAST).x        = 13
items(ITEM_FAST).y        = 6
items(ITEM_FAST).val      = "Fast"
items(ITEM_FAST).group_id = 1
items(ITEM_FAST).checked  = 1

items(ITEM_SAFE).kind     = VT_FORM_RADIO
items(ITEM_SAFE).x        = 23
items(ITEM_SAFE).y        = 6
items(ITEM_SAFE).val      = "Safe"
items(ITEM_SAFE).group_id = 1

items(ITEM_OFF).kind     = VT_FORM_RADIO
items(ITEM_OFF).x        = 33
items(ITEM_OFF).y        = 6
items(ITEM_OFF).val      = "Off"
items(ITEM_OFF).group_id = 1

' Lock CHECKBOX (toggles VT_FORM_NO_ESC)
items(ITEM_LOCK).kind    = VT_FORM_CHECKBOX
items(ITEM_LOCK).x       = 13
items(ITEM_LOCK).y       = 8
items(ITEM_LOCK).val     = "Disable Escape"
items(ITEM_LOCK).checked = 0

' Buttons
items(ITEM_OK).kind = VT_FORM_BUTTON
items(ITEM_OK).x    = 13
items(ITEM_OK).y    = 10
items(ITEM_OK).val  = "  OK  "
items(ITEM_OK).ret  = VT_RET_OK

items(ITEM_CANCEL).kind = VT_FORM_BUTTON
items(ITEM_CANCEL).x    = 24
items(ITEM_CANCEL).y    = 10
items(ITEM_CANCEL).val  = "Cancel"
items(ITEM_CANCEL).ret  = VT_RET_CANCEL

focused   = ITEM_NAME
frm_flags = 0

vt_screen
vt_title "ex_tui_form3"
vt_mouse 1

' Window chrome is static -- draw it once before the loop
vt_tui_window(2, 1, 46, 13, " Settings ", VT_TUI_WIN_SHADOW)

running = 1
Do While running

    If items(ITEM_LOCK).checked <> 0 Then
        frm_flags = VT_FORM_NO_ESC
    Else
        frm_flags = 0
    End If

    k   = vt_inkey()
    res = vt_tui_form_handle(items(), focused, k, frm_flags)

    If res = VT_FORM_CANCEL Then
        running = 0
    ElseIf res = VT_RET_OK Then
        running = 0
        message = "Name: " & items(ITEM_NAME).val & Chr(10) & _
                  "Enable: " & IIf(items(ITEM_ENABLE).checked, "yes", "no") & Chr(10) & _
                  "Mode: " & IIf(items(ITEM_FAST).checked, "Fast", _
                             IIf(items(ITEM_SAFE).checked, "Safe", "Off"))
        vt_tui_dialog("Result", message, VT_DLG_OK)
    ElseIf res = VT_RET_CANCEL Then
        running = 0
    End If

    ' Status bar first -- vt_locate here must not be the last call before present
    If (frm_flags And VT_FORM_NO_ESC) <> 0 Then
        lock_hint = " Escape locked -- uncheck Lock to re-enable  "
    Else
        lock_hint = " Tab/Shift+Tab=focus   Enter=activate button "
    End If
    vt_color(VT_BLACK, VT_CYAN)
    vt_locate(15, 3)
    vt_print(lock_hint)

    ' Widget draw last -- its vt_locate is the final cursor placement before present
    vt_tui_form_draw(items(), focused)

    vt_sleep(16)

Loop

vt_shutdown()
