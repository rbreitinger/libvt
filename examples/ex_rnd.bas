#include "../vt/vt.bi"

Dim as Long idx, n

Randomize

vt_screen

for idx = 0 to 9
  
  '' picks a random number between -10 and 10
  n = vt_rnd(-10, 10)
  
  vt_locate 1+idx, 3
    
  vt_print "Number " & idx & " : " & n
next idx

vt_sleep
vt_shutdown
