#include once "vt/vt.bi"

' =============================================================================
' vt_mouse_test.bas
' Dot grid paintbox. Status bar row 25 shows live pos, btns, wheel.
' LMB = paint block (cycling colour)
' RMB = erase back to dot
' MMB = clear whole grid
' ESC = quit
' =============================================================================

vt_title "VT Mouse Test"
vt_screen VT_SCREEN_0

' restrict scroll region, row 25 is the status bar
vt_view_print(1, 24)
vt_locate(25, 1, 0)

' fill play area with a grey dot grid
Dim row_i As Long
Dim col_i As Long
For row_i = 1 To 24
    For col_i = 1 To 80
        vt_set_cell(col_i, row_i, Asc("."), VT_DARK_GREY, VT_BLACK)
    Next col_i
Next row_i

vt_mouse(1)
vt_mousecursor(219, VT_WHITE)

Dim mx          As Long
Dim my          As Long
Dim mb          As Long
Dim mw          As Long
Dim prev_mb     As Long
Dim wheel_total As Long
Dim k           As ULong
Dim paint_clr   As Long
Dim whl_str     As String
Dim pos_str     As String

paint_clr   = VT_BRIGHT_CYAN
wheel_total = 0

Do
    prev_mb      = mb
    vt_getmouse(@mx, @my, @mb, @mw)
    wheel_total += mw

    ' left click: stamp a filled block in cycling colour (edge triggered)
    If (mb And VT_MOUSE_BTN_LEFT) AndAlso ((prev_mb And VT_MOUSE_BTN_LEFT) = 0) Then
        vt_set_cell(mx, my, 219, paint_clr, VT_BLACK)
        paint_clr += 1
        If paint_clr > VT_WHITE Then paint_clr = VT_BLUE
    End If

    ' right click: erase back to dot (edge triggered)
    If (mb And VT_MOUSE_BTN_RIGHT) AndAlso ((prev_mb And VT_MOUSE_BTN_RIGHT) = 0) Then
        vt_set_cell(mx, my, Asc("."), VT_DARK_GREY, VT_BLACK)
    End If

    ' middle click: clear entire play area (edge triggered)
    If (mb And VT_MOUSE_BTN_MIDDLE) AndAlso ((prev_mb And VT_MOUSE_BTN_MIDDLE) = 0) Then
        For row_i = 1 To 24
            For col_i = 1 To 80
                vt_set_cell(col_i, row_i, Asc("."), VT_DARK_GREY, VT_BLACK)
            Next col_i
        Next row_i
    End If

    ' -------------------------------------------------------------------------
    ' status bar -- row 25, fixed width fields, trailing spaces clear old digits
    ' -------------------------------------------------------------------------
    vt_locate(25, 1, 0)

    ' position: cols 1-80 and rows 1-24 are always 1-2 digits; pad to 2 wide manually
    pos_str = Str(mx)
    If Len(pos_str) < 2 Then pos_str = " " & pos_str
    Dim pos_str2 As String = Str(my)
    If Len(pos_str2) < 2 Then pos_str2 = " " & pos_str2
    vt_color(VT_LIGHT_GREY, VT_BLACK)
    vt_print(" Pos:" & pos_str & "," & pos_str2 & " ")

    ' button indicators -- bright when held, dark when up
    If mb And VT_MOUSE_BTN_LEFT Then
        vt_color(VT_BLACK, VT_BRIGHT_GREEN)
    Else
        vt_color(VT_DARK_GREY, VT_BLACK)
    End If
    vt_print("[L]")

    If mb And VT_MOUSE_BTN_MIDDLE Then
        vt_color(VT_BLACK, VT_BRIGHT_GREEN)
    Else
        vt_color(VT_DARK_GREY, VT_BLACK)
    End If
    vt_print("[M]")

    If mb And VT_MOUSE_BTN_RIGHT Then
        vt_color(VT_BLACK, VT_BRIGHT_GREEN)
    Else
        vt_color(VT_DARK_GREY, VT_BLACK)
    End If
    vt_print("[R]")

    ' wheel accumulator -- prefix + for positive, trailing spaces clear old digits
    whl_str = Str(wheel_total)
    If wheel_total >= 0 Then whl_str = "+" & whl_str
    vt_color(VT_BRIGHT_CYAN, VT_BLACK)
    vt_print("  Wheel:" & whl_str & "     ")

    ' hints
    vt_color(VT_DARK_GREY, VT_BLACK)
    vt_print(" LMB:paint  RMB:erase  MMB:clear  ESC:quit")

    ' -------------------------------------------------------------------------
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do

    vt_sleep 1
Loop

vt_mouse(0)