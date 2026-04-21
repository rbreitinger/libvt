' ex_tui_editor.bas -- vt_tui_editor scenarios
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

vt_screen(VT_SCREEN_0)
vt_title("test: editor")

Dim src As String
src = "Line 01: edit me!" & Chr(10) & _
      "Line 02: arrows + Home/End navigate." & Chr(10) & _
      "Line 03: Del deletes right of cursor." & Chr(10) & _
      "Line 04: Enter inserts a newline." & Chr(10) & _
      "Line 05: Backspace deletes left." & Chr(10) & _
      "Line 06: PgUp/PgDn scrolls by page." & Chr(10) & _
      "Line 07: F10 or Ctrl+Enter confirms." & Chr(10) & _
      "Line 08: ESC returns original unchanged." & Chr(10) & _
      "Line 09: ninth line." & Chr(10) & _
      "Line 10: tenth line, end of block."

' --- 1: edit mode, F10 to confirm ---
vt_cls()
draw_header("EDITOR 1 -- edit mode, F10 or Ctrl+Enter to confirm")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Edit freely. F10 or Ctrl+Enter confirms. ESC cancels.")
Dim r1 As String
r1 = vt_tui_editor(2, 5, 76, 14, src)
vt_locate(21, 2) : vt_color(VT_YELLOW, VT_BLACK)
If r1 = src Then
    vt_print("ESC pressed -- original text returned unchanged.")
Else
    vt_print("Confirmed. First 60 chars: " & Left(r1, 60))
End If
wait_key("editor 1 done")

' --- 2: ESC must return original unchanged ---
vt_cls()
draw_header("EDITOR 2 -- press ESC immediately, original must come back")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Press ESC without editing. Returned string must equal original.")
Dim r2 As String
r2 = vt_tui_editor(2, 5, 76, 14, src)
vt_locate(21, 2)
vt_color(IIf(r2 = src, VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
vt_print(IIf(r2 = src, "PASS: original returned unchanged", "FAIL: strings differ (len " & Len(r2) & " vs " & Len(src) & ")"))
wait_key("editor 2 done")

' --- 3: readonly mode ---
vt_cls()
draw_header("EDITOR 3 -- readonly (VT_TUI_ED_READONLY)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Try typing -- nothing should change. Arrows/PgUp/PgDn scroll.")
vt_locate(4, 2) : vt_print("F10 or ESC exits. Returned text must equal original.")
Dim r3 As String
r3 = vt_tui_editor(2, 5, 76, 14, src, VT_TUI_ED_READONLY)
vt_locate(21, 2)
vt_color(IIf(r3 = src, VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
vt_print(IIf(r3 = src, "PASS: readonly, text unchanged", "FAIL: text was modified in readonly mode"))
wait_key("all editor tests done")

vt_shutdown()
