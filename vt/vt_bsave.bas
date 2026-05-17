' =============================================================================
' vt_bsave.bas : save and load screen cell buffers to/from .vts files          
' =============================================================================

'>>>
    ':topic vt_bsave
    ':short Save the work page to a .vts file
    ':group File I/O
    'Save the active work page to a .vts file. Unaffected by any viewport. Always saves the full screen. Created or overwritten.
':syntax
Function vt_bsave(fname As String) As Long
        ':params
        'fname  Destination file path. Created or overwritten if it exists.
        ':notes
        'Return values:
        '   0  success
        '  -1  library not ready (call vt_screen first)
        '  -2  file could not be opened for writing
        ':example
        'If vt_bsave("savegame.vts") <> 0 Then
        '    vt_print("Save failed!" & VT_LF)
        'End If
        ':see
        'vt_bload
    '<<<
    If vt_internal.ready = 0 Then Return -1

    Dim fh    As Long
    Dim cols  As Long
    Dim rows  As Long
    Dim ci    As Long
    Dim magic As String * 4

    cols  = vt_internal.scr_cols
    rows  = vt_internal.scr_rows
    magic = "VTBS"

    fh = FreeFile()
    If Open(fname For Binary As #fh) <> 0 Then Return -2

    Put #fh, , magic
    Put #fh, , cols
    Put #fh, , rows

    For ci = 0 To cols * rows - 1
        Put #fh, , vt_internal.cells[ci].ch
        Put #fh, , vt_internal.cells[ci].fg
        Put #fh, , vt_internal.cells[ci].bg
    Next ci

    Close #fh
    Return 0
End Function

'>>>
':topic vt_bload
':short Load a .vts screen file into the work page
':group File I/O
'Load a .vts file into the active work page. Validates the magic and screen dimensions before touching the cell buffer. Sets the display dirty
'on success so the next vt_present reflects the loaded content. Unaffected by any viewport - always loads the full screen.
'
':syntax
Function vt_bload(fname As String) As Long
        ':params
        'fname  Path to the .vts file to load.
        ':notes
        'Return values:
        '   0  success
        '  -1  library not ready (call vt_screen first)
        '  -2  file could not be opened
        '  -3  bad magic -- not a valid .vts file
        '  -4  dimension mismatch (different screen mode)
        '
        'The .vts format:
        '   4-byte magic "VTBS"
        '   4-byte cols
        '   4-byte rows (all little-endian Long),
        '   followed by cols x rows x 3 bytes (ch, fg, bg per cell, left-to-right, top-to-bottom).
        ':example
        'If vt_file_exists("savegame.vts") Then
        '    If vt_bload("savegame.vts") = 0 Then
        '        vt_present()
        '    End If
        'End If
        ':see
        'vt_bsave
        'vt_file_exists
    '<<<
    If vt_internal.ready = 0 Then Return -1

    Dim fh    As Long
    Dim cols  As Long
    Dim rows  As Long
    Dim ci    As Long
    Dim magic As String * 4

    fh = FreeFile()
    If Open(fname For Binary As #fh) <> 0 Then Return -2

    Get #fh, , magic
    If magic <> "VTBS" Then Close #fh : Return -3

    Get #fh, , cols
    Get #fh, , rows
    If cols <> vt_internal.scr_cols OrElse rows <> vt_internal.scr_rows Then
        Close #fh
        Return -4
    End If

    For ci = 0 To cols * rows - 1
        Get #fh, , vt_internal.cells[ci].ch
        Get #fh, , vt_internal.cells[ci].fg
        Get #fh, , vt_internal.cells[ci].bg
    Next ci

    Close #fh
    vt_internal.dirty = 1
    Return 0
End Function
