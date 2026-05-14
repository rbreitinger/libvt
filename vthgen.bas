' =============================================================================
' vthgen.bas  --  Generate .vth help file from annotated .bi / .bas sources
' Usage:  vthgen.exe <source_folder> [output.vth]
' Output: defaults to <folder_name>.vth in the current directory
'
' Source annotation syntax (inside '>>> ... '<<< blocks):
'   ':topic <name>       start a new topic
'   ':short <text>       one-line summary
'   ':group <name>       group for the index
'   ':syntax             begin syntax section
'   ':params             begin parameters section
'   ':notes              begin notes section (reflowed)
'   ':example            begin example section
'   ':see                begin see-also section (one topic per line)
'   'plain text          body paragraph text
'   real code line       verbatim, no leading ' required
' =============================================================================
#cmdline "-gen gcc -O 2"
#include once "dir.bi"

Const MAX_TOPICS  = 2048
Const MAX_GROUPS  = 128
Const MAX_FILES   = 1024
Const MAX_SUBDIRS = 256

' -----------------------------------------------------------------------
' Topic record
' -----------------------------------------------------------------------
Type gen_topic
    tname  As String
    tshort As String
    tgroup As String
    tbody  As String   ' section tags + body lines, Chr(10)-delimited
End Type

Dim Shared topics(MAX_TOPICS - 1) As gen_topic
Dim Shared ntopics As Long

Dim Shared grps(MAX_GROUPS - 1) As String
Dim Shared ngrps As Long

Dim Shared src_files(MAX_FILES - 1) As String
Dim Shared nfiles As Long

Dim Shared tidxs(MAX_TOPICS - 1) As Long

' -----------------------------------------------------------------------
' str_trim  --  strip leading/trailing whitespace
' -----------------------------------------------------------------------
Function str_trim(s As String) As String
    Dim ilft As Long = 1
    Dim irgt As Long = Len(s)
    Do While ilft <= irgt
        Dim ch As UByte = s[ilft - 1]
        If ch = 32 Or ch = 9 Or ch = 13 Then ilft += 1 Else Exit Do
    Loop
    Do While irgt >= ilft
        Dim ch As UByte = s[irgt - 1]
        If ch = 32 Or ch = 9 Or ch = 13 Then irgt -= 1 Else Exit Do
    Loop
    If ilft > irgt Then Return ""
    Return Mid(s, ilft, irgt - ilft + 1)
End Function

' -----------------------------------------------------------------------
' str_lower  --  ASCII lowercase (no locale dependency)
' -----------------------------------------------------------------------
Function str_lower(s As String) As String
    Dim r As String = s
    Dim i As Long
    For i = 1 To Len(r)
        Dim ch As UByte = r[i - 1]
        If ch >= 65 And ch <= 90 Then r[i - 1] = ch + 32
    Next
    Return r
End Function

' -----------------------------------------------------------------------
' add_grp  --  register a unique group name
' -----------------------------------------------------------------------
Sub add_grp(nm As String)
    Dim i As Long
    For i = 0 To ngrps - 1
        If grps(i) = nm Then Exit Sub
    Next
    If ngrps >= MAX_GROUPS Then
        Print "vthgen: group limit reached, skipping '" & nm & "'"
        Exit Sub
    End If
    grps(ngrps) = nm
    ngrps += 1
End Sub

' -----------------------------------------------------------------------
' store_topic  --  commit one completed topic to global array
' -----------------------------------------------------------------------
Sub store_topic(ByRef t As gen_topic, ByRef in_top As Byte)
    If in_top = 0 Or t.tname = "" Then Exit Sub
    ' strip leading blank lines that accumulate before first body text
    Do While Left(t.tbody, 1) = Chr(10)
        t.tbody = Mid(t.tbody, 2)
    Loop
    If t.tgroup = "" Then t.tgroup = "General"
    add_grp t.tgroup
    If ntopics >= MAX_TOPICS Then
        Print "vthgen: topic limit reached, skipping '" & t.tname & "'"
        in_top = 0
        Exit Sub
    End If
    topics(ntopics) = t
    ntopics += 1
    in_top = 0
End Sub

' -----------------------------------------------------------------------
' parse_file  --  extract all vthelp blocks from one source file
'
' Line classification inside a '>>> ... '<<< block:
'   starts with '  ->  strip the ', treat as vth content
'     starts with : after strip  ->  tag line
'     otherwise                  ->  plain body text
'   no leading '  ->  verbatim code line, append as-is
' -----------------------------------------------------------------------
Sub parse_file(fname As String)
    Dim fh As Long = FreeFile
    If Open(fname For Input As #fh) <> 0 Then
        Print "vthgen: cannot open '" & fname & "'"
        Exit Sub
    End If

    Dim in_block As Byte   = 0
    Dim in_top   As Byte   = 0
    Dim cur_tag  As String = ""
    Dim t        As gen_topic
    Dim fln      As String
    Dim content  As String
    Dim is_cmnt  As Byte
    Dim sppos    As Long
    Dim stag     As String
    Dim rest     As String

    Do While Not EOF(fh)
        Line Input #fh, fln

        ' --- Block boundary detection ---
        If in_block = 0 Then
            If str_trim(fln) = "'>>>" Then in_block = 1
            Continue Do
        End If

        If str_trim(fln) = "'<<<" Then
            in_block = 0
            store_topic t, in_top
            Continue Do
        End If

        Dim ftrim As String = str_trim(fln)

        ' --- Classify line ---
        If Left(ftrim, 1) = "'" Then
            content = Mid(ftrim, 2)   ' strip leading comment marker
            is_cmnt = 1
        Else
            content = fln           ' verbatim code line, keep as-is
            is_cmnt = 0
        End If

        ' --- Tag detection: only from comment lines starting with ':' ---
        If is_cmnt And Left(content, 1) = ":" Then
            sppos = InStr(2, content, " ")
            If sppos = 0 Then
                stag = str_lower(Mid(content, 2))
                rest = ""
            Else
                stag = str_lower(Mid(content, 2, sppos - 2))
                rest = str_trim(Mid(content, sppos + 1))
            End If

            ' :topic ends current topic and starts a new one
            If stag = "topic" Then
                store_topic t, in_top
                t.tname  = rest
                t.tshort = ""
                t.tgroup = ""
                t.tbody  = ""
                in_top   = 1
                cur_tag  = ""
                Continue Do
            End If

            If in_top = 0 Then Continue Do

            Select Case stag
            Case "short"
                t.tshort = rest
            Case "group"
                t.tgroup = rest
            Case "syntax", "params", "notes", "example", "see"
                t.tbody &= ":" & stag & Chr(10)
                cur_tag  = stag
            Case Else
                ' Unknown tag: store verbatim as body text
                t.tbody &= content & Chr(10)
            End Select

            Continue Do
        End If

        ' --- Plain body line (comment text or verbatim code) ---
        If in_top = 0 Then Continue Do
        t.tbody &= content & Chr(10)

    Loop

    ' end of file reached while inside a block -- store whatever we have
    store_topic t, in_top
    Close #fh
End Sub

' -----------------------------------------------------------------------
' collect_files  --  recursively gather .bi / .bas filenames
'
' Subdirectory names are snapshotted before any wildcard Dir() calls
' to avoid Dir() global-state conflicts between nested calls.
' -----------------------------------------------------------------------
Sub collect_files(folder As String)
    Dim subdirs(MAX_SUBDIRS - 1) As String
    Dim nsubdirs As Long = 0
    Dim entry    As String

    ' Snapshot all non-. / .. entries from the fbDirectory listing.
    ' Non-directory entries that sneak in are harmless: recursive calls
    ' on them simply return nothing from the *.bi / *.bas Dir() searches.
    entry = Dir(folder & "/*", fbDirectory)
    Do While entry <> ""
        If entry <> "." And entry <> ".." Then
            If nsubdirs < MAX_SUBDIRS Then
                subdirs(nsubdirs) = entry
                nsubdirs += 1
            End If
        End If
        entry = Dir()
    Loop

    ' Collect .bi files
    entry = Dir(folder & "/*.bi")
    Do While entry <> ""
        If nfiles < MAX_FILES Then
            src_files(nfiles) = folder & "/" & entry
            nfiles += 1
        End If
        entry = Dir()
    Loop

    ' Collect .bas files
    entry = Dir(folder & "/*.bas")
    Do While entry <> ""
        If nfiles < MAX_FILES Then
            src_files(nfiles) = folder & "/" & entry
            nfiles += 1
        End If
        entry = Dir()
    Loop

    ' Recurse into subdirectories
    Dim i As Long
    For i = 0 To nsubdirs - 1
        collect_files folder & "/" & subdirs(i)
    Next
End Sub

' -----------------------------------------------------------------------
' sort_grps  --  alphabetical insertion sort on grps(), case-insensitive
' -----------------------------------------------------------------------
Sub sort_grps()
    Dim i As Long, j As Long
    Dim tmp As String
    For i = 1 To ngrps - 1
        tmp = grps(i)
        j   = i - 1
        Do While j >= 0 AndAlso str_lower(grps(j)) > str_lower(tmp)
            grps(j + 1) = grps(j)
            j -= 1
        Loop
        grps(j + 1) = tmp
    Next
End Sub

' -----------------------------------------------------------------------
' get_grp_topics  --  fill tidxs() with topic indices for one group,
'                     sorted alphabetically by topic name.
'                     Returns count; caller declares tidxs() As Long.
' -----------------------------------------------------------------------
Function get_grp_topics(grp As String) As Long
    Dim cnt As Long = 0
    Dim i   As Long, j As Long
    Dim tmp As Long

    For i = 0 To ntopics - 1
        If topics(i).tgroup = grp Then cnt += 1
    Next
    If cnt = 0 Then Return 0

    cnt = 0
    For i = 0 To ntopics - 1
        If topics(i).tgroup = grp Then
            tidxs(cnt) = i
            cnt += 1
        End If
    Next

    ' Insertion sort by topic name, case-insensitive
    For i = 1 To cnt - 1
        tmp = tidxs(i)
        j   = i - 1
        Do While j >= 0 AndAlso str_lower(topics(tidxs(j)).tname) > str_lower(topics(tmp).tname)
            tidxs(j + 1) = tidxs(j)
            j -= 1
        Loop
        tidxs(j + 1) = tmp
    Next

    Return cnt
End Function

' -----------------------------------------------------------------------
' write_vth  --  emit sorted topics to the output file
' -----------------------------------------------------------------------
Sub write_vth(fname As String)
    Dim fh As Long = FreeFile
    If Open(fname For Output As #fh) <> 0 Then
        Print "vthgen: cannot create '" & fname & "'"
        Exit Sub
    End If

    Dim gi    As Long
    Dim tcnt  As Long
    Dim ti    As Long
    Dim idx   As Long
    Dim tbody As String
    Dim bpos  As Long
    Dim blen  As Long
    Dim eol   As Long
    Dim bln   As String

    For gi = 0 To ngrps - 1
        tcnt = get_grp_topics(grps(gi))
        For ti = 0 To tcnt - 1
            idx = tidxs(ti)

            Print #fh, ":topic " & topics(idx).tname
            If topics(idx).tshort <> "" Then
                Print #fh, ":short " & topics(idx).tshort
            End If
            Print #fh, ":group " & topics(idx).tgroup

            ' Write tbody line by line
            tbody = topics(idx).tbody
            blen  = Len(tbody)
            bpos  = 1
            Do While bpos <= blen
                eol = InStr(bpos, tbody, Chr(10))
                If eol = 0 Then
                    bln  = Mid(tbody, bpos)
                    bpos = blen + 1
                Else
                    bln  = Mid(tbody, bpos, eol - bpos)
                    bpos = eol + 1
                End If
                Print #fh, bln
            Loop

            Print #fh, ""   ' blank line between topics for readability
        Next
    Next

    Close #fh
    Print "vthgen: " & ntopics & " topics / " & ngrps & " groups -> '" & fname & "'"
End Sub

' -----------------------------------------------------------------------
' Entry point
' -----------------------------------------------------------------------
Dim src_folder As String = Command(1)
Dim out_file   As String = Command(2)

Print "vthgen: working dir  = " & CurDir()
Print "vthgen: source folder = '" & src_folder & "'"
Print "vthgen: output file   = '" & out_file & "'"

If src_folder = "" Then
    Print "vthgen -- vthelp source generator"
    Print "Usage:  vthgen <source_folder> [output.vth]"
    End 1
End If

' Strip trailing path separator
Do While Right(src_folder, 1) = "/" Or Right(src_folder, 1) = "\"
    src_folder = Left(src_folder, Len(src_folder) - 1)
Loop

' Default output: last path component + .vth
If out_file = "" Then
    Dim spos As Long = 0, si As Long
    For si = Len(src_folder) To 1 Step -1
        If Mid(src_folder, si, 1) = "/" Or Mid(src_folder, si, 1) = "\" Then
            spos = si : Exit For
        End If
    Next
    If spos > 0 Then
        out_file = Mid(src_folder, spos + 1) & ".vth"
    Else
        out_file = src_folder & ".vth"
    End If
End If

Print "vthgen: scanning '" & src_folder & "'..."
collect_files src_folder
Print "vthgen: " & nfiles & " file(s) found"

Dim fi As Long
For fi = 0 To nfiles - 1
    Print "vthgen:   " & src_files(fi)
    parse_file src_files(fi)
Next

Print "vthgen: " & ntopics & " topic(s) in " & ngrps & " group(s)"
sort_grps()
write_vth out_file
