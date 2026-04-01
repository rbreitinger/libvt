#include once "vt/vt.bi"

vt_title  "Hello World Example"       ' set window title
vt_screen VT_SCREEN_0                 ' set video mode
vt_color  VT_YELLOW, VT_BLUE          ' set yellow font on blue background
vt_cls                                ' clears the screen to blue because we set blue as background before
vt_locate , , , 95                    ' set cursor symbol to underscore _
vt_print_center 12, "Hello, World!"   ' print text in row 12 centered
vt_sleep                              ' waits until a key is pressed, vt_sleep already calls vt_present
