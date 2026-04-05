#include "vt/vt.bi"

vt_Screen VT_SCREEN_EGA43, VT_WINDOWED_MAX

'' Load a custom bitmapped font (128x128) and use magenta as mask color (255, 0, 255)
dim as long result = vt_LoadFont("Zaratustra_msx.bmp", 128, 128, 255, 0, 255)

vt_color 9
vt_print_center(11, "Custom Bitmapped Font Loading Demo" & VT_NEWLINE)
vt_color 4
vt_print_center(13, "Zaratustra_msx.bmp 8x8 glyphs" & VT_NEWLINE)
vt_color 15
vt_print_center(15, "- Any key to continue -" & VT_NEWLINE)

vt_sleep

vt_Screen VT_SCREEN_TILES, VT_WINDOWED_MAX

'' Load a custom bitmapped font, auto detect size and use magenta as mask color (255, 0, 255)
result = vt_LoadFont("GuybrushASCII_curses_square_16x16.bmp", , , 255, 0, 255)

vt_color 5
vt_print_center(11, "Custom Bitmapped Font Loading Demo" & VT_NEWLINE)
vt_color 10
vt_print_center(13, "GuybrushASCII_curses_square_16x16.bmp" & VT_NEWLINE)
vt_color 11
vt_print_center(15, "- Any key to continue -"& VT_NEWLINE)

vt_color 15
vt_print_center(17, chr(1) &chr(32) & chr(2) & VT_NEWLINE)

vt_sleep

vt_font_reset
vt_print_center(19, "Internal font restored."& VT_NEWLINE)
vt_print_center(20, "- Any key to quit -"& VT_NEWLINE)

vt_sleep

vt_shutdown
