#include once "vt/vt.bi"

Dim choice As String
Dim k      As ULong
Dim answer As String

vt_title "vt_getchar Demo"
vt_screen
vt_view_print 1, 24
vt_locate , , 0

'--- status bar ---
vt_color VT_WHITE, VT_DARK_GREY
vt_locate 25, 1
vt_print " vt_getchar demo" & Space(64)

' ==========================================================================
' menu with vt_getchar filtered
' ==========================================================================
vt_color VT_WHITE, VT_BLACK
vt_cls
vt_locate 3, 4  : vt_print "Menu selection with vt_getchar(allowed)"
vt_color VT_LIGHT_GREY, VT_BLACK

vt_locate 5, 4  : vt_print "Only keys 1-3 are accepted. Any other key is silently ignored."
vt_locate 7, 4  : vt_print "1. New Game"
vt_locate 8, 4  : vt_print "2. Load Game"
vt_locate 9, 4  : vt_print "3. Quit"
vt_color VT_YELLOW, VT_BLACK
vt_locate 11, 4 : vt_print "Your choice: "
vt_present

choice = vt_getchar("123")

vt_color VT_BRIGHT_GREEN, VT_BLACK
vt_locate 11, 17 : vt_print choice
vt_color VT_LIGHT_GREY, VT_BLACK
vt_locate 13, 4

Select Case choice
    Case "1" : vt_print "You chose: New Game"
    Case "2" : vt_print "You chose: Load Game"
    Case "3" : vt_print "You chose: Quit"
End Select

vt_locate 15, 4 : vt_print "Press any key to quit..."

vt_sleep 
vt_shutdown