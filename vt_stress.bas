' =============================================================================
' vt_stress.bas  -  VT render speed test + ESC key detection test
'
' Two things under test:
'
'   1. SPEED
'      Fill all 2000 cells via vt_set_cell (no auto-presents triggered).
'      Time the loop, then time exactly one vt_present() call.
'      Results are printed on screen so you can see real ms numbers.
'      Expected with GPU renderer: set_cell loop < 1 ms, present < 5 ms.
'      If present is > 50 ms the SDL renderer is probably falling back
'      to software mode (check the "renderer:" line in the output).
'
'   2. ESC detection  (the "it never exits" bug explained)
'      WRONG:  If k = VT_KEY_ESC          <- compares 65536 to 1, always false
'      RIGHT:  If VT_SCAN(k) = VT_KEY_ESC <- extracts bits 16-27, gives 1
'
'      VT_KEY_ESC = 1 is a *scancode*, not the full key record.
'      The full key record packs scancode into bits 16-27:
'        ESC keydown -> keyrec = (VT_KEY_ESC Shl 16) = 65536
'      VT_SCAN() shifts back down, so VT_SCAN(65536) = 1 = VT_KEY_ESC. OK.
'      The "any key" check on the first screen used (k <> 0) which is fine
'      because 65536 <> 0, so ESC happened to pass that test.
'
' Compile:  fbc vt_stress.bas
' =============================================================================

#include once "vt/vt.bi"

' --- locals ---
Dim k          As ULong
Dim r          As Long
Dim c          As Long
Dim fg_clr     As Long
Dim bg_clr     As Long
Dim t1         As Double
Dim t2         As Double
Dim t_fill_ms  As Long   ' vt_set_cell loop time in ms
Dim t_pres_ms  As Long   ' one vt_present() time in ms

' -------------------------------------------------------------------------
' Init
' -------------------------------------------------------------------------
vt_init(VT_MODE_80x25)

' -------------------------------------------------------------------------
' Phase 1 - fill all 2000 cells via vt_set_cell
' vt_set_cell only sets dirty=1, it does NOT call vt_present.
' So this loop triggers zero screen redraws - pure cell buffer writes.
' -------------------------------------------------------------------------
t1 = Timer

For r = 1 To 25
    For c = 1 To 80
        fg_clr = (c Mod 15) + 1            ' colours 1-15 cycling across each row
        bg_clr = r Mod 8                    ' colours 0-7 cycling down each column
        vt_set_cell(c, r, _
            65 + ((r + c) Mod 26), _        ' A-Z cycling
            fg_clr, _
            bg_clr)
    Next c
Next r

t2 = Timer
t_fill_ms = CLng((t2 - t1) * 1000.0)

' -------------------------------------------------------------------------
' Phase 2 - time exactly ONE vt_present call
' This renders the filled buffer to the SDL window.
' -------------------------------------------------------------------------
t1 = Timer
vt_present()
t2 = Timer
t_pres_ms = CLng((t2 - t1) * 1000.0)

' brief pause so the filled screen is visible before we overlay the results
Sleep 800, 1 

' -------------------------------------------------------------------------
' Phase 3 - overlay results on the colourful fill
' Note: each vt_print here also calls vt_present internally.
' That is fine for a small number of status lines - it only matters in loops.
' -------------------------------------------------------------------------
Dim renderer_name As String = "unknown"

' SDL_GetRendererInfo is accessible because vt.bi pulls in SDL2/SDL.bi
Dim rinfo As SDL_RendererInfo
If SDL_GetRendererInfo(vt_internal.sdl_renderer, @rinfo) = 0 Then
    renderer_name = *rinfo.name
End If

vt_color(VT_WHITE, VT_BLUE)

vt_locate(9,  22) : vt_print(" =============================== ")
vt_locate(10, 22) : vt_print("   VT stress test results        ")
vt_locate(11, 22) : vt_print(" =============================== ")
vt_locate(12, 22) : vt_print("  renderer : " & Left(renderer_name, 18) & Space(18 - Len(renderer_name)) & " ")
vt_locate(13, 22) : vt_print("  set_cell x2000  : " & Str(t_fill_ms) & " ms          ")
vt_locate(14, 22) : vt_print("  vt_present x1   : " & Str(t_pres_ms) & " ms          ")
vt_locate(15, 22) : vt_print(" =============================== ")
vt_locate(16, 22) : vt_print("  Press ESC to quit              ")
vt_locate(17, 22) : vt_print(" =============================== ")

' -------------------------------------------------------------------------
' Phase 4 - wait for ESC
' CORRECT comparison: VT_SCAN(k) = VT_KEY_ESC
' k is a ULong with scancode in bits 16-27.  VT_SCAN() extracts those bits.
' -------------------------------------------------------------------------
Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do   ' correct
    If vt_should_quit() Then Exit Do
    Sleep 10
Loop

vt_shutdown()
