' =============================================================================
' vt_strings.bas : opt-in String Utility Extension for libvt
' =============================================================================

'>>>
':topic vt_str_replace
':short Replace all occurrences of a substring
':group Strings
'Replace every non-overlapping occurrence of
'find in s with repl. Scanning advances past the
'replacement so overlapping matches are not
'produced. Returns s unchanged if find is empty.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_replace(s    As String, _
                        find As String, _
                        repl As String) As String
        ':params
        's     Source string.
        'find  Substring to search for. Empty = no-op.
        'repl  Replacement. May be empty to delete all.
        ':example
        'Dim fname As String = _
        '    vt_str_replace("hello world", " ", "_")
        '' fname = "hello_world"
        '
        'Dim stripped As String = _
        '    vt_str_replace("a--b--c", "--", "")
        '' stripped = "abc"
        ':see
        'vt_str_split
        'vt_str_count
    '<<<
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

'>>>
':topic vt_str_split
':short Split a string into an array by delimiter
':group Strings
'Split s by delim and fill arr() with the
'resulting segments. The array is ReDim'd by this
'function; the caller only needs to declare
'Dim arr() As String. Returns the number of
'elements produced. If delim is empty, each
'character becomes its own element. A trailing
'delimiter produces a final empty element.
'An empty s always returns one element of "".
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_split(s     As String, _
                      delim As String, _
                      arr() As String) As Long
        ':params
        's      Source string to split.
        'delim  Delimiter. Empty = split into characters.
        'arr()  Receives the segments. ReDim'd to
        '       0 To count-1.
        ':notes
        'Return: number of elements placed in arr().
        ':example
        'Dim parts() As String
        'Dim cnt As Long = _
        '    vt_str_split("one,two,three", ",", parts())
        '' cnt=3  parts(0)="one" parts(1)="two" ...
        'For i As Long = 0 To cnt - 1
        '    vt_print(parts(i) + VT_LF)
        'Next i
        ':see
        'vt_str_replace
        'vt_str_count
    '<<<
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

'>>>
':topic vt_str_pad_left
':short Right-align a string in a fixed-width field
':group Strings
'Right-align s in a field of exactly length
'characters by padding with ch on the left. If s
'is longer than length, the rightmost length
'characters are returned (truncation keeps the
'least-significant end, useful for numbers). Only
'the first character of ch is used; if ch is
'empty a space is substituted. Returns "" if
'length <= 0.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_pad_left(s      As String, _
                         length As Long, _
                         ch     As String) _
                         As String
        ':params
        's       Source string.
        'length  Desired output width in characters.
        'ch      Fill character. Only first char is used.
        ':example
        '' Zero-pad a score to 6 digits:
        'vt_print( vt_str_pad_left(Str(score), 6, "0") )
        '' "001450"
        ':see
        'vt_str_pad_right
    '<<<
    Dim slen    As Long
    Dim fill_ch As String

    If length <= 0 Then Return ""
    fill_ch = Left(ch, 1)
    If Len(fill_ch) = 0 Then fill_ch = " "
    slen = Len(s)
    If slen >= length Then Return Right(s, length)
    Return String(length - slen, fill_ch[0]) + s
End Function

'>>>
':topic vt_str_pad_right
':short Left-align a string in a fixed-width field
':group Strings
'Left-align s in a field of exactly length
'characters by padding with ch on the right. If
's is longer than length, the leftmost length
'characters are returned. Only the first character
'of ch is used; if ch is empty a space is
'substituted. Returns "" if length <= 0.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_pad_right(s      As String, _
                          length As Long,   _
                          ch     As String) _
                          As String
        ':params
        's       Source string.
        'length  Desired output width in characters.
        'ch      Fill character. Only first char is used.
        ':example
        '' Fixed label next to a value:
        'vt_print( vt_str_pad_right("SCORE", 10, " ") & _
        '          vt_str_pad_left(Str(score), 6, "0") )
        ':see
        'vt_str_pad_left
    '<<<
    Dim slen    As Long
    Dim fill_ch As String

    If length <= 0 Then Return ""
    fill_ch = Left(ch, 1)
    If Len(fill_ch) = 0 Then fill_ch = " "
    slen = Len(s)
    If slen >= length Then Return Left(s, length)
    Return s + String(length - slen, fill_ch[0])
End Function

'>>>
':topic vt_str_repeat
':short Repeat a string n times
':group Strings
'Return s concatenated n times. Returns "" for
'n <= 0 or an empty s. Single-character strings
'use FreeBASIC's String() internally for
'efficiency.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_repeat(s As String, _
                       n As Long) As String
        ':params
        's  String to repeat.
        'n  Number of repetitions. 0 or negative = "".
        ':example
        '' Draw a separator line:
        'vt_print(vt_str_repeat("-=", 20) & VT_LF)
        '
        '' Progress bar string:
        'Dim bar As String = "[" & _
        '    vt_str_repeat("#", filled) & _
        '    vt_str_repeat(".", empty_count) & "]"
        ':see
        'vt_str_pad_left
        'vt_str_pad_right
    '<<<
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

'>>>
':topic vt_str_count
':short Count non-overlapping occurrences of a substring
':group Strings
'Count non-overlapping occurrences of find in s.
'Returns 0 if either string is empty.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_count(s    As String, _
                      find As String) As Long
        ':params
        's     String to search in.
        'find  Substring to count. Empty = always 0.
        ':notes
        'Return: number of non-overlapping occurrences.
        '0 if none or if either argument is empty.
        ':example
        'Dim n As Long = vt_str_count("banana", "a")
        '' n = 3
        '
        'n = vt_str_count("banana", "an")
        '' n = 2  ("b[an][an]a")
        ':see
        'vt_str_replace
    '<<<
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

'>>>
':topic vt_str_starts_with
':short Test whether a string begins with a prefix
':group Strings
'Returns 1 if s begins with pfx, 0 otherwise.
'An empty pfx always returns 1.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_starts_with(s   As String, _
                            pfx As String) _
                            As Byte
        ':params
        's    String to test.
        'pfx  Expected prefix.
        ':example
        'If vt_str_starts_with(input_line, "/quit") Then
        '    end_game = 1
        'End If
        ':see
        'vt_str_ends_with
    '<<<
    Dim plen As Long
    plen = Len(pfx)
    If plen = 0 Then Return 1
    If plen > Len(s) Then Return 0
    If Left(s, plen) = pfx Then Return 1
    Return 0
End Function

'>>>
':topic vt_str_ends_with
':short Test whether a string ends with a suffix
':group Strings
'Returns 1 if s ends with sfx, 0 otherwise.
'An empty sfx always returns 1.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_ends_with(s   As String, _
                          sfx As String) _
                          As Byte
        ':params
        's    String to test.
        'sfx  Expected suffix.
        ':example
        'If vt_str_ends_with(filename, ".vts") Then
        '    vt_bload(filename)
        'End If
        ':see
        'vt_str_starts_with
    '<<<
    Dim sfx_len As Long
    Dim slen    As Long
    sfx_len = Len(sfx)
    slen    = Len(s)
    If sfx_len = 0 Then Return 1
    If sfx_len > slen Then Return 0
    If Right(s, sfx_len) = sfx Then Return 1
    Return 0
End Function

'>>>
':topic vt_str_trim_chars
':short Trim a custom character set from both ends
':group Strings
'Remove any character found in the set chars
'from both ends of s and return the result.
'FreeBASIC's built-in Trim only removes spaces;
'this function accepts any set of characters.
'Returns "" if s consists entirely of chars.
'Returns s unchanged if chars is empty.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_trim_chars(s     As String, _
                           chars As String) _
                           As String
        ':params
        's      Source string.
        'chars  Set of characters to strip. Each
        '       character is an individual candidate.
        ':example
        'Dim clean As String = _
        '    vt_str_trim_chars("***hello***", "*")
        '' clean = "hello"
        '
        'clean = vt_str_trim_chars("  ..hi.. ", " .")
        '' clean = "hi"
        ':see
        'vt_str_replace
    '<<<
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

'>>>
':topic vt_str_wordwrap
':short Insert line breaks for word-wrapping
':group Strings
'Insert Chr(10) line breaks into s so that no
'line exceeds col_width characters. Words are
'never split -- a word longer than col_width
'occupies its own line unbroken. Existing Chr(10)
'and Chr(13) characters are preserved and reset
'the line-length counter; CRLF pairs are collapsed
'to a single Chr(10). The return value is a plain
'string with embedded newlines -- pass it directly
'to vt_print. No screen required: col_width = -1
'falls back to 80 when no VT screen is open.
'Opt-in: define VT_USE_STRINGS before the include.
':syntax
Function vt_str_wordwrap(s            As String,    _
                         col_width    As Long = -1, _
                         first_offset As Long = 0)  _
                         As String
        ':params
        's             Source text to wrap.
        'col_width     Max line width. -1 uses screen
        '              width or 80 if no screen is open.
        'first_offset  Characters already consumed on
        '              the first line before this text.
        '              Subsequent lines always start at
        '              column 0.
        ':example
        'Dim msg As String = _
        '    "This item restores your health fully " & _
        '    "and also cures poison."
        'vt_print(vt_str_wordwrap(msg, 30))
        '
        '' Label already on same line:
        'vt_print("Description: ")
        'vt_print(vt_str_wordwrap(msg, 40, 13))
        ':see
        'vt_print
        'vt_cols
    '<<<
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
