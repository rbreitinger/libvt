' =============================================================================
' ex_bload.bas -- vt_bsave / vt_bload demo
'
' Draws two themed screens and saves each to a .vts file, then enters a
' switcher loop where F1/F2 restores either screen instantly from disk.
'
' The key point: the entire cell buffer (ch + fg + bg for every cell) is
' preserved in the file. Instructions baked into each screen come back
' with the load -- the file is a complete snapshot.
'
' Files written to the working directory:
'   screen_a.vts   blue theme, fake main menu
'   screen_b.vts   dark theme, full colour palette swatch
'
' Return codes shown on bload failure:
'  -2 = file not found   -3 = not a .vts file   -4 = wrong screen mode
' =============================================================================

#include once "vt/vt.bi"

Declare Sub draw_screen_a()
Declare Sub draw_screen_b()
Declare Sub show_load_error(ret As Long)

Const FILE_A = "screen_a.vts"
Const FILE_B = "screen_b.vts"

Dim k   As ULong
Dim ret As Long

vt_title "ex_bload"
vt_screen VT_SCREEN_0

' -----------------------------------------------------------------------
' Build and save both screens up front.
' A brief pause after each so the user sees what was saved.
' -----------------------------------------------------------------------
draw_screen_a()
vt_present()
ret = vt_bsave(FILE_A)
If ret <> 0 Then
    vt_color(VT_BRIGHT_RED, VT_BLACK)
    vt_locate(13, 28) : vt_print("vt_bsave failed: " & Str(ret))
    vt_present()
    vt_sleep(0)
    End
End If
vt_sleep(700)

draw_screen_b()
vt_present()
ret = vt_bsave(FILE_B)
If ret <> 0 Then
    vt_color(VT_BRIGHT_RED, VT_BLACK)
    vt_locate(13, 28) : vt_print("vt_bsave failed: " & Str(ret))
    vt_present()
    vt_sleep(0)
    End
End If
vt_sleep(700)

' -----------------------------------------------------------------------
' Switcher loop -- F1/F2 reload from disk, ESC quits
' -----------------------------------------------------------------------
vt_bload(FILE_A)
vt_present()

Do
    k = vt_inkey()

    Select Case VT_SCAN(k)
        Case VT_KEY_F1
            ret = vt_bload(FILE_A)
            If ret <> 0 Then show_load_error(ret) Else vt_present()
        Case VT_KEY_F2
            ret = vt_bload(FILE_B)
            If ret <> 0 Then show_load_error(ret) Else vt_present()
        Case VT_KEY_ESC
            Exit Do
    End Select

    Sleep 10, 1
Loop

vt_shutdown
End

' =============================================================================
' draw_screen_a -- blue theme, centered title, fake menu
' =============================================================================
Sub draw_screen_a()
    Dim cc  As Long
    Dim rr  As Long
    Dim txt As String

    vt_color(VT_WHITE, VT_BLUE)
    vt_cls()

    ' double-line border
    vt_set_cell(1,  1,  201, VT_LIGHT_GREY, VT_BLUE)
    vt_set_cell(80, 1,  187, VT_LIGHT_GREY, VT_BLUE)
    vt_set_cell(1,  25, 200, VT_LIGHT_GREY, VT_BLUE)
    vt_set_cell(80, 25, 188, VT_LIGHT_GREY, VT_BLUE)
    For cc = 2 To 79
        vt_set_cell(cc, 1,  205, VT_LIGHT_GREY, VT_BLUE)
        vt_set_cell(cc, 25, 205, VT_LIGHT_GREY, VT_BLUE)
    Next cc
    For rr = 2 To 24
        vt_set_cell(1,  rr, 186, VT_LIGHT_GREY, VT_BLUE)
        vt_set_cell(80, rr, 186, VT_LIGHT_GREY, VT_BLUE)
    Next rr

    ' title block
    vt_color(VT_YELLOW, VT_BLUE)
    txt = "* SCREEN A *"
    vt_locate(6, (80 - Len(txt)) \ 2 + 1) : vt_print(txt)
    vt_color(VT_CYAN, VT_BLUE)
    txt = "Blue Theme -- Saved as screen_a.vts"
    vt_locate(7, (80 - Len(txt)) \ 2 + 1) : vt_print(txt)

    ' fake menu entries
    vt_color(VT_WHITE, VT_BLUE)
    Dim items(4) As String
    items(0) = "1.  New Game"
    items(1) = "2.  Load Game"
    items(2) = "3.  Options"
    items(3) = "4.  Credits"
    items(4) = "5.  Quit"
    For rr = 0 To 4
        vt_locate(10 + rr, (80 - Len(items(rr))) \ 2 + 1)
        vt_print(items(rr))
    Next rr

    ' decorative separator
    vt_color(VT_DARK_GREY, VT_BLUE)
    txt = String(40, Chr(196))
    vt_locate(16, (80 - Len(txt)) \ 2 + 1) : vt_print(txt)

    ' instructions baked into the saved screen
    vt_color(VT_BLACK, VT_CYAN)
    vt_locate(25, 2)
    vt_print(" F1 = Screen A   F2 = Screen B   ESC = quit ")
End Sub

' =============================================================================
' draw_screen_b -- dark theme, full 16-colour palette swatch
' =============================================================================
Sub draw_screen_b()
    Dim ci  As Long
    Dim cc  As Long
    Dim rr  As Long
    Dim txt As String

    Dim color_names(15) As String
    color_names(0)  = "Black       "
    color_names(1)  = "Blue        "
    color_names(2)  = "Green       "
    color_names(3)  = "Cyan        "
    color_names(4)  = "Red         "
    color_names(5)  = "Magenta     "
    color_names(6)  = "Brown       "
    color_names(7)  = "Light Grey  "
    color_names(8)  = "Dark Grey   "
    color_names(9)  = "Bright Blue "
    color_names(10) = "Bright Green"
    color_names(11) = "Bright Cyan "
    color_names(12) = "Bright Red  "
    color_names(13) = "Bright Mag. "
    color_names(14) = "Yellow      "
    color_names(15) = "White       "

    vt_color(VT_LIGHT_GREY, VT_BLACK)
    vt_cls()

    ' title
    vt_color(VT_YELLOW, VT_BLACK)
    txt = "* SCREEN B *"
    vt_locate(2, (80 - Len(txt)) \ 2 + 1) : vt_print(txt)
    vt_color(VT_DARK_GREY, VT_BLACK)
    txt = "Dark Theme -- Saved as screen_b.vts"
    vt_locate(3, (80 - Len(txt)) \ 2 + 1) : vt_print(txt)

    ' column headers
    vt_color(VT_DARK_GREY, VT_BLACK)
    vt_locate(5, 5)  : vt_print("Idx  Colour Name    ")
    vt_locate(5, 25) : vt_print("Swatch (fg on black / fg on white)")

    ' one row per colour
    For ci = 0 To 15
        vt_color(VT_DARK_GREY, VT_BLACK)
        vt_locate(6 + ci, 5)
        vt_print(Right("0" & Str(ci), 2) & "   " & color_names(ci))

        ' swatch: 6 blocks on black bg
        For cc = 0 To 5
            vt_set_cell(29 + cc, 6 + ci, 219, ci, VT_BLACK)
        Next cc

        vt_set_cell(36, 6 + ci, 32, VT_LIGHT_GREY, VT_BLACK)

        ' swatch: 6 blocks on white bg
        For cc = 0 To 5
            vt_set_cell(38 + cc, 6 + ci, 219, ci, VT_WHITE)
        Next cc
    Next ci

    ' instructions baked into the saved screen
    vt_color(VT_BLACK, VT_CYAN)
    vt_locate(25, 2)
    vt_print(" F1 = Screen A   F2 = Screen B   ESC = quit ")
End Sub

' =============================================================================
' show_load_error -- brief inline error, waits for a key before returning
' =============================================================================
Sub show_load_error(ret As Long)
    Dim err_txt As String
    Select Case ret
        Case -2 : err_txt = "file not found"
        Case -3 : err_txt = "not a .vts file"
        Case -4 : err_txt = "wrong screen mode"
        Case Else : err_txt = "error " & Str(ret)
    End Select
    vt_color(VT_WHITE, VT_RED)
    vt_locate(13, (80 - Len(err_txt) - 19) \ 2 + 1)
    vt_print("  vt_bload failed: " & err_txt & "  ")
    vt_present()
    vt_sleep(1500)
End Sub
