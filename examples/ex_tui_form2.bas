' ex_tui_form2.bas -- demonstrates VT_FORM_CHECKBOX and VT_FORM_RADIO
#Define VT_USE_TUI
#Include Once "../vt/vt.bi"

' ---------------------------------------------------------------------------
' build_summary -- read form state, return human-readable result string
' ---------------------------------------------------------------------------
Function build_summary(items() As vt_tui_form_item) As String
    Dim snd_str  As String
    Dim hint_str As String
    Dim diff_str As String

    If items(0).checked Then snd_str  = "On"  Else snd_str  = "Off"
    If items(1).checked Then hint_str = "On"  Else hint_str = "Off"

    If items(2).checked Then
        diff_str = "Easy"
    ElseIf items(3).checked Then
        diff_str = "Normal"
    Else
        diff_str = "Hard"
    End If

    Return "Sound:      " & snd_str  & Chr(10) & _
           "Show hints: " & hint_str & Chr(10) & _
           "Difficulty: " & diff_str
End Function

' ---------------------------------------------------------------------------
' main
' ---------------------------------------------------------------------------
Const WIN_X = 21
Const WIN_Y = 6
Const WIN_W = 40
Const WIN_H = 14

Dim As Long  ret, focused
Dim k        As ULong
Dim items(5) As vt_tui_form_item

' --- checkboxes ---
items(0).kind    = VT_FORM_CHECKBOX : items(0).x = WIN_X + 2 : items(0).y = WIN_Y + 2
items(0).val     = "Enable sound"   : items(0).checked = 1

items(1).kind    = VT_FORM_CHECKBOX : items(1).x = WIN_X + 2 : items(1).y = WIN_Y + 3
items(1).val     = "Show hints"     : items(1).checked = 0

' --- radio group 1 (Difficulty) ---
items(2).kind     = VT_FORM_RADIO : items(2).x = WIN_X + 2 : items(2).y = WIN_Y + 6
items(2).val      = "Easy"        : items(2).checked = 1    : items(2).group_id = 1

items(3).kind     = VT_FORM_RADIO : items(3).x = WIN_X + 2 : items(3).y = WIN_Y + 7
items(3).val      = "Normal"      : items(3).checked = 0    : items(3).group_id = 1

items(4).kind     = VT_FORM_RADIO : items(4).x = WIN_X + 2 : items(4).y = WIN_Y + 8
items(4).val      = "Hard"        : items(4).checked = 0    : items(4).group_id = 1

' --- OK button -- centered: inner width=38, button width=6, offset=(38-6)/2=16 ---
items(5).kind = VT_FORM_BUTTON : items(5).x = WIN_X + 17 : items(5).y = WIN_Y + 11
items(5).val  = " OK "         : items(5).ret = VT_RET_OK

focused = 0
ret     = VT_FORM_PENDING

vt_title "Form Demo -- Checkbox & Radio"
vt_screen VT_SCREEN_0, VT_WINDOWED Or VT_NO_RESIZE
vt_mouse 1

Do
    k   = vt_inkey()
    ret = vt_tui_form_handle(items(), focused, k)

    If ret = VT_FORM_CANCEL Then Exit Do
    If ret >= 0 Then
        vt_tui_dialog("Your selection", build_summary(items()), VT_DLG_OK)
        Exit Do
    End If

    ' --- draw ---
    vt_tui_window(WIN_X, WIN_Y, WIN_W, WIN_H, "Settings")
    
    ' static section label between checkboxes and radio group
    vt_color(VT_BLACK, VT_LIGHT_GREY)
    vt_locate(WIN_Y + 5, WIN_X + 2)
    vt_print("Difficulty:")

    vt_tui_form_draw(items(), focused)
    vt_tui_statusbar(25, " Tab=Next   Space/Enter=Toggle   Esc=Cancel ")

    vt_sleep 16
Loop

vt_shutdown()
