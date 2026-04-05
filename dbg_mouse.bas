#include "vt/vt.bi"

vt_screen

do
    static as byte mouseOn = 0
    dim k as ulong
    k = vt_inkey
    
    if VT_SCAN(k) = VT_KEY_ENTER then
      mouseOn xor = 1
      
      if mouseOn = 1 then
        vt_mouse(1)
      else
        vt_mouse(0)
      end if
      
    end if
    
    if VT_SCAN(k) = VT_KEY_ESC then exit do
      
loop


