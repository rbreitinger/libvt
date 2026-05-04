#include once "../vt/vt.bi"

vt_title  "Custom Screen Mode Demo"       ' set window title

' custom screenres and font size
' up to 255 x 255 cells and either font 8x8, 8x14 or 8x16
vt_screen VT_SCREENPARAM(80, 10, 8, 8), VT_WINDOWED
vt_color VT_YELLOW, VT_BLUE
vt_print_center 5, "HELLO WORLD"
vt_sleep

vt_screen VT_SCREENPARAM(80, 10, 8, 14), VT_WINDOWED
vt_color VT_YELLOW, VT_BLUE
vt_print_center 5, "HELLO WORLD"
vt_sleep

vt_screen VT_SCREENPARAM(80, 10, 8, 16), VT_WINDOWED
vt_color VT_YELLOW, VT_BLUE
vt_print_center 5, "HELLO WORLD"
vt_sleep

vt_shutdown
