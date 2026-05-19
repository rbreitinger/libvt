'>>>
':topic vt_key_repeat
':short Configure auto-repeat timing
':group Keyboard
'Configure the timing of auto-repeat events
'generated when a key is held down. Default:
'400 ms initial delay, 30 ms repeat rate. Set
'either value to 0 to disable the corresponding
'phase of repeat.
':syntax
Sub vt_key_repeat(initial_ms As Long = 400, _
                  rate_ms    As Long = 30)
        ':params
        'initial_ms  Delay in ms before the first repeat
        '            event fires. Default 400.
        'rate_ms     Interval in ms between subsequent
        '            repeat events. Default 30.
        ':see
        'vt_inkey
    '<<<
    vt_internal.rep_initial = initial_ms
    vt_internal.rep_rate    = rate_ms
End Sub

'>>>
':topic vt_inkey
':short Non-blocking key read
':group Keyboard
'Non-blocking key read. Returns the next key
'from the buffer, or 0 if no key is pending.
'Also pumps events, updates blink, and calls
'vt_present if the display is dirty (throttled
'to 2 ms). Use VT_SCAN / VT_CHAR macros to
'decode the returned value.
':syntax
Function vt_inkey() As ULong
        ':notes
        'Return: packed key event (non-zero) if a key
        'was waiting. 0 if the buffer is empty or the
        'library is not ready.
        ':example
        '' Game loop pattern:
        'Do
        '    Dim k As ULong = vt_inkey()
        '    If VT_SCAN(k) = VT_KEY_ESC Then Exit Do
        '    ' ... update and draw ...
        '    vt_sleep 16
        'Loop
        ':see
        'vt_getkey
        'vt_getchar
        'vt_pump
        'c_keymacros
        'c_keyscans
    '<<<
    If vt_internal.ready = 0 Then Return 0
    vt_pump()
    If vt_internal_blink_update() Then vt_internal.dirty = 1
    vt_internal_present_if_dirty()
    If vt_internal.key_count = 0 Then Return 0
    Dim evt As ULong = vt_internal.key_buf(vt_internal.key_read)
    vt_internal.key_read  = (vt_internal.key_read + 1) Mod _VT_KEY_BUFFER_SIZE
    vt_internal.key_count -= 1
    Return evt
End Function

'>>>
':topic vt_key_held
':short Poll the real-time state of a key
':group Keyboard
'Poll whether a key is physically held down at
'the time of the call. Returns 1 if held, 0 if
'not. Useful for smooth movement in game loops
'where event-based repeat is not fast enough.
'Accepts the same VT_KEY_* scancode constants
'used with VT_SCAN.
':syntax
Function vt_key_held(vtscan As Long) As Byte
        ':params
        'vtscan  A VT_KEY_* scancode constant.
        ':notes
        'Return values:
        '  1  Key is currently pressed.
        '  0  Not pressed, scancode not recognized,
        '     or library not ready.
        ':example
        'If vt_key_held(VT_KEY_LEFT)  Then x -= 1
        'If vt_key_held(VT_KEY_RIGHT) Then x += 1
        ':see
        'vt_inkey
        'c_keyscans
    '<<<
    Dim sdl_scan As Long
    Dim numkeys  As Long
    Dim states   As Const UByte Ptr

    Select Case vtscan
        Case VT_KEY_F1     : sdl_scan = _VT_DRV_SCANCODE_F1
        Case VT_KEY_F2     : sdl_scan = _VT_DRV_SCANCODE_F2
        Case VT_KEY_F3     : sdl_scan = _VT_DRV_SCANCODE_F3
        Case VT_KEY_F4     : sdl_scan = _VT_DRV_SCANCODE_F4
        Case VT_KEY_F5     : sdl_scan = _VT_DRV_SCANCODE_F5
        Case VT_KEY_F6     : sdl_scan = _VT_DRV_SCANCODE_F6
        Case VT_KEY_F7     : sdl_scan = _VT_DRV_SCANCODE_F7
        Case VT_KEY_F8     : sdl_scan = _VT_DRV_SCANCODE_F8
        Case VT_KEY_F9     : sdl_scan = _VT_DRV_SCANCODE_F9
        Case VT_KEY_F10    : sdl_scan = _VT_DRV_SCANCODE_F10
        Case VT_KEY_F11    : sdl_scan = _VT_DRV_SCANCODE_F11
        Case VT_KEY_F12    : sdl_scan = _VT_DRV_SCANCODE_F12
        Case VT_KEY_ESC    : sdl_scan = _VT_DRV_SCANCODE_ESCAPE
        Case VT_KEY_ENTER  : sdl_scan = _VT_DRV_SCANCODE_RETURN
        Case VT_KEY_BKSP   : sdl_scan = _VT_DRV_SCANCODE_BACKSPACE
        Case VT_KEY_TAB    : sdl_scan = _VT_DRV_SCANCODE_TAB
        Case VT_KEY_SPACE  : sdl_scan = _VT_DRV_SCANCODE_SPACE
        Case VT_KEY_UP     : sdl_scan = _VT_DRV_SCANCODE_UP
        Case VT_KEY_DOWN   : sdl_scan = _VT_DRV_SCANCODE_DOWN
        Case VT_KEY_LEFT   : sdl_scan = _VT_DRV_SCANCODE_LEFT
        Case VT_KEY_RIGHT  : sdl_scan = _VT_DRV_SCANCODE_RIGHT
        Case VT_KEY_HOME   : sdl_scan = _VT_DRV_SCANCODE_HOME
        Case VT_KEY_END    : sdl_scan = _VT_DRV_SCANCODE_END
        Case VT_KEY_PGUP   : sdl_scan = _VT_DRV_SCANCODE_PAGEUP
        Case VT_KEY_PGDN   : sdl_scan = _VT_DRV_SCANCODE_PAGEDOWN
        Case VT_KEY_INS    : sdl_scan = _VT_DRV_SCANCODE_INSERT
        Case VT_KEY_DEL    : sdl_scan = _VT_DRV_SCANCODE_DELETE
        Case VT_KEY_LSHIFT : sdl_scan = _VT_DRV_SCANCODE_LSHIFT
        Case VT_KEY_RSHIFT : sdl_scan = _VT_DRV_SCANCODE_RSHIFT
        Case VT_KEY_LCTRL  : sdl_scan = _VT_DRV_SCANCODE_LCTRL
        Case VT_KEY_RCTRL  : sdl_scan = _VT_DRV_SCANCODE_RCTRL
        Case VT_KEY_LALT   : sdl_scan = _VT_DRV_SCANCODE_LALT
        Case VT_KEY_RALT   : sdl_scan = _VT_DRV_SCANCODE_RALT
        Case VT_KEY_LWIN   : sdl_scan = _VT_DRV_SCANCODE_LGUI
        Case VT_KEY_RWIN   : sdl_scan = _VT_DRV_SCANCODE_RGUI
        Case Else          : Return 0
    End Select

    states = _VT_DRV_GetKeyboardState(@numkeys)
    If states = 0 Then Return 0
    If sdl_scan >= numkeys Then Return 0
    Return states[sdl_scan]
End Function

'>>>
':topic vt_getkey
':short Block until any key is pressed
':group Keyboard
'Block until any key (including non-printable and
'special keys) is pressed. Returns the same
'packed ULong format as vt_inkey. Use the
'VT_SCAN / VT_CHAR / VT_SHIFT / VT_CTRL /
'VT_ALT macros to extract fields.
':syntax
Function vt_getkey() As ULong
        ':notes
        'Return: packed key event value. Decode with
        'VT_CHAR, VT_SCAN, VT_SHIFT, VT_CTRL, VT_ALT,
        'VT_REPEAT macros.
        ':example
        'Dim k As ULong = vt_getkey()
        'If VT_SCAN(k) = VT_KEY_ESC Then End
        'If VT_CHAR(k) = Asc("q") Then End
        ':see
        'vt_inkey
        'vt_getchar
        'c_keymacros
        'c_keyscans
    '<<<
    Dim k As ULong
    Do
        k = vt_inkey()
        If k <> 0 Then Return k
        Sleep 10, 1
    Loop
End Function

'>>>
':topic vt_getchar
':short Block until a printable character is pressed
':group Keyboard
'Block until a printable character (ASCII 32-255)
'is pressed. If allowed is non-empty, only
'characters within that string are accepted; all
'others are discarded silently. Returns the
'accepted character as a one-character String.
':syntax
Function vt_getchar(allowed As String = "") _
                    As String
        ':params
        'allowed  Whitelist of accepted characters.
        '         Empty string = accept any printable.
        ':notes
        'Return: single-character String containing the
        'accepted character.
        ':example
        'vt_print("Continue? (Y/N) ")
        'Dim ans As String = UCase(vt_getchar("YyNn"))
        ':see
        'vt_getkey
        'vt_inkey
        'vt_input
    '<<<
    Dim k  As ULong
    Dim ch As UByte
    Do
        k  = vt_getkey()
        ch = VT_CHAR(k)
        If ch >= 32 Then
            If allowed = "" Then Return Chr(ch)
            If InStr(allowed, Chr(ch)) > 0 Then Return Chr(ch)
        End If
    Loop
End Function

'>>>
':topic vt_key_flush
':short Discard all pending keys in the key buffer
':group Keyboard
'Discard all keys currently waiting in the
'internal key buffer.
':syntax
Sub vt_key_flush()
        ':see
        'vt_inkey
    '<<<
    vt_internal.key_read  = 0
    vt_internal.key_write = 0
    vt_internal.key_count = 0
End Sub

'>>>
    ':topic vt_input
    ':short Full-featured blocking single-line editor
    ':group Keyboard
    'Blocking single-line text editor at the current cursor position. Supports Home, End, Left, Right,
    'Insert, Delete, Backspace, and clipboard paste when copy/paste is enabled. Returns the entered
    'string on Enter, or "" on Escape. Colour must be set with vt_color before calling.
':syntax
Function vt_input(max_len   As Long = -1, _
                  initial   As String = "", _
                  allowed   As String = "", _
                  cancelled As Byte Ptr = 0) _
                  As String
        ':params
        'max_len   Max input length. -1 fills remaining
        '          columns on the current row.
        'initial   Pre-filled text. Escape restores this
        '          text, clears the screen, and returns "".
        'allowed   Whitelist of accepted characters.
        '          Empty = accept any printable ASCII.
        'cancelled Optional Byte Ptr. Set to 1 on Escape,
        '          0 on Enter. Pass 0 to ignore.
        ':example
        '#Include Once "vt/vt.bi"
        'vt_screen()
        'Dim esc As Byte
        'vt_locate(10, 1)
        'vt_print("Enter amount: ")
        'Dim amount As String = vt_input(8, "0", "0123456789.", @esc)
        'If esc Then
        '    vt_print("Cancelled" & VT_LF)
        'Else
        '    vt_print("Got: " & amount & VT_LF)
        'End If
        'vt_sleep()
        'vt_shutdown()
        ':see
        'vt_getchar
        'vt_getkey
        'vt_color
        'vt_locate
        'vt_copypaste
    '<<<
    If vt_internal.ready = 0 Then Return ""

    Dim start_col As Long
    Dim start_row As Long
    Dim eff_max   As Long
    Dim avail     As Long
    Dim buf       As String
    Dim epos      As Long      ' edit cursor, 0-based index into buf
    Dim k         As ULong
    Dim sc        As Long
    Dim ch        As UByte
    Dim ci        As Long
    Dim cell_ch   As UByte
    Dim blen      As Long
    Dim clip_ptr  As ZString Ptr
    Dim clip_str  As String
    Dim pi        As Long
    Dim pch       As UByte

    start_col = vt_internal.cur_col
    start_row = vt_internal.cur_row

    ' clamp field width to available columns from start position
    avail   = vt_internal.scr_cols - start_col + 1
    eff_max = max_len
    If eff_max <= 0 OrElse eff_max > avail Then eff_max = avail

    ' clamp initial to eff_max
    buf = initial
    If Len(buf) > eff_max Then buf = Left(buf, eff_max)
    epos = Len(buf)    ' cursor starts at end of initial

    If cancelled <> 0 Then *cancelled = 0

    Do
        ' --- redraw field: buf + space padding to eff_max ---
        blen = Len(buf)
        For ci = 0 To eff_max - 1
            cell_ch = 32
            If ci < blen Then cell_ch = buf[ci]
            vt_set_cell(start_col + ci, start_row, cell_ch, _
                        vt_internal.clr_fg, vt_internal.clr_bg)
        Next ci
        vt_locate(start_row, start_col + epos)

        ' --- wait for key or paste ---
        ' cp_paste_pend is set by vt_pump (Shift+INS or MMB) and unblocks
        ' this loop without needing an actual key in the buffer.
        Do
            k = vt_inkey()
            If k <> 0 Then Exit Do
              If vt_internal.cp_paste_pend Then Exit Do
            Sleep 10, 1
        Loop

        ' --- paste injection ---
        If vt_internal.cp_paste_pend Then
            vt_internal.cp_paste_pend = 0
            clip_ptr = _VT_DRV_GetClipboardText()
            If clip_ptr <> 0 Then
                clip_str = *clip_ptr
                _VT_DRV_free(clip_ptr)

                ' TODO: simplify?

                ' SDL clipboard text is UTF-8; decode multi-byte sequences to CP437.
                ' CR / LF and unmappable codepoints are silently dropped.
                Dim pst_len As Long  = Len(clip_str)
                Dim pst_b0  As UByte
                Dim pst_b1  As UByte
                Dim pst_b2  As UByte
                Dim pst_cp  As Long
                pi = 0
                Do While pi < pst_len
                    pst_b0 = clip_str[pi]
                    If pst_b0 >= &h80 Then
                        ' multi-byte UTF-8 -- decode and map to CP437
                        pch = 0
                        If (pst_b0 And &hE0) = &hC0 AndAlso pi + 1 < pst_len Then
                            pst_b1 = clip_str[pi + 1]
                            pst_cp = ((CLng(pst_b0) And &h1F) Shl 6) Or (CLng(pst_b1) And &h3F)
                            pch = vt_internal_unicode_to_cp437_2t(pst_cp)
                            pi += 2
                        ElseIf (pst_b0 And &hF0) = &hE0 AndAlso pi + 2 < pst_len Then
                            pst_b1 = clip_str[pi + 1]
                            pst_b2 = clip_str[pi + 2]
                            pst_cp = ((CLng(pst_b0) And &h0F) Shl 12) _
                                  Or ((CLng(pst_b1) And &h3F) Shl 6) _
                                  Or  (CLng(pst_b2) And &h3F)
                            pch = vt_internal_unicode_to_cp437_3t(pst_cp)
                            pi += 3
                        Else
                            pi += 1 : Continue Do   ' stray byte: skip
                        End If
                        If pch < 32 Then Continue Do   ' unmappable (returned 0) or ctrl: skip
                    Else
                        pch = pst_b0
                        pi += 1
                        If pch < 32 OrElse pch = 127 Then Continue Do   ' CR/LF/ctrl: skip
                    End If
                    If Len(buf) < eff_max Then
                        If allowed = "" OrElse InStr(allowed, Chr(pch)) > 0 Then
                            buf  = Left(buf, epos) & Chr(pch) & Mid(buf, epos + 1)
                            epos += 1
                        End If
                    End If
                Loop
            End If
            Continue Do   ' redraw with pasted content before waiting for next key
        End If

        sc = VT_SCAN(k)
        ch = VT_CHAR(k)

        Select Case sc
            Case VT_KEY_ENTER
                Return buf

            Case VT_KEY_ESC
                ' restore initial content and leave screen clean
                blen = Len(initial)
                For ci = 0 To eff_max - 1
                    cell_ch = 32
                    If ci < blen Then cell_ch = initial[ci]
                    vt_set_cell(start_col + ci, start_row, cell_ch, _
                                vt_internal.clr_fg, vt_internal.clr_bg)
                Next ci
                vt_locate(start_row, start_col + blen)
                If cancelled <> 0 Then *cancelled = 1
                Return ""

            Case VT_KEY_LEFT
                If epos > 0 Then epos -= 1

            Case VT_KEY_RIGHT
                If epos < Len(buf) Then epos += 1

            Case VT_KEY_HOME
                epos = 0

            Case VT_KEY_END
                epos = Len(buf)

            Case VT_KEY_BKSP
                If epos > 0 Then
                    buf  = Left(buf, epos - 1) & Mid(buf, epos + 1)
                    epos -= 1
                End If

            Case VT_KEY_DEL
                If epos < Len(buf) Then
                    buf = Left(buf, epos) & Mid(buf, epos + 2)
                End If

            Case Else
                ' printable character -- insert at epos if room and allowed
                If ch >= 32 AndAlso Len(buf) < eff_max Then
                    If allowed = "" OrElse InStr(allowed, Chr(ch)) > 0 Then
                        buf  = Left(buf, epos) & Chr(ch) & Mid(buf, epos + 1)
                        epos += 1
                    End If
                End If

        End Select
    Loop
End Function 
