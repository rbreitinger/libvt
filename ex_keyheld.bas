#include once "vt/vt.bi"

Dim px    As Long = 40
Dim py    As Long = 12
Dim moved As Byte

vt_title "vt_key_held Demo"
vt_screen
vt_view_print 1, 24
vt_locate , , 0     ' hide cursor

vt_color VT_YELLOW, VT_BLUE
vt_locate 25, 1
vt_print "   Hold arrow keys to move - ESC to quit" & Space(40)

moved = 1

Do
    If vt_key_held(VT_KEY_UP)    AndAlso py > 1  Then py -= 1 : moved = 1
    If vt_key_held(VT_KEY_DOWN)  AndAlso py < 24 Then py += 1 : moved = 1
    If vt_key_held(VT_KEY_LEFT)  AndAlso px > 2  Then px -= 2 : moved = 1
    If vt_key_held(VT_KEY_RIGHT) AndAlso px < 80 Then px += 2 : moved = 1

    If moved Then
        vt_cls VT_BLACK
        vt_set_cell(px, py, 2, VT_BRIGHT_BLUE, VT_BLACK)
        vt_present
        moved = 0
    End If

    If vt_key_held(VT_KEY_ESC) Then Exit Do
    
    vt_sleep 16
Loop 
vt_shutdown