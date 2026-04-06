' must be defined so sound is available, BEFORE including the header
#Define VT_USE_SOUND

#Include Once "../vt/vt.bi"

Dim i As Long 
Static wavename(3) As ZString * 17 = { "VT_WAVE_SQUARE", "VT_WAVE_TRIANGLE", "VT_WAVE_SINE", "VT_WAVE_NOISE" }

vt_Title "vt_sound Demo"
vt_Screen

For i = 0 To 3
  vt_Sound 262, 250,  i, VT_SOUND_BACKGROUND
  vt_Sound 330, 250,  i, VT_SOUND_BACKGROUND
  vt_Sound 392, 250,  i, VT_SOUND_BACKGROUND
  vt_Sound 510, 1250, i, VT_SOUND_BACKGROUND

  vt_Color i+9
  vt_Print_Center 10+i, "Sound Playback Using " & wavename(i) & "  "
  
  vt_Sound_Wait() ' sync here when melody is done
  vt_Sleep(500)
Next i

vt_Cls
vt_Color VT_BRIGHT_BLUE
vt_Locate ,,0
For i = 20 To 450 Step 8
  vt_Print_Center 12, String( i/10, 254)
  vt_Sound i, 24, VT_WAVE_TRIANGLE, VT_SOUND_BLOCKING
Next i

vt_Color VT_WHITE
vt_Print_Center 15, " - any key to quit - "

vt_Key_Flush
vt_Sleep

vt_Shutdown
