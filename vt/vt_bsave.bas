' =============================================================================
' vt_bsave.bas : save and load screen cell buffers to/from .vts files
' =============================================================================
Function vt_bsave(fname As String) As Long
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

Function vt_bload(fname As String) As Long
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
