' =============================================================================
' vt_inputtest.bas - vt_getkey / vt_getchar demonstration
' Three use cases: menu choice, yes/no, any key with special key detection.
' =============================================================================

#include once "vt/vt.bi"

Dim choice As String
Dim k      As ULong
Dim answer As String

vt_init(VT_MODE_80x25)
vt_view_print(1, 24)
vt_locate(1, 1, 0)

'--- status bar ---
vt_color(VT_BLACK, VT_LIGHT_GREY)
vt_locate(25, 1)
vt_print(" vt_getkey / vt_getchar demo" & Space(52))

' ==========================================================================
' Demo 1 - menu with vt_getchar filtered
' ==========================================================================
vt_color(VT_WHITE, VT_BLACK)
vt_cls()
vt_locate(3, 4)  : vt_print("DEMO 1 - Menu selection with vt_getchar(allowed)")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 4)  : vt_print("Only keys 1-3 are accepted. Any other key is silently ignored.")
vt_locate(7, 4)  : vt_print("1. New Game")
vt_locate(8, 4)  : vt_print("2. Load Game")
vt_locate(9, 4)  : vt_print("3. Quit")
vt_color(VT_YELLOW, VT_BLACK)
vt_locate(11, 4) : vt_print("Your choice: ")
vt_present()

choice = vt_getchar("123")

vt_color(VT_BRIGHT_GREEN, VT_BLACK)
vt_locate(11, 17) : vt_print(choice)
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(13, 4)

Select Case choice
    Case "1" : vt_print("You chose: New Game")
    Case "2" : vt_print("You chose: Load Game")
    Case "3" : vt_print("You chose: Quit")
End Select

vt_locate(15, 4) : vt_print("Press any key to continue...")
vt_present()
vt_key_flush()   ' clear any repeat events from menu keypress
vt_getkey()

' ==========================================================================
' Demo 2 - yes/no with vt_getchar case insensitive
' ==========================================================================
vt_color(VT_WHITE, VT_BLACK)
vt_cls()
vt_locate(3, 4)  : vt_print("DEMO 2 - Yes/No with vt_getchar, case insensitive")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 4)  : vt_print("Y, y, N and n are accepted. Anything else is ignored.")
vt_color(VT_YELLOW, VT_BLACK)
vt_locate(7, 4)  : vt_print("Are you enjoying this demo? (Y/N): ")
vt_present()
vt_key_flush()   ' clear any repeat events from menu keypress

answer = LCase(vt_getchar("YyNn"))

vt_color(VT_BRIGHT_GREEN, VT_BLACK)
vt_locate(7, 40) : vt_print(UCase(answer))
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(9, 4)

If answer = "y" Then
    vt_print("Glad to hear it!")
Else
    vt_print("We will do better!")
End If

vt_locate(11, 4) : vt_print("Press any key to continue...")
vt_present()
vt_key_flush()   ' clear any repeat events from menu keypress
vt_getkey()

' ==========================================================================
' Demo 3 - vt_getkey returning full key record, special keys detected
' ==========================================================================
vt_color(VT_WHITE, VT_BLACK)
vt_cls()
vt_locate(3, 4)  : vt_print("DEMO 3 - Full key record with vt_getkey")
vt_color(VT_LIGHT_GREY, VT_BLACK)
vt_locate(5, 4)  : vt_print("Press any key. Shows ASCII and scancode. ESC to finish.")
vt_locate(7, 4)  : vt_print("Key            ASCII   Scancode")
vt_locate(8, 4)  : vt_print(String(40, 196))
vt_key_flush()   ' clear any repeat events from menu keypress

Dim row As Long = 9
Do
    vt_locate(row, 4) : vt_print(Space(50))
    vt_locate(row, 4)
    vt_present()

    k = vt_getkey()
    If k = 0 Then Exit Do
    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do

    Dim ch_val   As UByte  = VT_CHAR(k)
    Dim sc_val   As Long   = VT_SCAN(k)
    Dim key_desc As String

    Select Case sc_val
        Case VT_KEY_ENTER  : key_desc = "Enter"
        Case VT_KEY_BKSP   : key_desc = "Backspace"
        Case VT_KEY_TAB    : key_desc = "Tab"
        Case VT_KEY_SPACE  : key_desc = "Space"
        Case VT_KEY_UP     : key_desc = "Up"
        Case VT_KEY_DOWN   : key_desc = "Down"
        Case VT_KEY_LEFT   : key_desc = "Left"
        Case VT_KEY_RIGHT  : key_desc = "Right"
        Case VT_KEY_F1     : key_desc = "F1"
        Case VT_KEY_F2     : key_desc = "F2"
        Case VT_KEY_F3     : key_desc = "F3"
        Case VT_KEY_F4     : key_desc = "F4"
        Case Else
            If ch_val >= 32 Then
                key_desc = Chr(ch_val)
            Else
                key_desc = "?"
            End If
    End Select

    vt_color(VT_YELLOW, VT_BLACK)
    vt_locate(row, 4)  : vt_print(key_desc & Space(15 - Len(key_desc)))
    vt_color(VT_BRIGHT_CYAN, VT_BLACK)
    vt_locate(row, 19) : vt_print(Str(ch_val) & Space(8 - Len(Str(ch_val))))
    vt_color(VT_BRIGHT_GREEN, VT_BLACK)
    vt_locate(row, 27) : vt_print(Str(sc_val))
    vt_present()

    row += 1
    If row > 23 Then row = 9
Loop

vt_shutdown()
