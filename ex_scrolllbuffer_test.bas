' simple file viewer, that demonstrates scrolling and view print 
' note that internal hardcoded (ctrl) + shift + PGDN/PGUP always 
' work to scroll IF scrolling was enabled.

#include once "vt/vt.bi"

Dim k  As ULong
Dim f  As Long
Dim ln As String

' --- init videomode in fullscren with 1024 lines of scrollback buffer ---
vt_title "vt_scrollback + vt_view_print Demo"
vt_screen 0', VT_FULLSCREEN_ASPECT
vt_scrollback 1024
vt_copypaste ( VT_CP_MOUSE Or VT_CP_KBD )

vt_mouse 1

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
    vt_print  ln & VT_NEWLINE
Wend
Close #f

Dim As Long mx, my, mb, mw, oldmw, wheelaccum
Do
    oldmw = mw
    vt_getmouse(@mx, @my, @mb, @mw)
    wheelaccum += mw
    
    If (mb And VT_MOUSE_BTN_LEFT) AndAlso my < 25 Then
        If vt_internal.sb_offset = 0 Then vt_locate my, mx
    End If
    
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC  Then Exit Do
    If VT_SCAN(k) = VT_KEY_UP   orelse oldmw < mw Then vt_scroll wheelaccum : wheelaccum = 0
    If VT_SCAN(k) = VT_KEY_DOWN orelse oldmw > mw Then vt_scroll wheelaccum : wheelaccum = 0
    vt_sleep 10
Loop

vt_shutdown
