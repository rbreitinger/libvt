#include once "../vt/vt.bi"

'' custom palette entries (by by Arne Niklas Jansson)
'' https://androidarts.com/palette/16pal.htm
static arne_v20_palette(47) As UByte = { _
  0, 0, 0, _
  157, 157, 157, _
  255, 255, 255, _
  190, 38, 51, _
  224, 111, 139, _
  73, 60, 43, _
  164, 100, 34, _
  235, 137, 49, _
  247, 226, 107, _
  47, 72, 78, _
  68, 137, 26, _
  163, 206, 39, _
  27, 38, 50, _
  0, 87, 132, _
  49, 162, 242, _
  178, 220, 239 _
}

vt_title "vt_palette_set Example"
vt_screen VT_SCREEN_TILES

'' load custom palette
vt_palette_set arne_v20_palette()

'' print some text using the custom palette
for col as long = 0 to 15
    vt_locate 3 + col , 14
    vt_color col
    vt_print chr(219) & " Hello Arne! " & chr(219)
next

vt_print_center 21 , " any key to restore default palette "

vt_sleep

vt_palette '' vt_palette without arguments restores the default palette

vt_print_center 23 , " any key to end the demo "

vt_sleep
vt_shutdown
