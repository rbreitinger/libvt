' =============================================================================
' VT render speed test 
' =============================================================================
#include once "../vt/vt.bi"

Dim k          As ULong
Dim fg_clr     As Long
Dim bg_clr     As Long
Dim t1         As Double
Dim t2         As Double
Dim t_fill_ms  As Long   ' vt_set_cell loop time in ms
Dim t_pres_ms  As Long   ' one vt_present() time in ms

vt_screen 

' -------------------------------------------------------------------------
' fill all 2000 cells via vt_set_cell
' vt_set_cell only sets dirty=1, it does NOT call vt_present.
' So this loop triggers zero screen redraws - pure cell buffer writes.
' -------------------------------------------------------------------------
t1 = Timer

For r As Long = 1 To 25
    For c As Long = 1 To 80
        fg_clr = (c Mod 15) + 1            ' colours 1-15 cycling across each row
        bg_clr = r Mod 8                   ' colours 0-7 cycling down each column
        vt_set_cell c, r, _
            65 + ((r + c) Mod 26), _       ' A-Z cycling
            fg_clr, _
            bg_clr
    Next c
Next r

t2 = Timer
t_fill_ms = CLng((t2 - t1) * 1000.0)

' -------------------------------------------------------------------------
' time exactly ONE vt_present() call
' This renders the filled buffer to the screen.
' -------------------------------------------------------------------------
t1 = Timer
vt_present
t2 = Timer
t_pres_ms = CLng((t2 - t1) * 1000.0)

' -------------------------------------------------------------------------
' overlay results 
' -------------------------------------------------------------------------
Dim renderer_name As String = "unknown"

' SDL_GetRendererInfo is accessible because vt.bi pulls in SDL2/SDL.bi
Dim rinfo As SDL_RendererInfo
If SDL_GetRendererInfo(vt_internal.sdl_renderer, @rinfo) = 0 Then
    renderer_name = *rinfo.name
End If

vt_color VT_WHITE, VT_BLUE

vt_locate 9,  22  : vt_print " =============================== " 
vt_locate 10, 22  : vt_print "   VT stress test results        " 
vt_locate 11, 22  : vt_print " =============================== " 
vt_locate 12, 22  : vt_print "  renderer : " & Left(renderer_name, 19) & Space(19 - Len(renderer_name)) & " " 
vt_locate 13, 22  : vt_print "  set_cell x2000  : " & Str(t_fill_ms) & " ms         " 
vt_locate 14, 22  : vt_print "  vt_present x1   : " & Str(t_pres_ms) & " ms         " 
vt_locate 15, 22  : vt_print " =============================== " 
vt_locate , , 0

vt_sleep
vt_shutdown
