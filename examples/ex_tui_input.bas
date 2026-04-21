' ex_tui_input.bas -- vt_tui_input_field scenarios
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
      vt_sleep(10 )
    Loop
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

Sub pass_fail(row As Long, ok As Byte, detail As String)
    vt_color(IIf(ok, VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
    vt_locate(row, 2)
    vt_print(IIf(ok, "PASS", "FAIL") & ": " & detail & String(30, " "))
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

vt_screen(VT_SCREEN_0, VT_WINDOWED)
vt_title("test: input_field")

' --- 1: confirm with Enter ---
vt_cls()
draw_header("INPUT 1 -- edit preloaded text, confirm with Enter")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Field preloaded with 'Ada Lovelace' (max 40). Edit, then Enter.")
Dim r1 As String
r1 = vt_tui_input_field(2, 7, 50, "Ada Lovelace", 40)
vt_locate(9, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned: [" & r1 & "]  (len=" & Len(r1) & ")")
wait_key("input 1 done")

' --- 2: ESC must return original unchanged ---
vt_cls()
draw_header("INPUT 2 -- press ESC, original must come back")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Field preloaded with 'Original Text'. Press ESC immediately.")
Dim r2 As String
r2 = vt_tui_input_field(2, 7, 50, "Original Text", 40)
vt_locate(9, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned: [" & r2 & "]")
pass_fail(10, (r2 = "Original Text"), "expected 'Original Text', got '" & r2 & "'")
wait_key("input 2 done")

' --- 3: max_len clamps input ---
vt_cls()
draw_header("INPUT 3 -- max_len=6, try typing 15+ chars")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Field is empty, max_len=6, width=30. Type a long string, Enter.")
Dim r3 As String
r3 = vt_tui_input_field(2, 7, 30, "", 6)
vt_locate(9, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned: [" & r3 & "]  (len=" & Len(r3) & ")")
pass_fail(10, (Len(r3) <= 6), "len=" & Len(r3) & " must be <= 6")
wait_key("input 3 done")

' --- 4: empty initial, confirm empty ---
vt_cls()
draw_header("INPUT 4 -- empty initial, press Enter without typing")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Field is empty. Press Enter without typing anything.")
Dim r4 As String
r4 = vt_tui_input_field(2, 7, 50, "", 40)
vt_locate(9, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned: [" & r4 & "]  (len=" & Len(r4) & ")")
pass_fail(10, (r4 = ""), "expected empty string")
wait_key("input 4 done")

' --- 5: narrow display width vs long content ---
vt_cls()
draw_header("INPUT 5 -- wide content in narrow display field")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Display wid=10, max_len=40. Preloaded with a long string.")
vt_locate(6, 2) : vt_print("Cursor should scroll within the narrow visible area.")
Dim r5 As String
r5 = vt_tui_input_field(2, 8, 10, "This is a long preloaded string", 40)
vt_locate(10, 2) : vt_color(VT_YELLOW, VT_BLACK)
vt_print("Returned: [" & r5 & "]  (len=" & Len(r5) & ")")
wait_key("all input tests done")

vt_shutdown()