' =============================================================================
' ex_screeninfo.bas -- vt_screeninfo / vt_width dynamic resize demo
'
' Shows how to poll vt_screeninfo() each frame and call vt_width() when the
' user resizes the window, then re-layout the application around the new size.
'
' =============================================================================
#Include Once "../vt/vt.bi"

' -----------------------------------------------------------------------------
' draw_layout - repaint everything for the current grid dimensions.
' Call once after startup and again whenever vt_width() is called.
' -----------------------------------------------------------------------------
Sub draw_layout(cols As Long, rows As Long)
    Dim txt     As String
    Dim info_row As Long

    vt_cls

    ' --- top bar ---
    vt_color VT_BLACK, VT_LIGHT_GREY
    vt_locate 1, 1
    vt_print String(cols, " ")
    vt_locate 1, 1
    vt_print " vt_screeninfo / vt_width demo"

    ' --- centered body ---
    vt_color VT_WHITE, VT_BLACK

    info_row = rows \ 2 - 2
    If info_row < 2 Then info_row = 2

    vt_print_center info_row,     "Resize the window to see vt_width() in action."
    vt_print_center info_row + 1, "The grid snaps to whole character cells automatically."
    vt_print_center info_row + 2, ""

    txt = "Current grid:  " & cols & " cols  x  " & rows & " rows"
    vt_color VT_YELLOW, VT_BLACK
    vt_print_center info_row + 3, txt

    ' --- bottom bar ---
    vt_color VT_BLACK, VT_LIGHT_GREY
    vt_locate rows, 1
    vt_print String(cols, " ")
    vt_locate rows, 1
    vt_print " ESC = quit"

    vt_color VT_LIGHT_GREY, VT_BLACK
End Sub

' =============================================================================
' main
' =============================================================================
vt_title "vt_screeninfo demo"
vt_screen VT_SCREEN_0, VT_WINDOWED
vt_scroll_enable VT_DISABLED

Dim k        As ULong
Dim nc       As Long
Dim nr       As Long

draw_layout vt_cols(), vt_rows()

Do
    k = vt_inkey()
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do

    ' poll physical output size -- returns 1 only when cols or rows changed
    If vt_screeninfo(nc, nr) Then
        vt_width nc, nr          ' reallocate buffers + reset state
        draw_layout nc, nr       ' re-layout app around new grid
    End If

    vt_sleep 16
Loop

vt_shutdown()
