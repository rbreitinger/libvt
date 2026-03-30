' =============================================================================
' vt_test.bas - VT Library first test
' Tests: init, cls, color, locate, print, print_center, box drawing,
'        vt_get_cell, vt_set_cell, vt_should_quit, vt_inkey.
' Compile: fbc vt_test.bas
' =============================================================================

#include once "vt/vt.bi"


' -----------------------------------------------------------------------------
' Draw a single-line box using CP437 box characters
' col, row: top-left corner (1-based)
' w, h: width and height including border
' -----------------------------------------------------------------------------
Sub draw_box(col As Long, row As Long, w As Long, ht As Long)
    Dim r As Long
    Dim c As Long

    ' top row
    vt_locate(row, col)
    vt_print(Chr(218) + String(w - 2, Chr(196)) + Chr(191))

    ' sides
    For r = row + 1 To row + ht - 2
        vt_locate(r, col)
        vt_print(Chr(179))
        vt_locate(r, col + w - 1)
        vt_print(Chr(179))
    Next r

    ' bottom row
    vt_locate(row + ht - 1, col)
    vt_print(Chr(192) + String(w - 2, Chr(196)) + Chr(217))
End Sub


' =============================================================================
' Main
' =============================================================================

Dim result As Long
Dim k      As ULong
Dim ci     As Long
Dim ln     As Long

result = vt_init(VT_MODE_80x25)
If result <> 0 Then
    Print "vt_init failed: "; result
    End
End If

' --- screen 1: colour palette display ---
vt_cls()

vt_color(VT_YELLOW, VT_BLACK)
vt_print_center(1, "VT - Virtual Text Screen Library - Test 1")
vt_color(VT_DARK_GREY, VT_BLACK)
vt_print_center(2, "Colour palette and box drawing")

' draw all 16 background colours as filled blocks with their index
For ci = 0 To 15
    vt_color(VT_WHITE, ci)
    vt_locate(4, ci * 4 + 1)
    vt_print(" " & ci & " ")
Next ci

' draw all 16 foreground colours as text samples
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(6, 1)
vt_print("Foreground colours:")
For ci = 0 To 15
    vt_color(ci, VT_BLACK)
    vt_locate(7 + (ci \ 8), (ci Mod 8) * 10 + 1)
    vt_print(Right("  " & ci, 2) & ": Hello")
Next ci

' draw a box
vt_color(VT_CYAN, VT_BLACK)
draw_box(2, 10, 40, 8)

' text inside the box
vt_color(VT_WHITE, VT_BLACK)
vt_locate(11, 4)
vt_print("Box drawn with CP437 characters:")
vt_color(VT_BRIGHT_GREEN, VT_BLACK)
vt_locate(12, 4)
vt_print(Chr(218) & " = 218   " & Chr(191) & " = 191")
vt_locate(13, 4)
vt_print(Chr(179) & " = 179   " & Chr(196) & " = 196")
vt_locate(14, 4)
vt_print(Chr(192) & " = 192   " & Chr(217) & " = 217")

' blinking text demo
vt_color(VT_WHITE Or VT_BLINK, VT_BLACK)
vt_locate(16, 1)
vt_print("This text is blinking!")
vt_color(VT_LIGHT_GREY, VT_BLACK)

' shade blocks demo
vt_locate(18, 1)
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Shade blocks: ")
vt_color(VT_WHITE, VT_BLACK)
vt_print(Chr(176) & Chr(176) & Chr(176) & " ")
vt_print(Chr(177) & Chr(177) & Chr(177) & " ")
vt_print(Chr(178) & Chr(178) & Chr(178) & " ")
vt_print(Chr(219) & Chr(219) & Chr(219))

' vt_set_cell and vt_get_cell test
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(20, 1)
vt_print("vt_set_cell / vt_get_cell test: ")
vt_set_cell(33, 20, Asc("*"), VT_BRIGHT_RED, VT_BLACK)
vt_set_cell(34, 20, Asc("*"), VT_YELLOW,     VT_BLACK)
vt_set_cell(35, 20, Asc("*"), VT_BRIGHT_GREEN, VT_BLACK)
vt_present()

Dim read_ch As UByte
Dim read_fg As UByte
Dim read_bg As UByte
vt_get_cell(34, 20, read_ch, read_fg, read_bg)
vt_locate(21, 1)
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_print("Read back cell (34,20): ch=" & read_ch & " fg=" & read_fg & " bg=" & read_bg)

vt_color(VT_DARK_GREY, VT_BLACK)
vt_locate(24, 1)
vt_print("Press any key to continue, ESC to quit...")
vt_locate(25, 1)

' --- wait for keypress ---
Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then GoTo quit_label
    If k <> 0 Then Exit Do
    If vt_should_quit() Then GoTo quit_label
    Sleep 10
Loop


' --- screen 2: input and scrolling test ---
vt_cls()
vt_color(VT_YELLOW, VT_BLACK)
vt_print_center(1, "VT - Test 2 - Print and Scroll")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(3, 1)

For ln = 1 To 30
    vt_color(ln Mod 14 + 1, VT_BLACK)
    vt_print("Scroll line " & ln & " - the quick brown fox jumps over the lazy dog" & Chr(10))
Next ln

vt_color(VT_DARK_GREY, VT_BLACK)
vt_print("Done scrolling. Press any key to quit...")

Do
    k = vt_inkey()
    If k <> 0 Then Exit Do
    If vt_should_quit() Then Exit Do
    Sleep 10
Loop


quit_label:
vt_shutdown()
