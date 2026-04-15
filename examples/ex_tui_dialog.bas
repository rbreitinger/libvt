' test_tui_dialog.bas -- vt_tui_dialog scenarios [pass]
#define VT_USE_TUI
#include once "../vt/vt.bi"

Sub draw_header(lbl As String)
    vt_color(VT_WHITE, VT_BLUE)
    vt_print_center(1, lbl)
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

Sub wait_key(prompt As String)
    Dim k As ULong
    vt_color(VT_YELLOW, VT_BLACK)
    vt_locate(25, 1) : vt_print(prompt & " -- press any key")
    vt_present()
    Do 
      k = vt_inkey() 
      If k <> 0 Then Exit Do 
      vt_sleep(10)
    Loop
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

Sub show_ret(row As Long, ret As Long, expected As Long, lbl As String)
    vt_locate(row, 2) : vt_color(VT_YELLOW, VT_BLACK)
    vt_print("Returned " & ret & " (" & lbl & ")")
    vt_locate(row + 1, 2)
    vt_color(IIf(ret = expected, VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
    vt_print(IIf(ret = expected, "PASS", "FAIL: expected " & expected))
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

vt_screen(VT_SCREEN_0, VT_WINDOWED)
vt_title("test: dialog")
vt_mouse(1)
vt_copypaste(VT_CP_MOUSE)

Dim ret As Long

' --- 1: OK + Enter ---
vt_cls()
draw_header("DIALOG 1-3 -- OK and OKCANCEL variants")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Test 1: VT_DLG_OK.  Press Enter on the button.")
wait_key("open dialog 1")
ret = vt_tui_dialog("Information", "Single OK button. Press Enter.", VT_DLG_OK)
show_ret(5, ret, VT_RET_OK, "VT_RET_OK=1")

' --- 2: OKCANCEL + Tab to Cancel ---
vt_locate(8, 2) : vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Test 2: VT_DLG_OKCANCEL. Tab to Cancel, press Enter.")
wait_key("open dialog 2")
ret = vt_tui_dialog("Confirm", "Tab once to Cancel, then Enter.", VT_DLG_OKCANCEL)
show_ret(10, ret, VT_RET_CANCEL, "VT_RET_CANCEL=0")

' --- 3: OKCANCEL + ESC ---
vt_locate(13, 2) : vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Test 3: VT_DLG_OKCANCEL. Press ESC (should return CANCEL).")
wait_key("open dialog 3")
ret = vt_tui_dialog("Confirm", "Press ESC now.", VT_DLG_OKCANCEL)
show_ret(15, ret, VT_RET_CANCEL, "VT_RET_CANCEL=0")
wait_key("dialogs 1-3 done")

' --- 4: YESNO + arrow keys ---
vt_cls()
draw_header("DIALOG 4-6 -- YESNO, NO_ESC, word-wrap")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Test 4: VT_DLG_YESNO. Use Left/Right arrows, then Enter.")
wait_key("open dialog 4")
ret = vt_tui_dialog("Question", "Choose Yes or No with arrow keys, then Enter.", VT_DLG_YESNO)
vt_locate(5, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned " & ret & IIf(ret = VT_RET_YES, " (YES)", IIf(ret = VT_RET_NO, " (NO)", " (?)")))

' --- 5: YESNOCANCEL + NO_ESC ---
vt_locate(7, 2) : vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Test 5: YESNOCANCEL + NO_ESC. Try ESC first (nothing), then pick.")
wait_key("open dialog 5")
ret = vt_tui_dialog("Mandatory", _
      "ESC is disabled (VT_DLG_NO_ESC). Press ESC a few times, then pick any button.", _
      VT_DLG_YESNOCANCEL Or VT_DLG_NO_ESC)
vt_locate(9, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned " & ret & " (any pick is valid here)")

' --- 6: mouse click on button + word-wrap ---
vt_locate(11, 2) : vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Test 6: long text wrap + mouse click. Click any button.")
wait_key("open dialog 6")
ret = vt_tui_dialog("Word Wrap", _
      "This is a deliberately long message to test the automatic word-wrap logic. " & _
      "It should break cleanly across multiple lines without cutting words in half, " & _
      "and the dialog window should auto-size to fit all wrapped lines plus the button row.", _
      VT_DLG_OKCANCEL)
vt_locate(13, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned " & ret & IIf(ret = VT_RET_OK, " (OK)", " (Cancel)"))
wait_key("all dialog tests done")

vt_mouse(0)
vt_shutdown()
