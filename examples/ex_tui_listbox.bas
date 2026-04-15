' test_tui_listbox.bas -- vt_tui_listbox scenarios [fully passed]
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

Sub pass_fail(row As Long, ok As Byte, detail As String)
    vt_color(IIf(ok, VT_BRIGHT_GREEN, VT_BRIGHT_RED), VT_BLACK)
    vt_locate(row, 2)
    vt_print(IIf(ok, "PASS", "FAIL") & ": " & detail & String(30, " "))
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

vt_screen(VT_SCREEN_0, VT_WINDOWED)
vt_title("test: listbox")
vt_mouse(1)

' --- 1: exact fit, no scrollbar ---
Dim sm(3) As String
sm(0) = "Alpha" : sm(1) = "Beta" : sm(2) = "Gamma" : sm(3) = "Delta"

vt_cls()
draw_header("LISTBOX 1 -- 4 items, height=4 (exact fit, no scrollbar)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("No scrollbar should appear. Up/Down + Enter, or click item.")
vt_locate(4, 2) : vt_print("Double-click also confirms.")
Dim pk1 As Long
pk1 = vt_tui_listbox(20, 6, 22, 4, sm())
vt_locate(12, 2) : vt_color(VT_YELLOW, VT_BLACK)
If pk1 = -1 Then
    vt_print("Cancelled (ESC returned -1).")
Else
    vt_print("Selected " & pk1 & ": '" & sm(pk1) & "'")
End If
wait_key("listbox 1 done")

' --- 2: large list, scrollbar + wheel ---
Dim big(14) As String
big(0)  = "01 - Apple"    : big(1)  = "02 - Banana"   : big(2)  = "03 - Cherry"
big(3)  = "04 - Date"     : big(4)  = "05 - Elderberry": big(5)  = "06 - Fig"
big(6)  = "07 - Grape"    : big(7)  = "08 - Honeydew" : big(8)  = "09 - Kiwi"
big(9)  = "10 - Lemon"    : big(10) = "11 - Mango"    : big(11) = "12 - Nectarine"
big(12) = "13 - Orange"   : big(13) = "14 - Papaya"   : big(14) = "15 - Quince"

vt_cls()
draw_header("LISTBOX 2 -- 15 items, height=6 (scrollbar visible, wheel)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Scrollbar on right. Mouse wheel scrolls view.")
vt_locate(4, 2) : vt_print("PgUp/PgDn/Home/End also work. Double-click or Enter confirms.")
Dim pk2 As Long
pk2 = vt_tui_listbox(20, 6, 24, 6, big())
vt_locate(14, 2) : vt_color(VT_YELLOW, VT_BLACK)
If pk2 = -1 Then
    vt_print("Cancelled.")
Else
    vt_print("Selected " & pk2 & ": '" & big(pk2) & "'")
End If
wait_key("listbox 2 done")

' --- 3: ESC must return -1 ---
Dim one(0) As String
one(0) = "Only item"

vt_cls()
draw_header("LISTBOX 3 -- ESC must return -1")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Press ESC immediately. Return value must be -1.")
Dim pk3 As Long
pk3 = vt_tui_listbox(20, 6, 22, 3, one())
pass_fail(10, (pk3 = -1), "expected -1, got " & pk3)
wait_key("listbox 3 done")

' --- 4: single-item list, confirm ---
vt_cls()
draw_header("LISTBOX 4 -- single item, confirm with Enter")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Only one item. Press Enter to confirm index 0.")
Dim pk4 As Long
pk4 = vt_tui_listbox(20, 6, 22, 3, one())
pass_fail(10, (pk4 = 0), "expected 0, got " & pk4)
wait_key("all listbox tests done")
vt_shutdown()