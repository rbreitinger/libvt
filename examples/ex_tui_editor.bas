' ex_tui_editor.bas
' Tests vt_tui_editor_draw / vt_tui_editor_handle (non-blocking pair).
' F1 toggles between edit and read-only mode at runtime.
' Escape exits. Dirty flag shown in status bar.
#Define VT_USE_TUI
#Include "../vt/vt.bi"

' ---------------------------------------------------------------------------
Dim st      As vt_tui_editor_state
Dim k       As ULong
Dim res     As Long
Dim running As Long
Dim hint    As String

st.work   = "Line one: type here."  & VT_LF & _
            "Line two: more text."  & VT_LF & _
            "Line three."           & VT_LF & _
            "Line four."            & VT_LF & _
            "Line five."            & VT_LF & _
            "Line six."
st.cpos   = 0
st.top_ln = 0
st.dirty  = 0
st.flags  = 0   ' edit mode; set VT_TUI_ED_READONLY for viewer-only

vt_screen
vt_title "ex_tui_editor"
vt_mouse 1
vt_copypaste(VT_ENABLED)

vt_tui_window(2, 2, 48, 14, " Editor ", VT_TUI_WIN_SHADOW)

running = 1
Do While running

    k = vt_inkey()

    ' F1 toggles readonly at runtime to test both code paths
    If VT_SCAN(k) = VT_KEY_F1 Then
        If (st.flags And VT_TUI_ED_READONLY) <> 0 Then
            st.flags = 0
        Else
            st.flags = VT_TUI_ED_READONLY
        End If
        k = 0
    End If

    res = vt_tui_editor_handle(3, 3, 46, 12, st, k)
    If res = VT_FORM_CANCEL Then running = 0

    ' Status bar first -- vt_locate here must not be the last call before present
    If (st.flags And VT_TUI_ED_READONLY) <> 0 Then
        hint = " [F1=Edit] [Esc=Quit]  VIEW"
    ElseIf st.dirty Then
        hint = " [F1=View] [Esc=Quit]  EDIT *"
    Else
        hint = " [F1=View] [Esc=Quit]  EDIT"
    End If
    vt_color(VT_BLACK, VT_CYAN)
    vt_locate(16, 2)
    vt_print(hint & Space(48 - Len(hint)))

    ' Widget draw last -- its vt_locate sets the final cursor position before present
    vt_tui_editor_draw(3, 3, 46, 12, st)

    vt_sleep(16)

Loop

vt_shutdown()
