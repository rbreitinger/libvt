' =============================================================================
' ex_strings.bas  --  demonstration of the vt_strings extension
' =============================================================================
#define VT_USE_STRINGS
#include once "../vt/vt.bi"

' -----------------------------------------------------------------------------
' helper: print "any key to continue" and wait
' -----------------------------------------------------------------------------
sub wait_for_key()
    vt_print VT_NEWLINE
    vt_print_center(vt_csrlin(), "-Any key to continue-") 
    vt_print VT_NEWLINE
    vt_sleep()
end sub

' -----------------------------------------------------------------------------
' helper: print a section header
' -----------------------------------------------------------------------------
Sub print_header(title As String)
    vt_color 11, 0
    vt_print !"\n  " + String(Len(title) + 4, "-") + !"\n"
    vt_print "  " + title
    vt_print !"\n  " + String(Len(title) + 4, "-") + !"\n"
    vt_color 7, 0
End Sub

' -----------------------------------------------------------------------------
' helper: print a labelled result row
' -----------------------------------------------------------------------------
Sub print_result(label As String, value As String)
    vt_color 14, 0
    vt_print "  " + vt_str_pad_right(label, 26, " ")
    vt_color 15, 0
    vt_print value + !"\n"
    vt_color 7, 0
End Sub

' =============================================================================
' main
' =============================================================================
vt_screen VT_SCREEN_0    ' 80x25

vt_color 10, 0
vt_print !"  vt_strings extension demo\n"
vt_color 8, 0
vt_print "  " + String(78, "-") + !"\n"

' ---------------------------------------------------------------------------
' vt_str_replace
' ---------------------------------------------------------------------------
print_header "vt_str_replace"
Dim rs As String = "the cat sat on the mat"
print_result "original:", rs
print_result "replace 'at' with '@':", vt_str_replace(rs, "at", "@")
print_result "replace 'the' with 'a':", vt_str_replace(rs, "the", "a")
print_result "empty find (no-op):", vt_str_replace(rs, "", "X")
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_split
' ---------------------------------------------------------------------------
print_header "vt_str_split"
Dim tokens() As String
Dim tok_cnt  As Long
tok_cnt = vt_str_split("one,two,three,four", ",", tokens())
vt_color 14, 0
vt_print "  split 'one,two,three,four' on ','"
vt_color 15, 0
vt_print !"  -> " & tok_cnt & " elements: "
Dim ti As Long
For ti = 0 To tok_cnt - 1
    If ti > 0 Then vt_print " | "
    vt_print tokens(ti)
Next ti
vt_print !"\n"
vt_color 7, 0
wait_for_key()

' trailing delimiter test
tok_cnt = vt_str_split("a:b:c:", ":", tokens())
vt_color 14, 0
vt_print "  split 'a:b:c:' (trailing delim)"
vt_color 15, 0
vt_print !"  -> " & tok_cnt & " elements (last is empty)\n"
vt_color 7, 0
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_pad_left / vt_str_pad_right
' ---------------------------------------------------------------------------
print_header "vt_str_pad_left / vt_str_pad_right"
Dim score_lbl  As String = "SCORE"
Dim score_val  As String = "9800"
print_result "pad_left  'hi'  10 '.':", "[" + vt_str_pad_left("hi",   10, ".") + "]"
print_result "pad_right 'hi'  10 '.':", "[" + vt_str_pad_right("hi",  10, ".") + "]"
print_result "pad_left  score  6 '0':", vt_str_pad_left(score_val, 6, "0")
print_result "truncate  right  4 '.':", "[" + vt_str_pad_right("toolongstring", 4, ".") + "]"
print_result "score label col:", vt_str_pad_right(score_lbl, 10, " ") + vt_str_pad_left(score_val, 6, "0")
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_repeat
' ---------------------------------------------------------------------------
print_header "vt_str_repeat"
print_result "repeat '-=' 5 times:", vt_str_repeat("-=", 5)
print_result "repeat '*'  8 times:", vt_str_repeat("*", 8)
print_result "repeat anything 0x: :", "[" + vt_str_repeat("x", 0) + "]"
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_count
' ---------------------------------------------------------------------------
print_header "vt_str_count"
Dim cs As String = "banana"
print_result "count 'an' in 'banana':", Str(vt_str_count(cs, "an"))
print_result "count 'a'  in 'banana':", Str(vt_str_count(cs, "a"))
print_result "count 'x'  in 'banana':", Str(vt_str_count(cs, "x"))
print_result "count ''   in 'banana':", Str(vt_str_count(cs, ""))
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_starts_with / vt_str_ends_with
' ---------------------------------------------------------------------------
print_header "vt_str_starts_with / vt_str_ends_with"
Dim sw_s As String = "FreeBASIC"
print_result "'FreeBASIC' starts 'Free':", Str(vt_str_starts_with(sw_s, "Free"))
print_result "'FreeBASIC' starts 'BASIC':", Str(vt_str_starts_with(sw_s, "BASIC"))
print_result "'FreeBASIC' ends   'BASIC':", Str(vt_str_ends_with(sw_s, "BASIC"))
print_result "'FreeBASIC' ends   'Free':", Str(vt_str_ends_with(sw_s, "Free"))
print_result "empty prefix (always 1):", Str(vt_str_starts_with(sw_s, ""))
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_trim_chars
' ---------------------------------------------------------------------------
print_header "vt_str_trim_chars"
print_result "trim '*' from '***hi***':", vt_str_trim_chars("***hi***", "*")
print_result "trim ' .' from '  ..hi.. ':", "[" + vt_str_trim_chars("  ..hi.. ", " .") + "]"
print_result "trim all chars -> empty:", "[" + vt_str_trim_chars("!!!!", "!") + "]"
print_result "empty chars (no-op):", vt_str_trim_chars("  hello  ", "")
wait_for_key()

' ---------------------------------------------------------------------------
' vt_str_wordwrap
' ---------------------------------------------------------------------------
print_header "vt_str_wordwrap"
Dim long_txt As String
Dim wrapped  As String
long_txt = "This is a longer sentence that should be broken across multiple lines automatically."

vt_color 14, 0
vt_print !"  wrapping at col_width=40:\n"
vt_color 15, 0
wrapped = vt_str_wordwrap(long_txt, 40)
' indent each line by 2 for display
vt_print "  " + vt_str_replace(wrapped, Chr(10), !"\n  ") + !"\n"

vt_color 14, 0
vt_print !"  wrapping at col_width=40, first_offset=12:\n"
vt_color 15, 0
vt_print "  Label here: "
wrapped = vt_str_wordwrap(long_txt, 40, 12)
vt_print vt_str_replace(wrapped, Chr(10), !"\n  ") + !"\n"

vt_color 14, 0
vt_print !"  col_width=-1 (uses screen width 80):\n"
vt_color 15, 0
wrapped = vt_str_wordwrap(long_txt)
vt_print "  " + wrapped + !"\n"

' ---------------------------------------------------------------------------
' done
' ---------------------------------------------------------------------------
vt_color 8, 0
vt_print !"\n  " + String(78, "-") + !"\n"
vt_color 7, 0
vt_print !"  press any key to exit\n"
vt_sleep 0
vt_shutdown