' vth2html.bas
' Convert a .vth offline help file to a self-contained .html page.
' Usage: vth2html <input.vth> [output.html] [Page Title]
' ---------------------------------------------------------------

Const MAX_TOPICS As Long = 2000
Const MAX_GROUPS As Long =  100

' Section state IDs
Const SEC_BODY    As Long = 0
Const SEC_SYNTAX  As Long = 1
Const SEC_PARAMS  As Long = 2
Const SEC_NOTES   As Long = 3
Const SEC_EXAMPLE As Long = 4
Const SEC_SEE     As Long = 5

Type TopicRec
    t_id      As String
    t_short   As String
    t_grp     As String
    t_body    As String
    t_syntax  As String
    t_params  As String
    t_notes   As String
    t_example As String
    t_see     As String   ' newline-separated list
End Type

Dim Shared all_topics(MAX_TOPICS - 1) As TopicRec
Dim Shared topic_cnt                  As Long

Dim Shared all_groups(MAX_GROUPS - 1) As String
Dim Shared group_cnt                  As Long

' ---------------------------------------------------------------
' Escape HTML special characters
Function html_esc(byref s As String) As String
    Dim res As String = ""
    Dim ci  As Long
    Dim ch  As String * 1
    For ci = 1 To Len(s)
        ch = Mid(s, ci, 1)
        Select Case ch
            Case "&"     : res += "&amp;"
            Case "<"     : res += "&lt;"
            Case ">"     : res += "&gt;"
            Case Chr(34) : res += "&quot;"
            Case Else    : res += ch
        End Select
    Next ci
    Return res
End Function

' Strip trailing newlines / carriage returns
Function rstrip_nl(byref s As String) As String
    Return RTrim(s, Any Chr(10) & Chr(13))
End Function

' ---------------------------------------------------------------
' Parse .vth file -> all_topics()
Function parse_vth(byref fname As String) As Long
    Dim fh      As Long
    Dim ln      As String
    Dim tok     As String
    Dim rest    As String
    Dim sp      As Long
    Dim sec     As Long = SEC_BODY
    Dim tidx    As Long = -1
    Dim is_tok  As Long
    Dim sitem   As String

    fh = FreeFile()
    If Open(fname For Input As #fh) <> 0 Then
        Print "ERROR: Cannot open: " & fname
        Return -1
    End If

    Do While Not EOF(fh)
        Line Input #fh, ln
        ' Strip bare CR from Windows line endings
        If Len(ln) > 0 AndAlso Right(ln, 1) = Chr(13) Then
            ln = Left(ln, Len(ln) - 1)
        End If

        is_tok = 0

        If Len(ln) > 0 AndAlso Left(ln, 1) = ":" Then
            sp = InStr(ln, " ")
            If sp > 0 Then
                tok  = LCase(Left(ln, sp - 1))
                rest = Trim(Mid(ln, sp + 1))
            Else
                tok  = LCase(Trim(ln))
                rest = ""
            End If

            Select Case tok
                Case ":topic"
                    is_tok = 1
                    tidx  += 1
                    If tidx >= MAX_TOPICS Then
                        Print "ERROR: Too many topics (limit " & MAX_TOPICS & ")"
                        Close #fh
                        Return -2
                    End If
                    all_topics(tidx).t_id      = Trim(rest)
                    all_topics(tidx).t_short   = ""
                    all_topics(tidx).t_grp     = ""
                    all_topics(tidx).t_body    = ""
                    all_topics(tidx).t_syntax  = ""
                    all_topics(tidx).t_params  = ""
                    all_topics(tidx).t_notes   = ""
                    all_topics(tidx).t_example = ""
                    all_topics(tidx).t_see     = ""
                    sec = SEC_BODY

                Case ":short"
                    is_tok = 1
                    If tidx >= 0 Then all_topics(tidx).t_short = rest

                Case ":group"
                    is_tok = 1
                    If tidx >= 0 Then all_topics(tidx).t_grp = rest

                Case ":syntax"
                    is_tok = 1
                    sec = SEC_SYNTAX

                Case ":params"
                    is_tok = 1
                    sec = SEC_PARAMS

                Case ":notes"
                    is_tok = 1
                    sec = SEC_NOTES

                Case ":example"
                    is_tok = 1
                    sec = SEC_EXAMPLE

                Case ":see"
                    is_tok = 1
                    sec = SEC_SEE

                ' Unknown colon-token: fall through and treat as content
            End Select
        End If

        If is_tok = 0 AndAlso tidx >= 0 Then
            Select Case sec
                Case SEC_BODY    : all_topics(tidx).t_body    += ln & Chr(10)
                Case SEC_SYNTAX  : all_topics(tidx).t_syntax  += ln & Chr(10)
                Case SEC_PARAMS  : all_topics(tidx).t_params  += ln & Chr(10)
                Case SEC_NOTES   : all_topics(tidx).t_notes   += ln & Chr(10)
                Case SEC_EXAMPLE : all_topics(tidx).t_example += ln & Chr(10)
                Case SEC_SEE
                    sitem = Trim(ln)
                    If Len(sitem) > 0 Then
                        all_topics(tidx).t_see += sitem & Chr(10)
                    End If
            End Select
        End If
    Loop

    Close #fh
    topic_cnt = tidx + 1
    Return 0
End Function

' ---------------------------------------------------------------
' Collect unique group names from parsed topics
Sub collect_groups()
    Dim ti    As Long
    Dim gi    As Long
    Dim found As Long
    Dim gn    As String

    group_cnt = 0
    For ti = 0 To topic_cnt - 1
        gn = all_topics(ti).t_grp
        If Len(gn) = 0 Then gn = "(ungrouped)"
        found = 0
        For gi = 0 To group_cnt - 1
            If all_groups(gi) = gn Then
                found = 1
                Exit For
            End If
        Next gi
        If found = 0 Then
            If group_cnt < MAX_GROUPS Then
                all_groups(group_cnt) = gn
                group_cnt += 1
            End If
        End If
    Next ti
End Sub

' Insertion-sort group array alphabetically (case-insensitive)
Sub sort_groups()
    Dim ii  As Long
    Dim jj  As Long
    Dim tmp As String
    For ii = 1 To group_cnt - 1
        tmp = all_groups(ii)
        jj  = ii - 1
        Do While jj >= 0 AndAlso LCase(all_groups(jj)) > LCase(tmp)
            all_groups(jj + 1) = all_groups(jj)
            jj -= 1
        Loop
        all_groups(jj + 1) = tmp
    Next ii
End Sub

' ---------------------------------------------------------------
' Emit one <pre> block, skipping it entirely if content is blank
Sub emit_pre(fh As Long, byref content As String, css_cls As String)
    Dim stripped As String = rstrip_nl(content)
    If Len(Trim(stripped)) = 0 Then Exit Sub
    Print #fh, "<pre class=""" & css_cls & """>" & html_esc(stripped) & "</pre>"
End Sub

' ---------------------------------------------------------------
' Write the HTML output file
Function write_html(byref outfname As String, byref page_title As String) As Long
    Dim fh      As Long
    Dim gi      As Long
    Dim ti      As Long
    Dim si      As Long
    Dim ii      As Long
    Dim jj      As Long
    Dim gn      As String
    Dim see_s   As String
    Dim see_pos As Long
    Dim see_nxt As Long
    Dim see_it  As String
    Dim tmp_i   As Long

    ' Reusable per-group topic index (declared outside loop)
    Dim gtopics(MAX_TOPICS - 1) As Long
    Dim gcnt    As Long

    fh = FreeFile()
    If Open(outfname For Output As #fh) <> 0 Then
        Print "ERROR: Cannot write: " & outfname
        Return -1
    End If

    ' ---- HTML head ------------------------------------------------
    Print #fh, "<!DOCTYPE html>"
    Print #fh, "<html lang=""en"">"
    Print #fh, "<head>"
    Print #fh, "<meta charset=""UTF-8"">"
    Print #fh, "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"
    Print #fh, "<title>" & html_esc(page_title) & "</title>"
    Print #fh, "<style>"
    Print #fh, "* { box-sizing: border-box; margin: 0; padding: 0; }"
    Print #fh, "body { font-family: monospace; font-size: 14px; background: #fff; color: #111; }"
    Print #fh, "#wrap { display: flex; height: 100vh; overflow: hidden; }"
    Print #fh, ""
    Print #fh, "/* --- left nav --- */"
    Print #fh, "#nav { width: 220px; min-width: 220px; overflow-y: auto;"
    Print #fh, "       border-right: 2px solid #aaa; padding: 6px 4px;"
    Print #fh, "       background: #f5f5f5; }"
    Print #fh, ".grp-hdr { font-weight: bold; color: #222; font-size: 12px;"
    Print #fh, "           margin-top: 12px; margin-bottom: 2px;"
    Print #fh, "           padding-bottom: 2px; border-bottom: 1px solid #bbb; }"
    Print #fh, ".grp-hdr:first-child { margin-top: 4px; }"
    Print #fh, "a.tlnk { display: block; color: #0044cc; text-decoration: none;"
    Print #fh, "         padding: 1px 0 1px 10px; font-size: 13px; }"
    Print #fh, "a.tlnk:hover { text-decoration: underline; color: #002288; }"
    Print #fh, ""
    Print #fh, "/* --- right pane --- */"
    Print #fh, "#pane { flex: 1; overflow-y: auto; padding: 18px 24px; }"
    Print #fh, ".tdiv { display: none; }"
    Print #fh, "h2 { font-size: 16px; border-bottom: 1px solid #aaa;"
    Print #fh, "     padding-bottom: 4px; margin-bottom: 6px; }"
    Print #fh, ".t-short { color: #555; font-style: italic; margin-bottom: 10px; }"
    Print #fh, ".sec-hdr { font-weight: bold; color: #333; font-size: 13px;"
    Print #fh, "           margin-top: 14px; margin-bottom: 4px; }"
    Print #fh, "pre.body-pre  { white-space: pre-wrap; margin-bottom: 10px; }"
    Print #fh, "pre.code-pre  { background: #f0f0f0; border: 1px solid #ccc;"
    Print #fh, "                padding: 8px 10px; overflow-x: auto;"
    Print #fh, "                margin-bottom: 8px; }"
    Print #fh, "pre.param-pre { background: #fafafa; border: 1px solid #ddd;"
    Print #fh, "                padding: 8px 10px; overflow-x: auto;"
    Print #fh, "                margin-bottom: 8px; }"
    Print #fh, ".see-list a { display: block; color: #0044cc;"
    Print #fh, "              text-decoration: none; padding: 1px 0; }"
    Print #fh, ".see-list a:hover { text-decoration: underline; }"
    Print #fh, "#welcome { color: #777; margin-top: 30px; }"
    Print #fh, "</style>"

    ' ---- JS: show one topic div, hide all others -----------------
    Print #fh, "<script>"
    Print #fh, "function show(id) {"
    Print #fh, "    document.getElementById('welcome').style.display = 'none';"
    Print #fh, "    var ds = document.getElementsByClassName('tdiv');"
    Print #fh, "    for (var i = 0; i < ds.length; i++) ds[i].style.display = 'none';"
    Print #fh, "    document.getElementById(id).style.display = 'block';"
    Print #fh, "    document.getElementById('pane').scrollTop = 0;"
    Print #fh, "}"
    Print #fh, "</script>"
    Print #fh, "</head>"
    Print #fh, "<body>"
    Print #fh, "<div id=""wrap"">"

    ' ---- Left navigation pane ------------------------------------
    Print #fh, "<div id=""nav"">"
    For gi = 0 To group_cnt - 1
        gn = all_groups(gi)

        ' Collect topics belonging to this group
        gcnt = 0
        For ti = 0 To topic_cnt - 1
            Dim tg As String = all_topics(ti).t_grp
            If Len(tg) = 0 Then tg = "(ungrouped)"
            If tg = gn Then
                gtopics(gcnt) = ti
                gcnt += 1
            End If
        Next ti

        ' Insertion-sort topics within group by id (case-insensitive)
        For ii = 1 To gcnt - 1
            tmp_i = gtopics(ii)
            jj    = ii - 1
            Do While jj >= 0 AndAlso _
                     LCase(all_topics(gtopics(jj)).t_id) > LCase(all_topics(tmp_i).t_id)
                gtopics(jj + 1) = gtopics(jj)
                jj -= 1
            Loop
            gtopics(jj + 1) = tmp_i
        Next ii

        Print #fh, "<div class=""grp-hdr"">" & html_esc(gn) & "</div>"
        For si = 0 To gcnt - 1
            ti = gtopics(si)
            Dim tid As String = all_topics(ti).t_id
            Print #fh, "<a class=""tlnk"" href=""#"" " & _
                        "onclick=""show('" & html_esc(tid) & "');return false;"">" & _
                        html_esc(tid) & "</a>"
        Next si
    Next gi
    Print #fh, "</div>"   ' #nav

    ' ---- Right content pane --------------------------------------
    Print #fh, "<div id=""pane"">"
    Print #fh, "<div id=""welcome"">Select a topic from the left panel.</div>"

    For ti = 0 To topic_cnt - 1
        Print #fh, "<div class=""tdiv"" id=""" & html_esc(all_topics(ti).t_id) & """>"

        ' Heading + short description
        Print #fh, "<h2>" & html_esc(all_topics(ti).t_id) & "</h2>"
        If Len(Trim(all_topics(ti).t_short)) > 0 Then
            Print #fh, "<div class=""t-short"">" & html_esc(Trim(all_topics(ti).t_short)) & "</div>"
        End If

        ' Body text
        emit_pre(fh, all_topics(ti).t_body, "body-pre")

        ' Syntax
        If Len(Trim(all_topics(ti).t_syntax)) > 0 Then
            Print #fh, "<div class=""sec-hdr"">Syntax</div>"
            emit_pre(fh, all_topics(ti).t_syntax, "code-pre")
        End If

        ' Parameters
        If Len(Trim(all_topics(ti).t_params)) > 0 Then
            Print #fh, "<div class=""sec-hdr"">Parameters</div>"
            emit_pre(fh, all_topics(ti).t_params, "param-pre")
        End If

        ' Notes
        If Len(Trim(all_topics(ti).t_notes)) > 0 Then
            Print #fh, "<div class=""sec-hdr"">Notes</div>"
            emit_pre(fh, all_topics(ti).t_notes, "body-pre")
        End If

        ' Example
        If Len(Trim(all_topics(ti).t_example)) > 0 Then
            Print #fh, "<div class=""sec-hdr"">Example</div>"
            emit_pre(fh, all_topics(ti).t_example, "code-pre")
        End If

        ' See also
        see_s = Trim(all_topics(ti).t_see)
        If Len(see_s) > 0 Then
            Print #fh, "<div class=""sec-hdr"">See Also</div>"
            Print #fh, "<div class=""see-list"">"
            see_pos = 1
            Do
                see_nxt = InStr(see_pos, see_s, Chr(10))
                If see_nxt > 0 Then
                    see_it  = Trim(Mid(see_s, see_pos, see_nxt - see_pos))
                    see_pos = see_nxt + 1
                Else
                    see_it  = Trim(Mid(see_s, see_pos))
                    see_pos = 0
                End If
                If Len(see_it) > 0 Then
                    Print #fh, "<a href=""#"" onclick=""show('" & html_esc(see_it) & _
                                "');return false;"">" & html_esc(see_it) & "</a>"
                End If
            Loop While see_pos > 0
            Print #fh, "</div>"
        End If

        Print #fh, "</div>"   ' .tdiv
    Next ti

    Print #fh, "</div>"   ' #pane
    Print #fh, "</div>"   ' #wrap
    Print #fh, "</body>"
    Print #fh, "</html>"

    Close #fh
    Return 0
End Function

' ==============================================================
' Entry point
' ==============================================================
Dim in_file  As String
Dim out_file As String
Dim pg_title As String
Dim dot_p    As Long
Dim res      As Long

If Command(1) = "" Then
    Print "Usage: vth2html <input.vth> [output.html] [""Page Title""]"
    End 1
End If

in_file = Command(1)

If Command(2) <> "" Then
    out_file = Command(2)
Else
    dot_p = InStrRev(in_file, ".")
    If dot_p > 0 Then
        out_file = Left(in_file, dot_p - 1) & ".html"
    Else
        out_file = in_file & ".html"
    End If
End If

If Command(3) <> "" Then
    pg_title = Command(3)
Else
    ' Derive title from input filename stem
    dot_p = InStrRev(in_file, ".")
    Dim slash_p As Long = InStrRev(in_file, "/")
    Dim bsl_p   As Long = InStrRev(in_file, "\")
    If bsl_p > slash_p Then slash_p = bsl_p
    Dim stem_start As Long = slash_p + 1
    Dim stem_end   As Long
    If dot_p > stem_start Then
        stem_end = dot_p - 1
    Else
        stem_end = Len(in_file)
    End If
    pg_title = Mid(in_file, stem_start, stem_end - stem_start + 1) & " Reference"
End If

Print "Parsing  : " & in_file
res = parse_vth(in_file)
If res <> 0 Then End 1

Print "Topics   : " & topic_cnt
collect_groups()
sort_groups()
Print "Groups   : " & group_cnt
Print "Writing  : " & out_file & "  [" & pg_title & "]"

res = write_html(out_file, pg_title)
If res <> 0 Then End 1

Print "Done."
End 0
