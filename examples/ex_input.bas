#include once "../vt/vt.bi"

vt_title "vt_input Demo"
vt_screen

vt_copypaste ( VT_CP_MOUSE Or VT_CP_KBD )

vt_color VT_WHITE, VT_BLUE
vt_locate 12, 20

Dim was_cancelled As Byte
Dim result As String = vt_input( 30, "Hello World", "", @was_cancelled )


If was_cancelled Then   
    vt_color VT_RED, VT_BLACK
    vt_locate 14, 20
    vt_print "canceled!"
else
    vt_color VT_GREEN, VT_BLACK
    vt_locate 14, 20
    vt_print "You typed: " & result
end if

vt_sleep  
vt_shutdown