#Define VT_TTY
#Include "../vt/vt.bi"

#if 0 'non ANSI path [ok but wrong colors]
vt_screen()
vt_cls()
vt_color VT_BRIGHT_GREEN
vt_locate 1, 1
vt_print "Hello, TTY!"
vt_color VT_YELLOW
vt_locate 2, 1
vt_print "Row 2 here"
vt_color VT_WHITE
vt_locate 5, 1
vt_print "Your name: "
vt_present()
Dim s As String = vt_input(20)
vt_locate 7, 1
vt_print "Got: " & s
vt_present()
vt_sleep 0
vt_shutdown()

#else ' ANSI parser test [ok]

vt_screen()
vt_cls()
vt_locate 1, 1
vt_print !"\x1b[92mHello, TTY!\x1b[0m"
vt_locate 2, 1
vt_print !"\x1b[93mRow 2 here\x1b[0m"
vt_locate 5, 1
vt_print !"\x1b[97mYour name: \x1b[0m"
vt_present()
Dim s As String = vt_input(20)
vt_locate 7, 1
vt_print "Got: " & s & Chr(10)
vt_present()
vt_sleep 0
vt_shutdown()

#endif