' =============================================================================
' vt_strings.bas  --  String Utility Extension for libvt
' opt-in: #define VT_USE_STRINGS  before  #include once "vt/vt.bi"
' Pure FreeBASIC -- no SDL2 or open VT screen required.
' =============================================================================

' -----------------------------------------------------------------------------
' vt_str_replace - replace all non-overlapping occurrences of find in s with repl
' returns s unchanged if find is empty
' -----------------------------------------------------------------------------
Function vt_str_replace(s As String, find As String, repl As String) As String
    Dim result  As String
    Dim cur_pos As Long
    Dim found   As Long
    Dim flen    As Long

    flen = Len(find)
    If flen = 0 Then Return s

    result  = ""
    cur_pos = 1
    Do
        found = InStr(cur_pos, s, find)
        If found = 0 Then
            result += Mid(s, cur_pos)
            Exit Do
        End If
        result  += Mid(s, cur_pos, found - cur_pos)
        result  += repl
        cur_pos  = found + flen
    Loop

    Return result
End Function

' -----------------------------------------------------------------------------
' vt_str_split - split s by delim into arr(), returns element count
' arr() is ReDim'd by this function; caller declares  Dim arr() As String
' if delim is empty, each character of s becomes its own element
' a trailing delimiter produces a final empty element (e.g. "a,b," -> 3 items)
' -----------------------------------------------------------------------------
Function vt_str_split(s As String, delim As String, arr() As String) As Long
    Dim slen    As Long
    Dim dlen    As Long
    Dim cur_pos As Long
    Dim found   As Long
    Dim cnt     As Long

    slen = Len(s)
    dlen = Len(delim)

    If slen = 0 Then
        ReDim arr(0 To 0)
        arr(0) = ""
        Return 1
    End If

    If dlen = 0 Then
        ReDim arr(0 To slen - 1)
        For cnt = 0 To slen - 1
            arr(cnt) = Mid(s, cnt + 1, 1)
        Next cnt
        Return slen
    End If

    ' first pass: count segments
    cnt     = 0
    cur_pos = 1
    Do
        found = InStr(cur_pos, s, delim)
        If found = 0 Then Exit Do
        cnt    += 1
        cur_pos = found + dlen
    Loop
    cnt += 1    ' last segment (or only segment when no delim found)

    ReDim arr(0 To cnt - 1)

    ' second pass: fill segments
    cnt     = 0
    cur_pos = 1
    Do
        found = InStr(cur_pos, s, delim)
        If found = 0 Then
            arr(cnt) = Mid(s, cur_pos)
            Exit Do
        End If
        arr(cnt) = Mid(s, cur_pos, found - cur_pos)
        cnt     += 1
        cur_pos  = found + dlen
    Loop

    Return UBound(arr) + 1
End Function

' -----------------------------------------------------------------------------
' vt_str_pad_left - right-align s in a field of exactly length characters
' pads with ch on the left; if s is longer than length, keeps the right end
' ch is treated as a single character; if multi-char, only the first is used
' -----------------------------------------------------------------------------
Function vt_str_pad_left(s As String, length As Long, ch As String) As String
    Dim slen    As Long
    Dim fill_ch As String

    If length <= 0 Then Return ""
    fill_ch = Left(ch, 1)
    If Len(fill_ch) = 0 Then fill_ch = " "
    slen = Len(s)
    If slen >= length Then Return Right(s, length)
    Return String(length - slen, fill_ch[0]) + s
End Function

' -----------------------------------------------------------------------------
' vt_str_pad_right - left-align s in a field of exactly length characters
' pads with ch on the right; if s is longer than length, keeps the left end
' -----------------------------------------------------------------------------
Function vt_str_pad_right(s As String, length As Long, ch As String) As String
    Dim slen    As Long
    Dim fill_ch As String

    If length <= 0 Then Return ""
    fill_ch = Left(ch, 1)
    If Len(fill_ch) = 0 Then fill_ch = " "
    slen = Len(s)
    If slen >= length Then Return Left(s, length)
    Return s + String(length - slen, fill_ch[0])
End Function

' -----------------------------------------------------------------------------
' vt_str_repeat - repeat s exactly n times; returns "" for n <= 0 or empty s
' single-character strings use String() internally for efficiency
' -----------------------------------------------------------------------------
Function vt_str_repeat(s As String, n As Long) As String
    Dim result As String
    Dim slen   As Long
    Dim i      As Long

    slen = Len(s)
    If n <= 0 OrElse slen = 0 Then Return ""
    If slen = 1 Then Return String(n, s[0])
    result = ""
    For i = 1 To n
        result += s
    Next i
    Return result
End Function

' -----------------------------------------------------------------------------
' vt_str_count - count non-overlapping occurrences of find in s
' returns 0 if find is empty or s is empty
' -----------------------------------------------------------------------------
Function vt_str_count(s As String, find As String) As Long
    Dim cnt     As Long
    Dim cur_pos As Long
    Dim found   As Long
    Dim flen    As Long

    flen = Len(find)
    If flen = 0 OrElse Len(s) = 0 Then Return 0

    cnt     = 0
    cur_pos = 1
    Do
        found = InStr(cur_pos, s, find)
        If found = 0 Then Exit Do
        cnt    += 1
        cur_pos = found + flen
    Loop
    Return cnt
End Function

' -----------------------------------------------------------------------------
' vt_str_starts_with - returns 1 if s begins with pfx, 0 otherwise
' empty pfx always returns 1
' -----------------------------------------------------------------------------
Function vt_str_starts_with(s As String, pfx As String) As Byte
    Dim plen As Long
    plen = Len(pfx)
    If plen = 0 Then Return 1
    If plen > Len(s) Then Return 0
    If Left(s, plen) = pfx Then Return 1
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_str_ends_with - returns 1 if s ends with sfx, 0 otherwise
' empty sfx always returns 1
' -----------------------------------------------------------------------------
Function vt_str_ends_with(s As String, sfx As String) As Byte
    Dim sfx_len As Long
    Dim slen    As Long
    sfx_len = Len(sfx)
    slen    = Len(s)
    If sfx_len = 0 Then Return 1
    If sfx_len > slen Then Return 0
    If Right(s, sfx_len) = sfx Then Return 1
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_str_trim_chars - trim any character found in the chars set from both ends of s
' e.g. vt_str_trim_chars("***hello***", "*")  -> "hello"
'      vt_str_trim_chars("  ..hi.. ",  " .") -> "hi"
' returns "" if s consists entirely of characters in the chars set
' -----------------------------------------------------------------------------
Function vt_str_trim_chars(s As String, chars As String) As String
    Dim slen As Long
    Dim lft  As Long
    Dim rgt  As Long

    slen = Len(s)
    If slen = 0 OrElse Len(chars) = 0 Then Return s

    lft = 1
    Do While lft <= slen
        If InStr(chars, Mid(s, lft, 1)) = 0 Then Exit Do
        lft += 1
    Loop

    rgt = slen
    Do While rgt >= lft
        If InStr(chars, Mid(s, rgt, 1)) = 0 Then Exit Do
        rgt -= 1
    Loop

    If lft > rgt Then Return ""
    Return Mid(s, lft, rgt - lft + 1)
End Function

' -----------------------------------------------------------------------------
' vt_str_wordwrap - insert Chr(10) breaks so no line exceeds col_width characters
' col_width = -1: use vt_internal.scr_cols if screen is open, else fall back to 80
' first_offset: characters already consumed on the first line (e.g. after a label)
' existing Chr(10)/Chr(13) in s are preserved and reset the line counter
' words longer than col_width are placed on their own line unbroken
' -----------------------------------------------------------------------------
Function vt_str_wordwrap(s As String, col_width As Long = -1, first_offset As Long = 0) As String
    Dim eff_width     As Long
    Dim result        As String
    Dim cur_len       As Long
    Dim slen          As Long
    Dim i             As Long
    Dim wstart        As Long
    Dim wend_idx      As Long
    Dim wrd_len       As Long
    Dim cur_word      As String
    Dim ch            As UByte
    Dim at_line_start As Byte

    If col_width = -1 Then
        If vt_internal.ready Then
            eff_width = vt_internal.scr_cols
        Else
            eff_width = 80
        End If
    Else
        eff_width = col_width
    End If
    If eff_width < 1 Then eff_width = 1

    slen          = Len(s)
    result        = ""
    cur_len       = first_offset
    at_line_start = 1
    i             = 1

    Do While i <= slen
        ch = s[i - 1]

        ' pass through existing newlines and reset line state
        If ch = 13 Then
            If i < slen AndAlso s[i] = 10 Then i += 1     ' collapse CRLF
            result       += Chr(10)
            cur_len       = 0
            at_line_start = 1
            i            += 1
            Continue Do
        End If
        If ch = 10 Then
            result       += Chr(10)
            cur_len       = 0
            at_line_start = 1
            i            += 1
            Continue Do
        End If

        ' skip spaces between words
        If ch = 32 Then
            i += 1
            Continue Do
        End If

        ' scan to end of current word
        wstart   = i
        wend_idx = i
        Do While wend_idx <= slen
            ch = s[wend_idx - 1]
            If ch = 32 OrElse ch = 10 OrElse ch = 13 Then Exit Do
            wend_idx += 1
        Loop
        wend_idx -= 1

        cur_word = Mid(s, wstart, wend_idx - wstart + 1)
        wrd_len  = Len(cur_word)

        If at_line_start Then
            ' first word on this line -- no space prefix
            result       += cur_word
            cur_len      += wrd_len
            at_line_start = 0
        ElseIf cur_len + 1 + wrd_len <= eff_width Then
            ' word fits on the current line
            result  += " " + cur_word
            cur_len += 1 + wrd_len
        Else
            ' wrap: open a new line with this word
            result  += Chr(10) + cur_word
            cur_len  = wrd_len
        End If

        i = wend_idx + 1
    Loop

    Return result
End Function
