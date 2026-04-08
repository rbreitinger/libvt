'' =============================================================================
''  vtetris-bake.bas  --  Asset baker for VTetris
''
''  Run this once after building to generate the screen assets.
''  The main game (vtetris.bas) expects these files to exist:
''
''      resources/vtetris-title.vts   title screen
''      resources/vtetris-game.vts    empty game background
''
''  Re-run whenever the layout or colours in vtetris.bas change.
'' =============================================================================
#define VT_USE_MATH
#include once "../vt/vt.bi"

#define fbDirectory &h10   '' Dir() flag for directory check -- not auto-defined in FB

'' --- layout constants (must match vtetris.bas) --------------------------------
Const BOARD_W   = 10
Const BOARD_H   = 20
Const BOARD_COL = 31
Const BOARD_ROW = 3
Const PANEL_COL = 54

'' --- shared state needed by drawing subs -------------------------------------
Dim Shared board(BOARD_W - 1, BOARD_H - 1) As UByte   '' all zero = empty board
Dim Shared pc_col(6) As UByte

'' panel values baked at their initial state
Dim Shared score     As Long
Dim Shared lvl       As Long
Dim Shared tot_lines As Long

'' --- piece colours (must match vtetris.bas) -----------------------------------
pc_col(0) = VT_BRIGHT_CYAN    '' I
pc_col(1) = VT_BRIGHT_BLUE    '' J
pc_col(2) = VT_BROWN          '' L
pc_col(3) = VT_YELLOW         '' O
pc_col(4) = VT_BRIGHT_GREEN   '' S
pc_col(5) = VT_BRIGHT_MAGENTA '' T
pc_col(6) = VT_BRIGHT_RED     '' Z

'' --- drawing subs ------------------------------------------------------------
'' (geometry and colour must stay in sync with vtetris.bas)

Sub put_cell(bx As Long, by As Long, bval As UByte)
    If by < 0 OrElse by >= BOARD_H Then Exit Sub
    If bx < 0 OrElse bx >= BOARD_W Then Exit Sub
    Dim sc As Long = BOARD_COL + bx * 2
    Dim sr As Long = BOARD_ROW + by
    If bval = 0 Then
        vt_set_cell sc,     sr, 32, VT_BLACK, VT_BLACK
        vt_set_cell sc + 1, sr, 32, VT_BLACK, VT_BLACK
    Else
        Dim clr As UByte = pc_col(bval - 1)
        vt_set_cell sc,     sr, 32, VT_WHITE, clr
        vt_set_cell sc + 1, sr, 32, VT_WHITE, clr
    End If
End Sub

Sub draw_border()
    Dim c As Long, r As Long
    Dim lft As Long = BOARD_COL - 1
    Dim rgt As Long = BOARD_COL + BOARD_W * 2
    Dim top As Long = BOARD_ROW - 1
    Dim bot As Long = BOARD_ROW + BOARD_H
    vt_set_cell lft, top, 201, VT_WHITE, VT_BLACK
    vt_set_cell rgt, top, 187, VT_WHITE, VT_BLACK
    For c = lft + 1 To rgt - 1
        vt_set_cell c, top, 205, VT_WHITE, VT_BLACK
    Next c
    For r = BOARD_ROW To BOARD_ROW + BOARD_H - 1
        vt_set_cell lft, r, 186, VT_WHITE, VT_BLACK
        vt_set_cell rgt, r, 186, VT_WHITE, VT_BLACK
    Next r
    vt_set_cell lft, bot, 200, VT_WHITE, VT_BLACK
    vt_set_cell rgt, bot, 188, VT_WHITE, VT_BLACK
    For c = lft + 1 To rgt - 1
        vt_set_cell c, bot, 205, VT_WHITE, VT_BLACK
    Next c
End Sub

Sub draw_board()
    Dim bx As Long, by As Long
    For by = 0 To BOARD_H - 1
        For bx = 0 To BOARD_W - 1
            put_cell bx, by, board(bx, by)
        Next bx
    Next by
End Sub

Sub draw_panel_static()
    Dim pc As Long = PANEL_COL
    vt_color VT_LIGHT_GREY, VT_BLACK
    vt_locate BOARD_ROW,      pc : vt_print "NEXT"
    vt_locate BOARD_ROW + 6,  pc : vt_print "SCORE"
    vt_locate BOARD_ROW + 9,  pc : vt_print "LEVEL"
    vt_locate BOARD_ROW + 11, pc : vt_print "LINES"
    vt_color VT_DARK_GREY, VT_BLACK
    vt_locate BOARD_ROW + 13, pc : vt_print String(22, Chr(196))
    vt_locate BOARD_ROW + 14, pc : vt_print "CONTROLS"
    vt_locate BOARD_ROW + 15, pc : vt_print Chr(27) & Chr(26) & "   Move"
    vt_locate BOARD_ROW + 16, pc : vt_print Chr(24) & " X  Rotate CW / CCW"
    vt_locate BOARD_ROW + 17, pc : vt_print Chr(25) & "    Soft drop"
    vt_locate BOARD_ROW + 18, pc : vt_print "SPC  Hard drop"
    vt_locate BOARD_ROW + 19, pc : vt_print "P    Pause"
    vt_locate BOARD_ROW + 20, pc : vt_print "ESC  Quit"
End Sub

Sub update_panel()
    Dim pc As Long = PANEL_COL
    vt_color VT_YELLOW,       VT_BLACK
    vt_locate BOARD_ROW + 7,  pc : vt_print Space(7 - vt_digits(score))     & score
    vt_color VT_BRIGHT_CYAN,  VT_BLACK
    vt_locate BOARD_ROW + 10, pc : vt_print Space(3 - vt_digits(lvl))       & lvl
    vt_color VT_BRIGHT_GREEN, VT_BLACK
    vt_locate BOARD_ROW + 12, pc : vt_print Space(4 - vt_digits(tot_lines)) & tot_lines
End Sub

'' =============================================================================
''  Bake
'' =============================================================================

vt_title "VTetris -- Asset Baker"
vt_screen VT_SCREEN_0, VT_WINDOWED Or VT_NO_RESIZE, 2
vt_locate , , 0   '' hide cursor

'' Ensure output directory exists
If Dir("resources", fbDirectory) = "" Then MkDir "resources"

'' --- Bake title screen -------------------------------------------------------
vt_page 1, VT_VIDEO
vt_scroll_enable 0
vt_color VT_BLACK, VT_BLACK
vt_cls

Dim i As Long

'' Colored block strips at top and bottom
For i = 1 To 80
    vt_set_cell i, 1,  219, pc_col((i - 1) Mod 7), VT_BLACK
    vt_set_cell i, 25, 219, pc_col((i + 3) Mod 7), VT_BLACK
Next i

'' Title box
vt_color VT_WHITE, VT_BLACK
vt_locate 4, 28 : vt_print Chr(201) & String(24, Chr(205)) & Chr(187)
vt_locate 5, 28 : vt_print Chr(186) & Space(24)             & Chr(186)
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 6, 28 : vt_print Chr(186) & "   V  T  e  t  r  i  s  " & Chr(186)
vt_color VT_WHITE, VT_BLACK
vt_locate 7, 28 : vt_print Chr(186) & Space(24)             & Chr(186)
vt_locate 8, 28 : vt_print Chr(200) & String(24, Chr(205)) & Chr(188)

vt_color VT_DARK_GREY, VT_BLACK
vt_print_center 10, "A Tetris showcase for the libvt FreeBASIC library"

'' Controls
vt_color VT_LIGHT_GREY, VT_BLACK
vt_print_center 12, "Controls"
vt_color VT_DARK_GREY, VT_BLACK
vt_locate 13, 27 : vt_print Chr(27) & Chr(26) & "      Move left / right"
vt_locate 14, 27 : vt_print Chr(24) & " X     Rotate CW / CCW"
vt_locate 15, 27 : vt_print Chr(25) & "       Soft drop   (+"  & Chr(49) & " pt/row)"
vt_locate 16, 27 : vt_print "SPACE   Hard drop   (+2 pts/row)"
vt_locate 17, 27 : vt_print "P       Pause / Resume"
vt_locate 18, 27 : vt_print "ESC     Quit"

'' Piece color swatch
For i = 0 To 6
    Dim sc As Long = 27 + i * 4
    vt_set_cell sc,     21, 32, VT_WHITE, pc_col(i)
    vt_set_cell sc + 1, 21, 32, VT_WHITE, pc_col(i)
Next i

vt_color VT_WHITE, VT_BLACK
vt_print_center 23, Chr(16) & "  Press any key to play  " & Chr(17)

vt_bsave "resources/vtetris-title.vts"

'' --- Bake game background ----------------------------------------------------
score = 0 : lvl = 1 : tot_lines = 0

vt_color VT_BLACK, VT_BLACK
vt_cls
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_print_center 1, " V T e t r i s "
draw_border()
draw_board()
draw_panel_static()
update_panel()

vt_bsave "resources/vtetris-game.vts"

'' --- Result screen -----------------------------------------------------------
vt_color VT_BLACK, VT_BLACK
vt_cls
vt_color VT_BRIGHT_GREEN, VT_BLACK
vt_print_center  9, "Assets baked successfully."
vt_color VT_LIGHT_GREY, VT_BLACK
vt_print_center 11, "resources/vtetris-title.vts"
vt_print_center 12, "resources/vtetris-game.vts"
vt_color VT_DARK_GREY, VT_BLACK
vt_print_center 15, "Press any key to exit."

vt_pcopy 1, VT_VIDEO
vt_present()
vt_sleep 0
vt_shutdown()
