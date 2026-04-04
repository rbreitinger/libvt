' =============================================================================
' vt_bsave.bas - VT Virtual Text Screen Library
' vt_bsave / vt_bload -- save and load screen cell buffers to/from .vts files
' =============================================================================
'
' .vts file format:
'   bytes  0 -  3 : magic "VTBS"   (4 x UByte, no null terminator)
'   bytes  4 -  7 : cols           (Long, 4 bytes, little-endian)
'   bytes  8 - 11 : rows           (Long, 4 bytes, little-endian)
'   bytes 12+     : cell data      (cols * rows * 3 bytes, ch/fg/bg per cell,
'                                   left-to-right, top-to-bottom)
'
' Example sizes:
'   VT_SCREEN_0   80x25 : 12 + 6000  =  6012 bytes
'   VT_SCREEN_12  80x30 : 12 + 7200  =  7212 bytes
'   VT_SCREEN_VGA50 80x50: 12 + 12000 = 12012 bytes
'
' Both functions operate on the active work page (via vt_internal.cells),
' consistent with all other drawing commands.
'
' Return codes:
'   0  = ok
'  -1  = library not ready (call vt_screen first)
'  -2  = file could not be opened
'  -3  = bad magic -- not a .vts file
'  -4  = dimension mismatch -- file was saved in a different screen mode

' -----------------------------------------------------------------------------
' vt_bsave - save the work page to a .vts file
' -----------------------------------------------------------------------------
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

' -----------------------------------------------------------------------------
' vt_bload - load a .vts file into the work page
' Validates magic and screen dimensions before touching the cell buffer.
' Sets dirty on success so the next vt_present reflects the loaded content.
' -----------------------------------------------------------------------------
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
