#Define VT_TTY
'#Define VT_USE_ANSI '''windows cmd OK
#Include "../vt/vt.bi"

vt_screen()
vt_print !"\x1b[2J\x1b[1;1H"
vt_print !"\x1b[32mHello, TTY!\x1b[0m" & Chr(10)
vt_print !"Row 2 here" & Chr(10)
vt_locate 5, 1
vt_print !"\x1b[1;33mYour name: \x1b[0m"
vt_present()
Dim s As String = vt_input(20)
vt_locate 7, 1
vt_print "Got: " & s & Chr(10)
vt_present()
vt_sleep 0
vt_shutdown()