' ex_tui_filedlg.bas -- vt_tui_file_dialog scenarios
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
    Do 
      k = vt_inkey() 
      If k <> 0 Then Exit Do 
      vt_sleep(10)
    Loop
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

vt_screen(VT_SCREEN_0, VT_WINDOWED)
vt_title("test: file_dialog")
vt_mouse(1)

Dim picked As String

' --- 1: open *.bas, navigate and confirm ---
vt_cls()
draw_header("FILEDLG 1 -- Open file (*.bas)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Navigate to a .bas file. Double-click or Enter to confirm.")
vt_locate(4, 2) : vt_print("F2 or OK button also confirms. Backspace goes up one dir.")
vt_locate(5, 2) : vt_print("Tab activates name field. Type a filename directly.")
wait_key("open file dialog")
picked = vt_tui_file_dialog("Open", ".\", "*.bas")
vt_locate(7, 2) : vt_color(VT_YELLOW, VT_BLACK)
If picked = "" Then
    vt_print("Cancelled (empty string).                          ")
Else
    vt_print("Picked: " & Left(picked, 72))
End If
wait_key("filedlg 1 done")

' --- 2: ESC immediately -> empty string ---
vt_cls()
draw_header("FILEDLG 2 -- ESC immediately, expect empty string")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Press ESC immediately in the file dialog.")
wait_key("open ESC test dialog")
picked = vt_tui_file_dialog("Open", ".\", "*.*")
vt_locate(5, 2)
vt_color(IIf(picked = "", VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
vt_print(IIf(picked = "", "PASS: empty string returned", "FAIL: expected empty, got: " & picked))
wait_key("filedlg 2 done")

' --- 3: DIRSONLY, navigate then confirm ---
vt_cls()
draw_header("FILEDLG 3 -- Directory picker (VT_TUI_FD_DIRSONLY)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Only directories shown. Double-click navigates into it.")
vt_locate(4, 2) : vt_print("On a dir entry: Enter or OK confirms the selected dir.")
vt_locate(5, 2) : vt_print("F2 confirms current dir if nothing selected above it.")
wait_key("open dirs dialog")
picked = vt_tui_file_dialog("Select Folder", ".\", "*", VT_TUI_FD_DIRSONLY)
vt_locate(7, 2) : vt_color(VT_YELLOW, VT_BLACK)
If picked = "" Then
    vt_print("Cancelled.                                         ")
Else
    vt_print("Picked: " & Left(picked, 72))
End If
wait_key("all filedlg tests done")

vt_mouse(0)
vt_shutdown()