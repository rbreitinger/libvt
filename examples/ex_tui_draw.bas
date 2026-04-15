' test_tui_draw.bas -- passive drawing widgets [pass]
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
vt_title("test: draw primitives")

' ---- A: rect_fill ----
vt_cls()
draw_header("DRAW A -- vt_tui_rect_fill (3 blocks)")
vt_tui_rect_fill( 2, 4, 24, 5, Asc("."), VT_BLACK, VT_LIGHT_GREY)
vt_tui_rect_fill(28, 4, 24, 5, Asc("+"), VT_BLACK, VT_CYAN)
vt_tui_rect_fill(54, 4, 24, 5, Asc("#"), VT_BLACK, VT_DARK_GREY)
vt_color(VT_WHITE, VT_BLACK)
vt_locate(3, 2)  : vt_print("light_grey '.'     cyan '+'          dark_grey '#'")
vt_locate(10, 2) : vt_print("All three blocks should be filled edge-to-edge with no gaps.")
wait_key("rect_fill ok?")

' ---- B: hline + vline, both styles ----
vt_cls()
draw_header("DRAW B -- hline / vline (single then double)")
' single (default after theme_default)
vt_tui_hline( 2,  5, 76, VT_YELLOW, VT_BLACK)
vt_tui_vline( 2,  6, 12, VT_YELLOW, VT_BLACK)
vt_color(VT_YELLOW, VT_BLACK)
vt_locate(3, 2) : vt_print("Single-line style (border_style=0)")
' switch to double
vt_tui_theme(VT_BLACK, VT_LIGHT_GREY, VT_WHITE, VT_BLUE, _
             VT_BLACK, VT_CYAN, VT_BLACK, VT_LIGHT_GREY, _
             VT_BLACK, VT_LIGHT_GREY, VT_WHITE, VT_DARK_GREY, 1)
vt_tui_hline( 2, 13, 76, VT_CYAN, VT_BLACK)
vt_tui_vline(78,  6, 12, VT_CYAN, VT_BLACK)
vt_color(VT_CYAN, VT_BLACK)
vt_locate(15, 2) : vt_print("Double-line style (border_style=1)")
vt_tui_theme_default()
wait_key("hline/vline ok?")

' ---- C: window variants ----
vt_cls()
draw_header("DRAW C -- vt_tui_window (4 variants)")
vt_tui_window( 2,  3, 36, 9, "Single Border")
vt_tui_window(40,  3, 36, 9, "Close + Shadow", VT_TUI_WIN_CLOSEBTN Or VT_TUI_WIN_SHADOW)
vt_tui_theme(VT_BLACK, VT_LIGHT_GREY, VT_WHITE, VT_BLUE, _
             VT_BLACK, VT_CYAN, VT_BLACK, VT_LIGHT_GREY, _
             VT_BLACK, VT_LIGHT_GREY, VT_WHITE, VT_DARK_GREY, 1)
vt_tui_window( 2, 14, 36, 9, "Double Border")
vt_tui_window(40, 14, 36, 9, "Double + Close + Shadow", VT_TUI_WIN_CLOSEBTN Or VT_TUI_WIN_SHADOW)
vt_tui_theme_default()
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(23, 2) : vt_print("Verify: shadow on right windows, [x] in title bars, correct borders.")
wait_key("windows ok?")

' ---- D: statusbar ----
vt_cls()
draw_header("DRAW D -- vt_tui_statusbar")
vt_tui_statusbar(24, " F1=Help  F2=Save  F10=Menu  ESC=Quit")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 2) : vt_print("Row 24 should be a filled cyan bar, left-aligned caption.")
vt_locate(6, 2) : vt_print("Row 25 is the wait_key prompt below (yellow, black bg).")
wait_key("statusbar ok?")

' ---- E: progress bars ----
vt_cls()
draw_header("DRAW E -- vt_tui_progress (0% to 100%)")
Dim pv As Long
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 2) : vt_print("Without label:")
For pv = 0 To 4
    vt_tui_progress(2, 4 + pv, 40, pv * 25, 100, 0)
    vt_locate(4 + pv, 44) : vt_print(pv * 25 & "% of 100  ")
Next pv
vt_locate(10, 2) : vt_print("With VT_TUI_PROG_LABEL (centred NN%):")
For pv = 0 To 4
    vt_tui_progress(2, 11 + pv, 40, pv * 25, 100, VT_TUI_PROG_LABEL)
Next pv
vt_locate(17, 2) : vt_print("Edge: 0% and 100% bars should be solid empty / solid full.")
wait_key("progress ok?")

vt_shutdown()