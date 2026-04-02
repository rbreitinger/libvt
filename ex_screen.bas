#include once "vt/vt.bi"

dim as long mode_idx, mode
dim as string modename
vt_title  "Screen Modes Demo"       ' set window title


for mode_idx = 0 to 15
  
  select case mode_idx
    case 0:  mode = VT_SCREEN_0      : modename = "VT_SCREEN_0"
    case 2:  mode = VT_SCREEN_2      : modename = "VT_SCREEN_2"
    case 4:  mode = VT_SCREEN_9      : modename = "VT_SCREEN_9"
    case 6:  mode = VT_SCREEN_12     : modename = "VT_SCREEN_12"
    case 8:  mode = VT_SCREEN_13     : modename = "VT_SCREEN_13"
    case 10: mode = VT_SCREEN_EGA43  : modename = "VT_SCREEN_EGA43"
    case 12: mode = VT_SCREEN_VGA50  : modename = "VT_SCREEN_VGA50"
    case 14: mode = VT_SCREEN_TILES  : modename = "VT_SCREEN_TILES"
  end select
  
  ' set video mode
  vt_screen   mode, iif( mode_idx and 1, VT_WINDOWED, VT_FULLSCREEN_ASPECT )
  
  vt_color    VT_YELLOW, VT_BLUE             ' set yellow font on blue background
  vt_cls                                     ' clears the screen to blue because we set blue as background before
  vt_locate   , , , 95                       ' set cursor symbol to underscore _
  
  vt_print_center 10, "vt_screen " & mode _  ' print text in row 10 centered
                    & " [" & modename & "]"
                      
  vt_print_center 12, iif( mode_idx and 1, _
      "VT_WINDOWED", "VT_FULLSCREEN_ASPECT" )
  
  vt_sleep                                   ' waits until a key is pressed, vt_sleep already calls vt_present
next 