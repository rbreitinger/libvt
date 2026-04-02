' simple file viewer, that demonstrates scrolling and view print 
' note that internal hardcoded (ctrl) + shift + PGDN/PGUP always 
' work to scroll IF scrolling was enabled.

#include once "vt/vt.bi"

Dim k  As ULong
Dim f  As Long
Dim ln As String

' --- init videomode in fullscren with 1024 lines of scrollback buffer ---
vt_title "vt_scrollback + vt_view_print Demo"
vt_screen 0, VT_FULLSCREEN_ASPECT
vt_scrollback 1024

' --- draw status bar first, scrolling disabled so it cannot be pushed off ---
vt_scroll_enable 0
vt_locate 25, 1
vt_color VT_BLACK, VT_LIGHT_GREY
vt_print " Press Arrow Up/Down to scroll, ESC to quit" & space(37)
vt_scroll_enable 1

' --- restrict scroll region to rows 1-24 ---
vt_view_print 1, 24
vt_locate 1, 1
vt_color VT_WHITE, VT_BLUE
vt_cls

' --- print file into the scroll region ---
f = FreeFile()
Open "vt/vt_core.bas" For Input As #f
While Not EOF(f)
    Line Input #f, ln
    vt_print(ln & Chr(10))
Wend
Close #f

Do
    k = vt_getkey
    If VT_SCAN(k) = VT_KEY_ESC  Then Exit Do
    If VT_SCAN(k) = VT_KEY_UP   Then vt_scroll 1
    If VT_SCAN(k) = VT_KEY_DOWN Then vt_scroll -1
Loop
