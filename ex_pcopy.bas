' =============================================================================
' ex_pcopy.bas -- double-buffer page flip demo
'
' Demonstrates:
'   vt_screen(..., 2)       open with 2 pages (VT_VIDEO + 1 work page)
'   vt_page(1, 0)           all drawing targets page 1, display stays page 0
'   vt_pcopy(1, VT_VIDEO)   blit the finished frame to the display page
'   vt_present()            flip to screen
'
' The display page (VT_VIDEO = 0) never sees a half-drawn frame.
' vt_pcopy delivers a complete image in one memcpy, then vt_present shows it.
' =============================================================================

#include once "vt/vt.bi"

' -----------------------------------------------------------------------------
' ball type
' -----------------------------------------------------------------------------
Const NUM_BALLS = 14

Type t_ball
    xp  As Single   ' column position (float for smooth sub-cell movement)
    yp  As Single   ' row position
    vx  As Single   ' horizontal velocity (cols per frame)
    vy  As Single   ' vertical velocity   (rows per frame)
    gly As UByte    ' CP437 glyph
    clr As UByte    ' foreground colour index
End Type

' -----------------------------------------------------------------------------
' main
' -----------------------------------------------------------------------------
Dim b(NUM_BALLS - 1) As t_ball
Dim scr_cols  As Long
Dim scr_rows  As Long
Dim idx       As Long
Dim cc        As Long
Dim rr        As Long
Dim k         As ULong
Dim frame_num As Long

' open with 2 pages: page 0 = VT_VIDEO (display), page 1 = work
vt_title "ex_pcopy -- double-buffer"
vt_screen VT_SCREEN_0, VT_WINDOWED, 2

scr_cols = vt_cols()
scr_rows = vt_rows()

' seed balls
Randomize

Dim glyphs(7) As UByte = {1, 2, 3, 4, 6, 15, 42, 254}

For idx = 0 To NUM_BALLS - 1
    b(idx).xp  = 3 + Rnd * (scr_cols - 4)
    b(idx).yp  = 3 + Rnd * (scr_rows - 4)
    b(idx).vx  = (0.5 + Rnd * 1.0) * IIf(Rnd > 0.5, 1.0, -1.0)
    b(idx).vy  = (0.2 + Rnd * 0.6) * IIf(Rnd > 0.5, 1.0, -1.0)
    b(idx).gly = glyphs(idx Mod 8)
    b(idx).clr = 9 + (idx Mod 7)   ' bright colours 9..15
Next idx

' --- double-buffer setup (called once, before the loop) ---
' From this point all drawing commands write to page 1.
' vt_present always shows page 0.
vt_page(1, VT_VIDEO)

' =========================================================================
' main loop
' =========================================================================
Do
    ' --- update ---
    For idx = 0 To NUM_BALLS - 1
        b(idx).xp += b(idx).vx
        b(idx).yp += b(idx).vy
        ' bounce off the inner border walls
        If b(idx).xp < 2              Then b(idx).xp = 2              : b(idx).vx = -b(idx).vx
        If b(idx).xp > scr_cols - 1   Then b(idx).xp = scr_cols - 1  : b(idx).vx = -b(idx).vx
        If b(idx).yp < 2              Then b(idx).yp = 2              : b(idx).vy = -b(idx).vy
        If b(idx).yp > scr_rows - 2   Then b(idx).yp = scr_rows - 2  : b(idx).vy = -b(idx).vy
    Next idx

    ' -----------------------------------------------------------------------
    ' draw -- everything goes to page 1 (the work page)
    ' -----------------------------------------------------------------------
    vt_color(VT_BLACK, VT_BLACK)
    vt_cls()

    ' double-line border (CP437 box-drawing glyphs)
    vt_set_cell(1,        1,        201, VT_DARK_GREY, VT_BLACK)   ' top-left
    vt_set_cell(scr_cols, 1,        187, VT_DARK_GREY, VT_BLACK)   ' top-right
    vt_set_cell(1,        scr_rows, 200, VT_DARK_GREY, VT_BLACK)   ' bot-left
    vt_set_cell(scr_cols, scr_rows, 188, VT_DARK_GREY, VT_BLACK)   ' bot-right
    For cc = 2 To scr_cols - 1
        vt_set_cell(cc, 1,        205, VT_DARK_GREY, VT_BLACK)
        vt_set_cell(cc, scr_rows, 205, VT_DARK_GREY, VT_BLACK)
    Next cc
    For rr = 2 To scr_rows - 1
        vt_set_cell(1,        rr, 186, VT_DARK_GREY, VT_BLACK)
        vt_set_cell(scr_cols, rr, 186, VT_DARK_GREY, VT_BLACK)
    Next rr

    ' title inset into top border
    vt_locate(1, 3)
    vt_color(VT_WHITE, VT_BLACK)
    vt_print(" ex_pcopy -- vt_page(1,VT_VIDEO) + vt_pcopy(1,VT_VIDEO) ")

    ' balls
    For idx = 0 To NUM_BALLS - 1
        vt_set_cell(CLng(b(idx).xp), CLng(b(idx).yp), b(idx).gly, b(idx).clr, VT_BLACK)
    Next idx

    ' status line inside bottom border
    vt_color(VT_DARK_GREY, VT_BLACK)
    vt_locate(scr_rows - 1, 3)
    vt_print("frame " & Str(frame_num) & "   ESC = quit")

    ' -----------------------------------------------------------------------
    ' flip -- three lines, always in this order
    ' -----------------------------------------------------------------------
    vt_pcopy(1, VT_VIDEO)   ' copy finished work page -> display page
    vt_present()             ' show the display page on screen

    frame_num += 1

    ' --- input ---
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do

    vt_sleep(16)   ' ~60 fps cap
Loop
