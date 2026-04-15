' simple file viewer, that demonstrates scrolling (hardcoded binds) and view print 
#include once "../vt/vt.bi"

Dim k  As ULong
Dim f  As Long
Dim ln As String

' --- init videomode in fullscren with 4096 lines of scrollback buffer ---
vt_screen 0, VT_FULLSCREEN_ASPECT
vt_scrollback 4096

vt_mouse 1 ' enable internal mouse (hides OS cursor)
vt_setmouse ,,0 ' hide our cursor (trick to entirely hide mouse)

' --- draw status bar first, scrolling disabled so it cannot be pushed off ---
vt_scroll_enable 0
vt_locate 25, 1
vt_color VT_BLACK, VT_LIGHT_GREY
#Ifndef VT_TTY
    vt_print_center 25, "(CTRL) + SHIFT + PGDN/PGUP to scroll, ESC to quit"
#Else
    vt_print_center 25, "ALT + . / - to scroll, ESC to quit"
#Endif
vt_scroll_enable 1

' --- restrict scroll region to rows 1-24 ---
vt_view_print 1, 24
vt_locate 1, 1
vt_color VT_WHITE, VT_BLUE
vt_cls

' --- print file into the scroll region ---
f = FreeFile()
Open "../vt/vt_core.bas" For Input As #f
While Not EOF(f)
    Line Input #f, ln
    vt_print  ln & VT_NEWLINE
Wend
Close #f

' --- main loop, scrolling keys are already handled internally ---
Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC  Then Exit Do
    vt_sleep 1
Loop

vt_shutdown
