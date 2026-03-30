#include once "vt/vt.bi"

vt_init(VT_MODE_40x25)                ' set video mode

vt_color(VT_YELLOW, VT_BLUE)          ' set yellow font on blue background

vt_cls()                              ' clears the screen to blue because we set blue as background before

vt_print_center(12, "Hello, World!")  ' print text in line 12 centered

vt_present()                          ' copy from memory to screen

vt_sleep()                            ' waits until a key is pressed

vt_shutdown()                         ' quits the program cleanly, always use it
