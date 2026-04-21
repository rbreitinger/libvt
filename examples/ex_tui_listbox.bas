' ex_tui_listbox.bas
' Tests vt_tui_listbox_draw / vt_tui_listbox_handle (non-blocking pair).
' Arrows / PgUp / PgDn / Home / End to navigate.
' Enter or double-click confirms. Escape exits.
#Define VT_USE_TUI
#Include "../vt/vt.bi"

' ---------------------------------------------------------------------------
Dim items(9) As String
items(0) = "Alpha"
items(1) = "Bravo"
items(2) = "Charlie"
items(3) = "Delta"
items(4) = "Echo"
items(5) = "Foxtrot"
items(6) = "Golf"
items(7) = "Hotel"
items(8) = "India"
items(9) = "Juliet"

Dim st      As vt_tui_listbox_state
Dim k       As ULong
Dim res     As Long
Dim running As Long

st.sel             = 0
st.top_item        = 0
st.last_click_item = -1
st.last_click_time = 0.0
st.prev_btns       = 0

vt_screen
vt_title "ex_tui_listbox"
vt_mouse 1
vt_locate ,,0

' Window chrome is static -- draw once outside the loop
vt_tui_window(2, 2, 24, 12, " Pick a call sign ", VT_TUI_WIN_SHADOW)

running = 1
Do While running

    k   = vt_inkey()
    res = vt_tui_listbox_handle(3, 3, 22, 10, items(), st, k)

    If res = VT_FORM_CANCEL Then
        running = 0
    ElseIf res >= 0 Then
        vt_tui_dialog("Result", "You picked: " & items(res), VT_DLG_OK)
        running = 0
    End If

    ' Status hint first -- its vt_locate must not clobber the widget cursor
    vt_color(VT_WHITE, VT_DARK_GREY)
    vt_locate(15, 2)
    vt_print(" Arrows/PgUp/PgDn  Enter=OK  Esc=Exit ")

    ' Widget draw last -- its cursor placement is the final one before present
    vt_tui_listbox_draw(3, 3, 22, 10, items(), st)

    vt_sleep(16)

Loop

vt_shutdown()
