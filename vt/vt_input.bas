' =============================================================================
' vt_input.bas : single-line blocking text editor                              
' =============================================================================

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
