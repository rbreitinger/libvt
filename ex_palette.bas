#include once "vt/vt.bi"

''  custom palette entries
Dim arne_v20_palette(47) As UByte = { _
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

dim idx as long
dim col as long

vt_init VT_MODE_40x25

'' set our custom palette, index 0-15, each holding R, G, B = 48 entries
for idx = 0 to 47 step 3
  vt_palette idx, arne_v20_palette(idx), arne_v20_palette(idx+1), arne_v20_palette(idx+2)
next

'' print some text using the custom palette
for col = 0 to 15
    vt_locate 3+col, 14
    vt_color col
    vt_print chr(219) & " Hello Arne! " & chr(219)
next

vt_print_center 21, " any key to quit "

vt_sleep

vt_shutdown
