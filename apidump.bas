' ============================================================
' apidump.bas  -  Public API scanner for libvt
'
' Scans .bas files  : vt_* subs/functions (skips vt_internal_*)
'                     VT_* consts, #define
'                     Enum / End Enum blocks
' Scans vt.bi       : VT_* consts, #define, #macro blocks
'                     Enum / End Enum blocks
'                     + Declare Sub/Function vt_*
'
' Usage:
'   apidump                   scan *.bas + vt.bi in ./
'   apidump path/to/src       scan *.bas + vt.bi in path/
'
' Output: libvt_api_dump.txt
' ============================================================

#include "file.bi"
#include "dir.bi"

Const OUT_FILE   = "libvt_api_dump.txt"
Const BI_NAME    = "vt.bi"

' ============================================================
'  String helpers
' ============================================================

Function strTrim(src As String) As String
    Dim i  As Long
    Dim j  As Long
    Dim ch As String
    i = 1
    j = Len(src)
    Do While i <= j
        ch = Mid(src, i, 1)
        If ch = " " Or ch = Chr(9) Then i += 1 Else Exit Do
    Loop
    Do While j >= i
        ch = Mid(src, j, 1)
        If ch = " " Or ch = Chr(9) Then j -= 1 Else Exit Do
    Loop
    If i > j Then Return ""
    Return Mid(src, i, j - i + 1)
End Function

Function strStartsWith(src As String, pfx As String) As Byte
    Dim n As Long
    n = Len(pfx)
    If Len(src) < n Then Return 0
    If LCase(Left(src, n)) = LCase(pfx) Then Return 1
    Return 0
End Function

' strip trailing ' comment (respects quoted strings)
Function stripComment(src As String) As String
    Dim in As Byte
    Dim i     As Long
    Dim ch    As String
    in = 0
    For i = 1 To Len(src)
        ch = Mid(src, i, 1)
        If ch = Chr(34) Then
            in = 1 - in
        ElseIf ch = "'" And in = 0 Then
            Return Left(src, i - 1)
        End If
    Next i
    Return src
End Function

' join FreeBASIC continuation lines (trailing _)
' fh must be the same open file handle the caller is reading
Function readLogicalLine(fh As Long, firstLn As String) As String
    Dim cur     As String
    Dim trimmed As String
    Dim nxtLn   As String
    cur = firstLn
    Do
        trimmed = strTrim(stripComment(cur))
        If Right(trimmed, 1) <> "_" Then Exit Do
        If EOF(fh) Then Exit Do
        cur = Left(trimmed, Len(trimmed) - 1)   ' drop trailing _
        Line Input #fh, nxtLn
        cur = strTrim(cur) & " " & strTrim(nxtLn)
    Loop
    Return cur
End Function

' ============================================================
'  .bas scanner - public vt_* subs/functions
'               + VT_* consts, #define
'               + Enum / End Enum blocks
' ============================================================

Sub scanBas(filename As String, outFH As Long, ByRef totalFns As Long)
    Dim fh       As Long
    Dim rawLn    As String
    Dim trimmed  As String
    Dim lnlow    As String
    Dim logLn    As String
    Dim checkLn  As String
    Dim nameOff  As Long
    Dim nameLow  As String
    Dim isSub    As Byte
    Dim isFn     As Byte

    Dim constBuf As String
    Dim defBuf   As String
    Dim enumBuf  As String

    Dim cnt      As Long
    Dim cntConst As Long
    Dim cntDef   As Long
    Dim cntEnum  As Long
    Dim inEnum   As Byte

    cnt      = 0 : cntConst = 0 : cntDef = 0 : cntEnum = 0
    inEnum   = 0
    constBuf = "" : defBuf = "" : enumBuf = ""
    fh       = FreeFile()

    If Open(filename For Input As #fh) <> 0 Then
        Print "  [!] cannot open: "; filename
        Print #outFH, "    [!] cannot open: " & filename
        Exit Sub
    End If

    Print "  bas: "; filename
    Print #outFH, "  [" & filename & "]"

    Do While Not EOF(fh)
        Line Input #fh, rawLn
        trimmed = strTrim(rawLn)
        lnlow   = LCase(trimmed)

        ' skip blank lines and comments fast
        If Len(trimmed) = 0 Then Continue Do
        If Left(trimmed, 1) = "'" Then Continue Do

        ' ---- inside Enum block: capture until End Enum ----
        If inEnum Then
            enumBuf &= "      " & trimmed & Chr(10)
            If strStartsWith(lnlow, "end enum") Then
                enumBuf &= Chr(10)    ' blank line between blocks
                inEnum = 0
            End If
            Continue Do
        End If

        ' ---- Const VT_* ----
        If strStartsWith(lnlow, "const vt_") Then
            logLn    = strTrim(stripComment(readLogicalLine(fh, trimmed)))
            constBuf &= "    " & logLn & Chr(10)
            cntConst += 1
            Continue Do
        End If

        ' ---- #define VT_* ----
        If strStartsWith(lnlow, "#define vt_") Then
            defBuf &= "    " & trimmed & Chr(10)
            cntDef  += 1
            Continue Do
        End If

        ' ---- Enum / End Enum block ----
        If lnlow = "enum" Or strStartsWith(lnlow, "enum ") Then
            enumBuf &= "    " & trimmed & Chr(10)
            cntEnum += 1
            inEnum   = 1
            Continue Do
        End If

        ' skip Private anything
        If strStartsWith(lnlow, "private ") Then Continue Do

        ' skip Declare (forward declarations, not definitions)
        If strStartsWith(lnlow, "declare ") Then Continue Do

        ' peel optional Public keyword
        checkLn = lnlow
        If strStartsWith(checkLn, "public ") Then
            checkLn = strTrim(Mid(checkLn, 8))
        End If

        isSub = strStartsWith(checkLn, "sub ")
        isFn  = strStartsWith(checkLn, "function ")

        If isSub = 0 And isFn = 0 Then Continue Do

        ' extract the function/sub name (first token after keyword)
        If isSub Then nameOff = 5 Else nameOff = 10
        nameLow = LCase(strTrim(Mid(checkLn, nameOff)))

        ' public vt_* but not vt_internal_*
        If strStartsWith(nameLow, "vt_") = 0 Then Continue Do
        If strStartsWith(nameLow, "vt_internal_") Then Continue Do

        ' collect full signature across continuation lines
        logLn = strTrim(stripComment(readLogicalLine(fh, trimmed)))

        Print #outFH, "    " & logLn
        cnt      += 1
        totalFns += 1
    Loop

    Close #fh

    If cnt = 0 Then Print #outFH, "    (none)"
    Print #outFH, ""

    ' ---- VT_* constants from this .bas ----
    If cntConst > 0 Then
        Print #outFH, "  -- Constants (" & cntConst & ") --"
        Print #outFH, constBuf
    End If

    ' ---- #define VT_* from this .bas ----
    If cntDef > 0 Then
        Print #outFH, "  -- Defines (" & cntDef & ") --"
        Print #outFH, defBuf
        Print #outFH, ""
    End If

    ' ---- Enum blocks from this .bas ----
    If cntEnum > 0 Then
        Print #outFH, "  -- Enums (" & cntEnum & ") --"
        Print #outFH, enumBuf
    End If

    Print "       " & cnt & " sub/fn  " _
        & cntConst & " const  " & cntDef & " define  " & cntEnum & " enum"
End Sub

' ============================================================
'  .bi scanner - VT_* consts, defines, macros, declares
'              + Enum / End Enum blocks
' ============================================================

Sub scanBi(filename As String, outFH As Long)
    Dim fh        As Long
    Dim rawLn     As String
    Dim trimmed   As String
    Dim lnlow     As String
    Dim logLn     As String
    Dim declCheck As String
    Dim namePart  As String

    Dim constBuf  As String
    Dim defBuf    As String
    Dim macroBuf  As String
    Dim declBuf   As String
    Dim enumBuf   As String

    Dim cntConst  As Long
    Dim cntDef    As Long
    Dim cntMacro  As Long
    Dim cntDecl   As Long
    Dim cntEnum   As Long
    Dim inMacro   As Byte
    Dim inEnum    As Byte

    constBuf = "" : defBuf = "" : macroBuf = "" : declBuf = "" : enumBuf = ""
    cntConst = 0  : cntDef = 0  : cntMacro = 0  : cntDecl = 0  : cntEnum = 0
    inMacro  = 0  : inEnum = 0

    fh = FreeFile()

    If Open(filename For Input As #fh) <> 0 Then
        Print "  [!] cannot open: "; filename
        Print #outFH, "  [!] cannot open: " & filename
        Exit Sub
    End If

    Print "  bi : "; filename

    Do While Not EOF(fh)
        Line Input #fh, rawLn
        trimmed = strTrim(rawLn)
        lnlow   = LCase(trimmed)

        If Len(trimmed) = 0 Then Continue Do

        ' ---- inside a #macro block: capture until #endmacro ----
        If inMacro Then
            macroBuf &= "      " & trimmed & Chr(10)
            If strStartsWith(lnlow, "#endmacro") Then inMacro = 0
            Continue Do
        End If

        ' ---- inside an Enum block: capture until End Enum ----
        If inEnum Then
            enumBuf &= "      " & trimmed & Chr(10)
            If strStartsWith(lnlow, "end enum") Then
                enumBuf &= Chr(10)    ' blank line between blocks
                inEnum = 0
            End If
            Continue Do
        End If

        ' ---- Const VT_* ----
        If strStartsWith(lnlow, "const vt_") Then
            logLn    = strTrim(stripComment(readLogicalLine(fh, trimmed)))
            constBuf &= "    " & logLn & Chr(10)
            cntConst += 1
            Continue Do
        End If

        ' ---- #define VT_* ----
        If strStartsWith(lnlow, "#define vt_") Then
            defBuf &= "    " & trimmed & Chr(10)
            cntDef  += 1
            Continue Do
        End If

        ' ---- #macro VT_* ----
        If strStartsWith(lnlow, "#macro vt_") Then
            macroBuf &= "    " & trimmed & Chr(10)
            cntMacro += 1
            inMacro   = 1
            Continue Do
        End If

        ' ---- Enum / End Enum block ----
        If lnlow = "enum" Or strStartsWith(lnlow, "enum ") Then
            enumBuf &= "    " & trimmed & Chr(10)
            cntEnum += 1
            inEnum   = 1
            Continue Do
        End If

        ' ---- Declare Sub/Function vt_* (bonus: .bi prototypes) ----
        If strStartsWith(lnlow, "declare ") Then
            declCheck = strTrim(Mid(lnlow, 9))
            If strStartsWith(declCheck, "sub ") Then
                namePart = LCase(strTrim(Mid(declCheck, 5)))
            ElseIf strStartsWith(declCheck, "function ") Then
                namePart = LCase(strTrim(Mid(declCheck, 10)))
            Else
                Continue Do
            End If
            If strStartsWith(namePart, "vt_") = 0 Then Continue Do
            If strStartsWith(namePart, "vt_internal_") Then Continue Do
            logLn   = strTrim(stripComment(readLogicalLine(fh, trimmed)))
            declBuf &= "    " & logLn & Chr(10)
            cntDecl += 1
            Continue Do
        End If

    Loop

    Close #fh

    ' ---- write sections ----
    Print #outFH, "  -- Constants (" & cntConst & ") --"
    If cntConst > 0 Then
        Print #outFH, constBuf
    Else
        Print #outFH, "    (none)" & Chr(10)
    End If

    Print #outFH, "  -- Defines (" & cntDef & ") --"
    If cntDef > 0 Then
        Print #outFH, defBuf
    Else
        Print #outFH, "    (none)" & Chr(10)
    End If

    Print #outFH, "  -- Macros (" & cntMacro & ") --"
    If cntMacro > 0 Then
        Print #outFH, macroBuf
    Else
        Print #outFH, "    (none)" & Chr(10)
    End If

    Print #outFH, "  -- Enums (" & cntEnum & ") --"
    If cntEnum > 0 Then
        Print #outFH, enumBuf
    Else
        Print #outFH, "    (none)" & Chr(10)
    End If

    If cntDecl > 0 Then
        Print #outFH, "  -- Declares in .bi (" & cntDecl & ") --"
        Print #outFH, declBuf
    End If

    Print "       " & cntConst & " const  " & cntDef & " define  " _
        & cntMacro & " macro  " & cntEnum & " enum  " & cntDecl & " declare"
End Sub

' ============================================================
'  MAIN
' ============================================================

Dim srcPath  As String
Dim biPath   As String
Dim ff       As String
Dim outFH    As Long
Dim totalFns As Long

srcPath  = IIf(Command(1) <> "", Command(1), ".")
biPath   = srcPath & IIf(srcPath = ".", "/", "/") & BI_NAME
totalFns = 0
outFH    = FreeFile()

Print "libvt API scanner"
Print "Source : "; srcPath
Print "Output : "; OUT_FILE
Print ""

If Open(OUT_FILE For Output As #outFH) <> 0 Then
    Print "ERROR: cannot create " & OUT_FILE
    End 1
End If

Print #outFH, "============================================================"
Print #outFH, " libvt Public API Dump"
Print #outFH, " Generated : " & Date & "  " & Time
Print #outFH, " Source    : " & srcPath
Print #outFH, "============================================================"
Print #outFH, ""

' ---- SUBS / FUNCTIONS + CONSTS / DEFINES / ENUMS from all .bas files ----

Print #outFH, "==== PUBLIC SUBS / FUNCTIONS + CONSTS / DEFINES / ENUMS (.bas) =="
Print #outFH, ""
Print "Scanning .bas files..."

Dim basFound As Byte
basFound = 0
ff = Dir(srcPath & "/*.bas", fbNormal)
Do While ff <> ""
    basFound = 1
    scanBas srcPath & "/" & ff, outFH, totalFns
    ff = Dir()
Loop

If basFound = 0 Then
    Print "  (no .bas files found)"
    Print #outFH, "  (no .bas files found)"
    Print #outFH, ""
End If

Print #outFH, "  Total: " & totalFns & " public sub/function(s)"
Print #outFH, ""

' ---- CONSTANTS / DEFINES / MACROS / ENUMS from vt.bi ----

Print #outFH, "==== PUBLIC CONSTANTS / DEFINES / MACROS / ENUMS (" & BI_NAME & ") =="
Print #outFH, ""
Print "Scanning " & BI_NAME & "..."

If FileExists(biPath) Then
    scanBi biPath, outFH
Else
    Print "  [!] " & biPath & " not found"
    Print #outFH, "  [!] " & biPath & " not found"
End If

' ---- footer ------------------------------------------------

Print #outFH, ""
Print #outFH, "============================================================"
Print #outFH, " End of dump"
Print #outFH, "============================================================"

Close #outFH

Print ""
Print "Done -> " & OUT_FILE
Print ""
Print "< any key to quit >"
Sleep
