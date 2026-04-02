' =============================================================================
' vt_input.bas - VT Virtual Text Screen Library
' vt_input : single-line blocking text editor
' =============================================================================

' -----------------------------------------------------------------------------
' vt_input - blocking single-line text input at current cursor position.
' max_len  : maximum input length. -1 = fill remaining columns on the row.
' initial  : pre-filled text. ESC restores this, leaves screen clean, returns "".
' allowed  : if non-empty, only characters in this string are accepted.
' cancelled: optional Byte Ptr. Set to 1 on ESC, 0 on Enter. Pass 0 to ignore.
' Uses current vt_color fg/bg throughout. Does not call vt_present directly.
' -----------------------------------------------------------------------------
Function vt_input(max_len As Long = -1, initial As String = "", _
                  allowed As String = "", cancelled As Byte Ptr = 0) As String
    If vt_internal.ready = 0 Then Return ""

    Dim start_col As Long
    Dim start_row As Long
    Dim eff_max   As Long
    Dim avail     As Long
    Dim buf       As String
    Dim epos      As Long    ' edit cursor, 0-based index into buf
    Dim k         As ULong
    Dim sc        As Long
    Dim ch        As UByte
    Dim ci        As Long
    Dim cell_ch   As UByte
    Dim blen      As Long

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

        ' --- wait for next key ---
        k  = vt_getkey()
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