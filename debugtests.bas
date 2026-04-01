#include once "vt/vt.bi"

vt_init
vt_color VT_YELLOW

vt_scroll_enable 1
'vt_locate ,,0
do
  vt_color int(rnd*14)+1
  vt_print (string (8, chr(176) ) ) & VT_NEWLINE
  
  vt_pump
  if vt_should_quit then exit do
  vt_sleep 1
  var k = vt_inkey
  if k then vt_sleep():vt_key_flush
loop

vt_shutdown
