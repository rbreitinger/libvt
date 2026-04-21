' ex_tui_form2.bas
' Tests the updated vt_tui_form_draw / vt_tui_form_handle:
'   - All four item kinds: INPUT, BUTTON, CHECKBOX, RADIO
'   - VT_FORM_NO_ESC flag (toggled live via the "Lock" checkbox)
'   - Keymap Tab / Shift+Tab / arrow navigation
'   - Enter on INPUT is a strict no-op (Tab moves focus)
'
' Layout inside a 46x17 window:
'   Row 3 : Name   [__________________]
'   Row 5 : Option [x] Enable feature
'   Row 6 : Mode   (*) Fast  ( ) Safe  ( ) Off
'   Row 8 : Lock   [ ] Disable Escape
'   Row 10: [  OK  ]   [Cancel]
' ---------------------------------------------------------------------------
#Define VT_USE_TUI
#Include "../vt/vt.bi"

Enum ItemEnum
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

' --- Name INPUT ---
items(ITEM_NAME).kind    = VT_FORM_INPUT
items(ITEM_NAME).x       = 12
items(ITEM_NAME).y       = 3
items(ITEM_NAME).wid     = 20
items(ITEM_NAME).val     = "World"
items(ITEM_NAME).max_len = 20
items(ITEM_NAME).cpos    = Len(items(ITEM_NAME).val)  ' cursor starts at end of pre-filled text

' --- Enable CHECKBOX ---
items(ITEM_ENABLE).kind    = VT_FORM_CHECKBOX
items(ITEM_ENABLE).x       = 12
items(ITEM_ENABLE).y       = 5
items(ITEM_ENABLE).val     = "Enable feature"
items(ITEM_ENABLE).checked = 1

' --- Mode RADIO group (group_id = 1) ---
items(ITEM_FAST).kind     = VT_FORM_RADIO
items(ITEM_FAST).x        = 12
items(ITEM_FAST).y        = 6
items(ITEM_FAST).val      = "Fast"
items(ITEM_FAST).group_id = 1
items(ITEM_FAST).checked  = 1

items(ITEM_SAFE).kind     = VT_FORM_RADIO
items(ITEM_SAFE).x        = 22
items(ITEM_SAFE).y        = 6
items(ITEM_SAFE).val      = "Safe"
items(ITEM_SAFE).group_id = 1

items(ITEM_OFF).kind     = VT_FORM_RADIO
items(ITEM_OFF).x        = 32
items(ITEM_OFF).y        = 6
items(ITEM_OFF).val      = "Off"
items(ITEM_OFF).group_id = 1

' --- Lock CHECKBOX (toggles VT_FORM_NO_ESC) ---
items(ITEM_LOCK).kind    = VT_FORM_CHECKBOX
items(ITEM_LOCK).x       = 12
items(ITEM_LOCK).y       = 8
items(ITEM_LOCK).val     = "Disable Escape"
items(ITEM_LOCK).checked = 0

' --- Buttons ---
items(ITEM_OK).kind = VT_FORM_BUTTON
items(ITEM_OK).x    = 12
items(ITEM_OK).y    = 10
items(ITEM_OK).val  = "  OK  "
items(ITEM_OK).ret  = VT_RET_OK

items(ITEM_CANCEL).kind = VT_FORM_BUTTON
items(ITEM_CANCEL).x    = 23
items(ITEM_CANCEL).y    = 10
items(ITEM_CANCEL).val  = "Cancel"
items(ITEM_CANCEL).ret  = VT_RET_CANCEL

focused   = ITEM_NAME
frm_flags = 0

vt_screen
vt_title "ex_tui_form3"
vt_mouse 1

vt_tui_window(2, 1, 46, 13, " Settings ", VT_TUI_WIN_SHADOW)

' Static labels -- drawn once outside the loop
vt_color(VT_BLACK, VT_LIGHT_GREY)
vt_locate(3,  4) : vt_print("Name  :")
vt_locate(5,  4) : vt_print("Option:")
vt_locate(6,  4) : vt_print("Mode  :")
vt_locate(8,  4) : vt_print("Lock  :")

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
