#include once "vt/vt.bi"

vt_init(VT_MODE_40x25)
vt_color(VT_YELLOW, VT_GREEN)
vt_cls()
vt_print_center(12, "Hello, World!")
vt_present()
vt_sleep()
vt_shutdown()
