' =============================================================================
' vt_scrolltest.bas - scrollback + vt_view_print test
' =============================================================================

#include once "vt/vt.bi"

Dim k  As ULong
Dim f  As Long
Dim ln As String

vt_init(VT_MODE_80x25, , VT_FULLSCREEN_STRETCH, 1024)

' --- draw status bar first, scrolling disabled so it cannot be pushed off ---
vt_scroll_enable(0)
vt_locate(25, 1)
vt_color(VT_BLACK, VT_LIGHT_GREY)
vt_print(" Shift+PgUp / Shift+PgDn to scroll   ESC to quit" & Space(32))
vt_scroll_enable(1)

' --- restrict scroll region to rows 1-24 ---
vt_view_print(1, 24)
vt_locate(1, 1)
vt_color(VT_WHITE, VT_BLUE)

' --- print file into the scroll region ---
f = FreeFile()
Open "vt/vt_core.bas" For Input As #f
While Not EOF(f)
    Line Input #f, ln
    vt_print(ln & Chr(10))
Wend
Close #f

vt_present()

Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do
    If vt_should_quit() Then Exit Do
    Sleep 10
Loop

vt_view_print_reset()
vt_shutdown()