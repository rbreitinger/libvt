' =============================================================================
' ex_close_guard.bas - vt_on_close callback demo
' Shows how to intercept the window [X] button to guard against data loss.
' =============================================================================
#Include Once "../vt/vt.bi"

' -----------------------------------------------------------------------------
' Global flag -- set whenever the user has "unsaved" content
' -----------------------------------------------------------------------------
Dim Shared unsaved As Byte

' -----------------------------------------------------------------------------
' Draw the status bar at row 25 in its normal look
' -----------------------------------------------------------------------------
Sub draw_statusbar()
    vt_color VT_BLACK, VT_CYAN
    vt_locate 25, 1
    vt_print "  ESC = quit cleanly   Any key = mark unsaved" & String(35, " ")
End Sub

' -----------------------------------------------------------------------------
' Update the title bar at row 1
' -----------------------------------------------------------------------------
Sub draw_title()
    vt_color VT_WHITE, VT_BLUE
    vt_locate 1, 1
    If unsaved Then
        vt_print "  [Close Guard Demo] *UNSAVED*" & String(50, " ")
    Else
        vt_print "  [Close Guard Demo]" & String(60, " ")
    End If
End Sub

' -----------------------------------------------------------------------------
' Close callback -- called by the library when the [X] button is pressed.
' Return 0 = let the library shut down normally.
' Return 1 = veto the close, stay open.
' -----------------------------------------------------------------------------
Function on_close() As Byte
    Dim ans As String

    If unsaved = 0 Then Return 0   ' nothing to lose, close as normal

    ' Overwrite the status bar with the confirmation prompt
    vt_color VT_YELLOW, VT_DARK_GREY
    vt_locate 25, 1
    vt_print "  Unsaved changes!  Quit without saving? (Y/N)" & String(34, " ")
    
    ans = vt_getchar("YyNn")
    
    If LCase(ans) = "y" Then Return 0   ' confirmed -- let library close

    ' Vetoed -- restore the normal status bar
    draw_statusbar()
    Return 1
End Function

' -----------------------------------------------------------------------------
' Draw the static chrome of the fake editor
' -----------------------------------------------------------------------------
Sub draw_editor()
    Dim row As Long

    vt_cls

    draw_title()

    ' Empty editor body
    vt_color VT_LIGHT_GREY, VT_BLACK
    For row = 2 To 24
        vt_locate row, 1
        vt_print String(80, " ")
    Next row

    draw_statusbar()
End Sub

' =============================================================================
' Main
' =============================================================================
vt_screen VT_SCREEN_0, VT_WINDOWED Or VT_NO_RESIZE
vt_title "Close Guard Demo"
vt_on_close(@on_close)
vt_scroll_enable 0

unsaved = 0
draw_editor()

vt_color VT_LIGHT_GREY, VT_BLACK
vt_locate 8, 10
vt_print "Try pressing the [X] button on the window."
vt_locate 9, 10
vt_print "First without pressing any key here -- it will close cleanly."
vt_locate 11, 10
vt_print "Then press any key to mark changes as unsaved, and try [X] again."
vt_locate 12, 10
vt_print "You will be asked to confirm before the window closes."

Dim k As ULong

Do
    k = vt_inkey()

    If k <> 0 Then
        If VT_SCAN(k) = VT_KEY_ESC Then Exit Do

        If unsaved = 0 Then
            unsaved = 1
            draw_title()
            vt_color VT_BRIGHT_RED, VT_BLACK
            vt_locate 14, 10
            vt_print "Changes marked as unsaved. Now try the [X] button."
        End If
    End If

    vt_Sleep 10
Loop

vt_shutdown()
