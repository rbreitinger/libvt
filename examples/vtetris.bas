'' =============================================================================
''  vtetris.bas  —  VTetris: Tetris demo for the libvt text screen library
''
''  Controls:  Left / Right   move          Up     rotate CW
''             X              rotate CCW    Down   soft drop  (+1 pt/row)
''             Space          hard drop     (+2 pts/row)
''             P              pause         Esc    quit
'' =============================================================================
#define VT_USE_SOUND
#include once "../vt/vt.bi"

'' --- layout constants --------------------------------------------------------
Const BOARD_W   = 10    '' cells wide
Const BOARD_H   = 20    '' cells tall
'' each cell = 2 chars wide; board origin at (BOARD_COL, BOARD_ROW), 1-based
Const BOARD_COL = 31
Const BOARD_ROW = 3
Const PANEL_COL = 54    '' right info panel start col

Const PC_I = 0 : Const PC_J = 1 : Const PC_L = 2 : Const PC_O = 3
Const PC_S = 4 : Const PC_T = 5 : Const PC_Z = 6

'' --- shared state ------------------------------------------------------------
'' board: 0 = empty, 1-7 = locked piece type + 1
Dim Shared board(BOARD_W - 1, BOARD_H - 1) As UByte

'' shape strings: 16-char 4x4 grid, row-major, 'X'=filled '.'=empty
Static Shared pstr(6, 3) As String * 16

'' VT color index per piece type 0-6
Dim Shared pc_col(6) As UByte

'' scratch cell-offset buffers filled by get_cells()
Dim Shared cell_cx(3) As Long
Dim Shared cell_cy(3) As Long

'' 7-bag randomizer
Dim Shared bag(6)  As Long
Dim Shared bag_pos As Long

'' current falling piece
Dim Shared cur_pc  As Long   '' piece type 0-6
Dim Shared cur_rot As Long   '' rotation 0-3
Dim Shared cur_bx  As Long   '' board x of 4x4 box top-left (0-based)
Dim Shared cur_by  As Long   '' board y of 4x4 box top-left (0-based)
Dim Shared nxt_pc  As Long

'' game stats / flags
Dim Shared score     As Long
Dim Shared lvl       As Long
Dim Shared tot_lines As Long
Dim Shared is_over   As Byte
Dim Shared want_quit As Byte

'' --- piece setup -------------------------------------------------------------
Sub init_pieces()
    pc_col(PC_I) = VT_BRIGHT_CYAN  : pc_col(PC_J) = VT_BRIGHT_BLUE
    pc_col(PC_L) = VT_BROWN        : pc_col(PC_O) = VT_YELLOW
    pc_col(PC_S) = VT_BRIGHT_GREEN : pc_col(PC_T) = VT_BRIGHT_MAGENTA
    pc_col(PC_Z) = VT_BRIGHT_RED

    '' I — 4 unique rotations
    pstr(0,0) = "....XXXX........" : pstr(0,1) = "..X...X...X...X."
    pstr(0,2) = "........XXXX...." : pstr(0,3) = ".X...X...X...X.."
    '' J
    pstr(1,0) = "X...XXX........." : pstr(1,1) = "XX..X...X......."
    pstr(1,2) = "....XXX...X....." : pstr(1,3) = ".X...X..XX......"
    '' L
    pstr(2,0) = "..X.XXX........." : pstr(2,1) = "X...X...XX......"
    pstr(2,2) = "....XXX.X......." : pstr(2,3) = "XX...X...X......"
    '' O — all rotations identical
    pstr(3,0) = ".XX..XX........." : pstr(3,1) = ".XX..XX........."
    pstr(3,2) = ".XX..XX........." : pstr(3,3) = ".XX..XX........."
    '' S — 2-state
    pstr(4,0) = ".XX.XX.........." : pstr(4,1) = "X...XX...X......"
    pstr(4,2) = ".XX.XX.........." : pstr(4,3) = "X...XX...X......"
    '' T
    pstr(5,0) = ".X..XXX........." : pstr(5,1) = "X...XX..X......."
    pstr(5,2) = "....XXX..X......" : pstr(5,3) = ".X..XX...X......"
    '' Z — 2-state
    pstr(6,0) = "XX...XX........." : pstr(6,1) = ".X..XX..X......."
    pstr(6,2) = "XX...XX........." : pstr(6,3) = ".X..XX..X......."
End Sub

'' --- 7-bag randomizer --------------------------------------------------------
Sub shuffle_bag()
    Dim i As Long, j As Long, tmp As Long
    For i = 0 To 6 : bag(i) = i : Next i
    For i = 6 To 1 Step -1
        j   = Int(Rnd * (i + 1))
        tmp = bag(i) : bag(i) = bag(j) : bag(j) = tmp
    Next i
    bag_pos = 0
End Sub

Function draw_bag() As Long
    If bag_pos >= 7 Then shuffle_bag()
    Dim pc As Long = bag(bag_pos)
    bag_pos += 1
    Return pc
End Function

'' --- cell helpers ------------------------------------------------------------
'' Scan pstr(pc, rot) and fill cell_cx / cell_cy with the 4 cell offsets
Sub get_cells(pc As Long, rot As Long)
    Dim s   As String = pstr(pc, rot)
    Dim idx As Long = 0
    Dim i   As Long
    For i = 0 To 15
        If Mid(s, i + 1, 1) = "X" Then
            cell_cx(idx) = i Mod 4
            cell_cy(idx) = i \ 4
            idx += 1
            If idx = 4 Then Exit For
        End If
    Next i
End Sub

'' Returns 1 if piece can occupy (bx, by) without collision
Function piece_ok(pc As Long, rot As Long, bx As Long, by As Long) As Byte
    get_cells pc, rot
    Dim i As Long
    For i = 0 To 3
        Dim cx As Long = bx + cell_cx(i)
        Dim cy As Long = by + cell_cy(i)
        If cx < 0 OrElse cx >= BOARD_W Then Return 0
        If cy >= BOARD_H              Then Return 0
        If cy >= 0 AndAlso board(cx, cy) <> 0 Then Return 0
    Next i
    Return 1
End Function

'' --- rendering ---------------------------------------------------------------
'' Draw one board cell. bval: 0=empty, 1-7=piece+1
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

'' Ghost cell drawn as "[]" outline in piece color
Sub put_ghost(bx As Long, by As Long, pc As Long)
    If by < 0 OrElse by >= BOARD_H Then Exit Sub
    If bx < 0 OrElse bx >= BOARD_W Then Exit Sub
    If board(bx, by) <> 0          Then Exit Sub
    Dim sc As Long = BOARD_COL + bx * 2
    Dim sr As Long = BOARD_ROW + by
    vt_set_cell sc,     sr, Asc("["), pc_col(pc), VT_BLACK
    vt_set_cell sc + 1, sr, Asc("]"), pc_col(pc), VT_BLACK
End Sub

'' Redraw entire locked board
Sub draw_board()
    Dim bx As Long, by As Long
    For by = 0 To BOARD_H - 1
        For bx = 0 To BOARD_W - 1
            put_cell bx, by, board(bx, by)
        Next bx
    Next by
End Sub

'' Draw (erase=0) or erase (erase=1) the current falling piece
Sub draw_cur(er As Byte)
    get_cells cur_pc, cur_rot
    Dim i As Long
    For i = 0 To 3
        If er Then
            put_cell cur_bx + cell_cx(i), cur_by + cell_cy(i), 0
        Else
            put_cell cur_bx + cell_cx(i), cur_by + cell_cy(i), cur_pc + 1
        End If
    Next i
End Sub

'' Return the lowest board-y the current piece can reach
Function ghost_row() As Long
    Dim gy As Long = cur_by
    Do While piece_ok(cur_pc, cur_rot, cur_bx, gy + 1)
        gy += 1
    Loop
    Return gy
End Function

'' Draw ghost piece at board-y = gy
Sub draw_ghost(gy As Long)
    If gy <= cur_by Then Exit Sub
    get_cells cur_pc, cur_rot
    Dim i As Long
    For i = 0 To 3
        put_ghost cur_bx + cell_cx(i), gy + cell_cy(i), cur_pc
    Next i
End Sub

'' --- border and panel --------------------------------------------------------
Sub draw_border()
    Dim c As Long, r As Long
    Dim lft As Long = BOARD_COL - 1
    Dim rgt As Long = BOARD_COL + BOARD_W * 2
    Dim top As Long = BOARD_ROW - 1
    Dim bot As Long = BOARD_ROW + BOARD_H

    '' Top  +---+
    vt_set_cell lft, top, 201, VT_WHITE, VT_BLACK
    vt_set_cell rgt, top, 187, VT_WHITE, VT_BLACK
    For c = lft + 1 To rgt - 1
        vt_set_cell c, top, 205, VT_WHITE, VT_BLACK
    Next c
    '' Sides  ¦
    For r = BOARD_ROW To BOARD_ROW + BOARD_H - 1
        vt_set_cell lft, r, 186, VT_WHITE, VT_BLACK
        vt_set_cell rgt, r, 186, VT_WHITE, VT_BLACK
    Next r
    '' Bottom  +---+
    vt_set_cell lft, bot, 200, VT_WHITE, VT_BLACK
    vt_set_cell rgt, bot, 188, VT_WHITE, VT_BLACK
    For c = lft + 1 To rgt - 1
        vt_set_cell c, bot, 205, VT_WHITE, VT_BLACK
    Next c
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
    vt_locate BOARD_ROW + 7,  pc : vt_print Right("       " & score,     7)
    vt_color VT_BRIGHT_CYAN,  VT_BLACK
    vt_locate BOARD_ROW + 10, pc : vt_print Right("  "      & lvl,       3)
    vt_color VT_BRIGHT_GREEN, VT_BLACK
    vt_locate BOARD_ROW + 12, pc : vt_print Right("    "    & tot_lines, 4)
End Sub

'' Redraw 4x4 NEXT preview area and show nxt_pc at rotation 0
Sub draw_next_piece()
    Dim pc As Long = PANEL_COL
    Dim r As Long, c As Long
    '' Clear preview area (8 chars wide x 4 rows)
    For r = 0 To 3
        For c = 0 To 7
            vt_set_cell pc + c, BOARD_ROW + 1 + r, 32, VT_BLACK, VT_BLACK
        Next c
    Next r
    '' Draw piece
    get_cells nxt_pc, 0
    Dim clr As UByte = pc_col(nxt_pc)
    Dim i   As Long
    For i = 0 To 3
        Dim sc As Long = pc + cell_cx(i) * 2
        Dim sr As Long = BOARD_ROW + 1 + cell_cy(i)
        vt_set_cell sc,     sr, 32, VT_WHITE, clr
        vt_set_cell sc + 1, sr, 32, VT_WHITE, clr
    Next i
End Sub

'' --- locking and line clearing -----------------------------------------------
Sub lock_piece()
    get_cells cur_pc, cur_rot
    Dim i As Long
    For i = 0 To 3
        Dim bx As Long = cur_bx + cell_cx(i)
        Dim by As Long = cur_by + cell_cy(i)
        If by >= 0 AndAlso by < BOARD_H AndAlso bx >= 0 AndAlso bx < BOARD_W Then
            board(bx, by) = cur_pc + 1
        End If
    Next i
End Sub

'' Remove all full rows in one compaction pass. Returns count cleared.
Function clear_lines() As Long
    Dim src     As Long = BOARD_H - 1
    Dim dst     As Long = BOARD_H - 1
    Dim bx      As Long
    Dim by      As Long
    Dim cleared As Long = 0
    Dim full    As Byte

    Do While src >= 0
        full = 1
        For bx = 0 To BOARD_W - 1
            If board(bx, src) = 0 Then full = 0 : Exit For
        Next bx
        If full Then
            cleared += 1
        Else
            If dst <> src Then
                For bx = 0 To BOARD_W - 1
                    board(bx, dst) = board(bx, src)
                Next bx
            End If
            dst -= 1
        End If
        src -= 1
    Loop
    '' Blank the vacated rows at the top
    For by = 0 To dst
        For bx = 0 To BOARD_W - 1 : board(bx, by) = 0 : Next bx
    Next by

    Return cleared
End Function

'' --- scoring and speed -------------------------------------------------------
Sub add_score(nc As Long)
    Dim old_lvl As Long = lvl
    Select Case nc
    Case 1 : score += 100 * lvl
    Case 2 : score += 300 * lvl
    Case 3 : score += 500 * lvl
    Case 4 : score += 800 * lvl
    End Select
    tot_lines += nc
    lvl = tot_lines \ 10 + 1
    update_panel()
    If lvl > old_lvl Then   '' level-up fanfare
        vt_sound 523, 80,  VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 659, 80,  VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 784, 180, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    End If
End Sub

'' Gravity drop interval in milliseconds (clamps at 50ms)
Function grav_ms() As Long
    Dim ms As Long = 800 - (lvl - 1) * 65
    If ms < 50 Then ms = 50
    Return ms
End Function

'' --- sound helpers -----------------------------------------------------------
Sub snd_move()
    vt_sound 440, 25, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
End Sub

Sub snd_rotate()
    vt_sound 550, 25, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
End Sub

Sub snd_lock()
    vt_sound 180, 70, VT_WAVE_TRIANGLE, VT_SOUND_BACKGROUND
End Sub

Sub snd_clear(nc As Long)
    If nc >= 4 Then   '' Tetris!
        vt_sound 523,  100, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 659,  100, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 784,  100, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 1047, 400, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    ElseIf nc > 0 Then
        vt_sound 523, 80,  VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
        vt_sound 659, 130, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    End If
End Sub

Sub snd_gameover()
    vt_sound 440, 120, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    vt_sound 330, 120, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    vt_sound 220, 200, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
    vt_sound 110, 500, VT_WAVE_SQUARE, VT_SOUND_BACKGROUND
End Sub

'' --- spawn -------------------------------------------------------------------
'' Pull nxt_pc into play, pick next from bag. Returns 0 if spawn blocked (game over).
Function spawn_piece() As Byte
    cur_pc  = nxt_pc
    cur_rot = 0
    cur_bx  = 3     '' 4x4 box starts at board col 3 ? piece spans cols 3-6
    cur_by  = -1    '' one row above board; piece enters from top
    nxt_pc  = draw_bag()
    draw_next_piece()
    Return piece_ok(cur_pc, cur_rot, cur_bx, cur_by)
End Function

'' --- title screen ------------------------------------------------------------
Sub title_screen()
    Dim i As Long

    vt_page 1, VT_VIDEO
    vt_color VT_BLACK, VT_BLACK
    vt_cls
    vt_scroll_enable 0

    '' Colored block strips at top and bottom
    For i = 1 To 80
        vt_set_cell i, 1,  219, pc_col((i - 1) Mod 7), VT_BLACK
        vt_set_cell i, 25, 219, pc_col((i + 3) Mod 7), VT_BLACK
    Next i

    '' Title box  (26 chars wide, starting col 28, rows 4-8)
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

    vt_pcopy 1, VT_VIDEO
    vt_present()
    vt_sleep 0   '' wait for any key
End Sub

'' --- main game ---------------------------------------------------------------
Sub run_game()
    Dim k         As ULong
    Dim grav_t    As Double
    Dim nc        As Long
    Dim gy        As Long
    Dim new_rot   As Long
    Dim bx        As Long
    Dim by        As Long
    Dim is_paused As Byte = 0

    '' Reset board
    For by = 0 To BOARD_H - 1
        For bx = 0 To BOARD_W - 1 : board(bx, by) = 0 : Next bx
    Next by
    score = 0 : lvl = 1 : tot_lines = 0 : is_over = 0

    '' Build screen on page 1
    vt_page 1, VT_VIDEO
    vt_color VT_BLACK, VT_BLACK
    vt_cls
    vt_scroll_enable 0

    vt_color VT_BRIGHT_CYAN, VT_BLACK
    vt_print_center 1, " V T e t r i s "

    draw_border()
    draw_board()
    draw_panel_static()
    update_panel()

    '' Prime bag and spawn first piece
    shuffle_bag()
    nxt_pc = draw_bag()
    draw_next_piece()
    If spawn_piece() = 0 Then is_over = 1

    grav_t = Timer()
    vt_key_flush()
    vt_pcopy 1, VT_VIDEO
    vt_present()

    '' -- game loop ------------------------------------------------------------
    Do While is_over = 0

        '' -- input ----------------------------------------------------------
        k = vt_inkey()
        Do While k <> 0

            '' ESC always works
            If VT_SCAN(k) = VT_KEY_ESC Then
                want_quit = 1 : is_over = 1 : Exit Do
            End If

            '' P always works — toggle pause
            If VT_CHAR(k) = Asc("p") OrElse VT_CHAR(k) = Asc("P") Then
                is_paused = 1 - is_paused
                If is_paused Then
                    vt_color VT_YELLOW, VT_BLACK
                    vt_print_center 12, " P A U S E D "
                    vt_pcopy 1, VT_VIDEO : vt_present()
                Else
                    grav_t = Timer()   '' don't count paused time as gravity
                End If
                k = vt_inkey() : Continue Do
            End If

            '' Skip movement keys while paused
            If is_paused Then k = vt_inkey() : Continue Do

            '' Movement and rotation
            Select Case VT_SCAN(k)

            Case VT_KEY_LEFT
                If piece_ok(cur_pc, cur_rot, cur_bx - 1, cur_by) Then
                    cur_bx -= 1 : snd_move()
                End If

            Case VT_KEY_RIGHT
                If piece_ok(cur_pc, cur_rot, cur_bx + 1, cur_by) Then
                    cur_bx += 1 : snd_move()
                End If

            Case VT_KEY_UP
                '' Rotate CW with ±1 wall-kick
                new_rot = (cur_rot + 1) Mod 4
                If piece_ok(cur_pc, new_rot, cur_bx, cur_by) Then
                    cur_rot = new_rot : snd_rotate()
                ElseIf piece_ok(cur_pc, new_rot, cur_bx - 1, cur_by) Then
                    cur_bx -= 1 : cur_rot = new_rot : snd_rotate()
                ElseIf piece_ok(cur_pc, new_rot, cur_bx + 1, cur_by) Then
                    cur_bx += 1 : cur_rot = new_rot : snd_rotate()
                End If

            Case VT_KEY_DOWN
                '' Soft drop
                If piece_ok(cur_pc, cur_rot, cur_bx, cur_by + 1) Then
                    cur_by += 1 : update_panel() : grav_t = Timer()
                End If

            Case VT_KEY_SPACE
                '' Hard drop — calculate ghost, drop, lock, clear
                gy = ghost_row()
                score  += (gy - cur_by) * 2
                cur_by  = gy
                lock_piece() : snd_lock()
                draw_board()
                vt_pcopy 1, VT_VIDEO : vt_present()
                vt_sleep 80
                nc = clear_lines()
                If nc > 0 Then snd_clear nc : add_score nc
                draw_board()
                If spawn_piece() = 0 Then is_over = 1
                grav_t = Timer()
                k = 0 : Exit Do   '' consume remaining keys this tick

            Case Else
                '' X = rotate CCW with ±1 wall-kick
                If VT_CHAR(k) = Asc("x") OrElse VT_CHAR(k) = Asc("X") Then
                                
                    new_rot = (cur_rot + 3) Mod 4
                    If piece_ok(cur_pc, new_rot, cur_bx, cur_by) Then
                        cur_rot = new_rot : snd_rotate()
                    ElseIf piece_ok(cur_pc, new_rot, cur_bx - 1, cur_by) Then
                        cur_bx -= 1 : cur_rot = new_rot : snd_rotate()
                    ElseIf piece_ok(cur_pc, new_rot, cur_bx + 1, cur_by) Then
                        cur_bx += 1 : cur_rot = new_rot : snd_rotate()
                    End If
                End If

            End Select

            k = vt_inkey()
        Loop

        If is_over Then Exit Do

        '' -- gravity ---------------------------------------------------------
        If is_paused = 0 Then
            If (Timer() - grav_t) * 1000.0 >= grav_ms() Then
                grav_t = Timer()
                If piece_ok(cur_pc, cur_rot, cur_bx, cur_by + 1) Then
                    cur_by += 1
                Else
                    '' Piece has landed — lock and spawn next
                    lock_piece() : snd_lock()
                    draw_board()
                    vt_pcopy 1, VT_VIDEO : vt_present()
                    vt_sleep 80
                    nc = clear_lines()
                    If nc > 0 Then snd_clear nc : add_score nc
                    draw_board()
                    If spawn_piece() = 0 Then is_over = 1
                End If
            End If
        End If

        If is_over Then Exit Do

        '' -- render ----------------------------------------------------------
        If is_paused = 0 Then
            gy = ghost_row()
            draw_board()
            draw_ghost gy
            draw_cur 0
        End If
        vt_pcopy 1, VT_VIDEO
        vt_present()
        vt_Sleep 16 '' ~60 fps cap
    Loop

    '' -- game over screen -----------------------------------------------------
    If want_quit = 0 Then
        snd_gameover()
        vt_sound_wait()
        vt_color VT_BRIGHT_RED, VT_BLACK
        vt_print_center 10, " G A M E   O V E R "
        vt_color VT_YELLOW, VT_BLACK
        vt_print_center 12, " Score: " & score & " "
        vt_color VT_LIGHT_GREY, VT_BLACK
        vt_print_center 14, " Press any key "
        vt_pcopy 1, VT_VIDEO
        vt_present()
        vt_sleep 0
    End If
End Sub

'' --- entry point -------------------------------------------------------------
Randomize
init_pieces()

vt_title "VTetris"
vt_screen VT_SCREEN_0, VT_FULLSCREEN_ASPECT, 2
vt_key_repeat 150, 40 '' custom DAS
vt_locate , , 0       '' hide text cursor
vt_mouse 1            '' enable console mouse to hide OS mouse cursor
vt_setmouse , , 0     '' hide our console mouse

Do
    want_quit = 0
    vt_key_flush()
    title_screen()
    run_game()
Loop While want_quit = 0