#include once "vt/vt.bi"

vt_init  VT_MODE_40x25,,VT_NO_RESIZE
vt_color VT_YELLOW

windowtitle "Hello World Test" '' <-- not working, need own

do
  for i as long = 5 to 19
    vt_color i-4, 15
    vt_locate i, 15, 0
    vt_print (string (8, chr(176) ) )
  next
  vt_present
  
  vt_pump
  if vt_should_quit then exit do
  vt_sleep 10
loop

vt_shutdown
