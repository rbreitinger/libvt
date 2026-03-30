#include once "vt/vt.bi"

vt_init(VT_MODE_80x25)
vt_color(VT_YELLOW, VT_BLUE)
vt_print_center(12, "Hello, World!")
vt_present()
vt_sleep()
vt_shutdown()
