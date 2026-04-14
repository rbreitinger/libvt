#Define VT_TTY
#Include "../vt/vt.bi"

vt_screen()
vt_print !"\e[2J\e[1;1H"
vt_print !"\e[32mHello, TTY!\e[0m\n"
vt_print !"Row 2 here\n"
vt_locate 5, 1
vt_print !"\e[1;33mYour name: \e[0m"
vt_present()
Dim s As String = vt_input(20)
vt_locate 7, 1
vt_print "Got: " & s & Chr(10)
vt_present()
vt_sleep 0
vt_shutdown()