' =============================================================================
' tui_form_test.bas
' Tests: menubar, vt_tui_form_draw/handle, dialog, statusbar.
' Exercises background save/restore across all three popup types.
'
' File -> New Contact  opens the address form.
' OK   -> shows a dialog with the entered data, statusbar shows name.
' Cancel / Esc -> returns to main screen, statusbar says "Cancelled."
' File -> Exit  ends the program.
'
' =============================================================================

#Define VT_USE_TUI
#Include Once "../vt/vt.bi"

' ---------------------------------------------------------------------------
' Form layout  (all 1-based, on an 80x25 screen)
' ---------------------------------------------------------------------------
Const FORM_X    = 10    ' window left col
Const FORM_Y    = 3     ' window top row
Const FORM_W    = 60    ' window width
Const FORM_H    = 10    ' window height  (border rows FORM_Y and FORM_Y+FORM_H-1)
Const LBL_COL   = 12    ' left edge of labels
Const INP_COL   = 26    ' left edge of input fields
Const INP_WID   = 40    ' visible width of each input field
' BTN_ROW = one row above the bottom border
Const BTN_ROW   = FORM_Y + FORM_H - 2   ' = 11
' Buttons are centred inside the 58-col body (inner cols 11..68)
' " OK " = 4 chars -> button width 6;  " Cancel " = 8 chars -> button width 10
' total cluster = 6 + 2 gap + 10 = 18;  start = 11 + (58-18)/2 = 31
Const BTN_OK_X  = 31
Const BTN_CX    = 39

' ---------------------------------------------------------------------------
' Menu data
' ---------------------------------------------------------------------------
Dim groups(0) As String
Dim mitems(1) As String   ' menu items flat array
Dim counts(0) As Long

groups(0) = "File"
mitems(0) = "New Contact"
mitems(1) = "Exit"
counts(0) = 2

' ---------------------------------------------------------------------------
' Form items   (0-4 = inputs, 5-6 = buttons)
' ---------------------------------------------------------------------------
Dim flds(6) As vt_tui_form_item

' inputs: kind, position, width, max content length
flds(0).kind = VT_FORM_INPUT : flds(0).x = INP_COL : flds(0).y = FORM_Y + 2
flds(0).wid  = INP_WID       : flds(0).max_len = 50

flds(1).kind = VT_FORM_INPUT : flds(1).x = INP_COL : flds(1).y = FORM_Y + 3
flds(1).wid  = INP_WID       : flds(1).max_len = 50

flds(2).kind = VT_FORM_INPUT : flds(2).x = INP_COL : flds(2).y = FORM_Y + 4
flds(2).wid  = INP_WID       : flds(2).max_len = 80

flds(3).kind = VT_FORM_INPUT : flds(3).x = INP_COL : flds(3).y = FORM_Y + 5
flds(3).wid  = INP_WID       : flds(3).max_len = 20

flds(4).kind = VT_FORM_INPUT : flds(4).x = INP_COL : flds(4).y = FORM_Y + 6
flds(4).wid  = INP_WID       : flds(4).max_len = 80

' buttons
flds(5).kind = VT_FORM_BUTTON : flds(5).x = BTN_OK_X : flds(5).y = BTN_ROW
flds(5).val  = " OK "         : flds(5).ret = VT_RET_OK

flds(6).kind = VT_FORM_BUTTON : flds(6).x = BTN_CX   : flds(6).y = BTN_ROW
flds(6).val  = " Cancel "     : flds(6).ret = VT_RET_CANCEL

' ---------------------------------------------------------------------------
' Runtime state
' ---------------------------------------------------------------------------
Dim k          As ULong
Dim mnu_ret    As Long
Dim frm_ret    As Long
Dim f_focused  As Long
Dim fi         As Long
Dim running    As Byte
Dim form_open  As Byte
Dim status_msg As String
Dim result_msg As String

running    = 1
form_open  = 0
f_focused  = 0
status_msg = "Alt+F: File menu"

' ---------------------------------------------------------------------------
' Open screen
' ---------------------------------------------------------------------------
vt_screen(VT_SCREEN_0, VT_WINDOWED)
vt_mouse(1)
vt_locate( ,,0)

' ---------------------------------------------------------------------------
' Main loop
' ---------------------------------------------------------------------------
Do
    k = vt_inkey()

    ' --- clear background ---
    vt_color(VT_BLACK, VT_BRIGHT_BLUE)
    vt_cls()

    ' --- chrome always drawn on every frame ---
    vt_tui_menubar_draw(1, groups())
    vt_tui_statusbar(25, status_msg)

    ' =========================================================================
    If form_open Then
    ' =========================================================================

        ' draw window chrome
        vt_tui_window(FORM_X, FORM_Y, FORM_W, FORM_H, "New Contact")

        ' draw static labels in window body colour
        vt_color(VT_BLACK, VT_LIGHT_GREY)
        vt_locate(FORM_Y + 2, LBL_COL) : vt_print "First name:"
        vt_locate(FORM_Y + 3, LBL_COL) : vt_print "Last name: "
        vt_locate(FORM_Y + 4, LBL_COL) : vt_print "Address:   "
        vt_locate(FORM_Y + 5, LBL_COL) : vt_print "Phone:     "
        vt_locate(FORM_Y + 6, LBL_COL) : vt_print "E-mail:    "

        ' draw form widgets and handle input
        vt_tui_form_draw(flds(), f_focused)
        frm_ret = vt_tui_form_handle(flds(), f_focused, k)

        If frm_ret <> VT_FORM_PENDING Then
            form_open = 0

            If frm_ret = VT_RET_OK Then
                ' build result string -- only include non-empty fields
                result_msg = flds(0).val & " " & flds(1).val
                If Len(flds(2).val) > 0 Then
                    result_msg &= Chr(10) & "Address: " & flds(2).val
                End If
                If Len(flds(3).val) > 0 Then
                    result_msg &= Chr(10) & "Phone:   " & flds(3).val
                End If
                If Len(flds(4).val) > 0 Then
                    result_msg &= Chr(10) & "E-mail:  " & flds(4).val
                End If

                ' dialog blocks, saves/restores the current screen behind it
                vt_tui_dialog("Contact Saved", result_msg, VT_DLG_OK)

                status_msg = "Saved: " & flds(0).val & " " & flds(1).val
            Else
                ' frm_ret = VT_RET_CANCEL or VT_FORM_CANCEL (Esc)
                status_msg = "Cancelled."
            End If
        End If

    ' =========================================================================
    Else
    ' =========================================================================

        ' menubar_handle is non-blocking while idle;
        ' blocks internally (with save/restore) while a dropdown is open
        mnu_ret = vt_tui_menubar_handle(1, groups(), mitems(), counts(), k)

        If mnu_ret <> 0 Then
            Select Case VT_TUI_MENU_GROUP(mnu_ret)

                Case 1  ' File
                    Select Case VT_TUI_MENU_ITEM(mnu_ret)

                        Case 1  ' New Contact
                            ' reset all input fields and internal state
                            For fi = 0 To 4
                                flds(fi).val      = ""
                                flds(fi).cpos     = 0
                                flds(fi).view_off = 0
                            Next fi
                            f_focused  = 0
                            form_open  = 1
                            status_msg = "Tab/Enter: next field   Shift+Tab: prev   Esc: cancel"

                        Case 2  ' Exit
                            running = 0

                    End Select

            End Select
        End If

    End If  ' form_open

    vt_sleep(10)
Loop While running

vt_shutdown()
