' vt_file.bas
' Simple file/directory helpers for libvt.
' Opt-in: #define VT_USE_FILE before #include once "vt/vt.bi"
' -----------------------------------------------------------------------

#include once "dir.bi"

' -----------------------------------------------------------------------
' vt_file_exists(path) As Byte
' 1 if path is an existing file (not a directory), 0 otherwise.
' Uses Dir() directly -- no vbcompat.bi needed.
' -----------------------------------------------------------------------
Function vt_file_exists(ByRef path As Const String) As Byte
    ' attrib As Integer: Dir() ByRef out_attrib requires Integer (exception to Long rule)
    Dim attrib As Integer
    Dim res    As String
    res = Dir(path, fbReadOnly Or fbHidden Or fbSystem Or fbArchive, attrib)
    If res = "" Then Return 0
    If (attrib And fbDirectory) Then Return 0
    Return 1
End Function

' -----------------------------------------------------------------------
' vt_file_isdir(path) As Byte
' 1 if path is an existing directory, 0 otherwise.
' Hides the fbDirectory / dir.bi dependency from caller code.
' -----------------------------------------------------------------------
Function vt_file_isdir(ByRef path As Const String) As Byte
    Dim attrib As Integer
    Dim res    As String
    res = Dir(path, fbDirectory Or fbReadOnly Or fbHidden Or fbSystem Or fbArchive, attrib)
    If res = "" Then Return 0
    If (attrib And fbDirectory) = 0 Then Return 0
    Return 1
End Function

' -----------------------------------------------------------------------
' vt_file_internal_normpath(p) As String
' Normalize a path for the recursion-trap check in vt_file_copy:
'   - lowercase (Windows is case-insensitive)
'   - all backslashes -> forward slash
'   - exactly one trailing slash appended
' "data"   -> "data/"    "data/backup" -> "data/backup/"
' The trailing slash prevents "data/" from matching "database/".
' -----------------------------------------------------------------------
Function vt_file_internal_normpath(ByRef p As Const String) As String
    Dim nrm As String
    Dim idx As Long
    nrm = LCase(p)
    For idx = 1 To Len(nrm)
        If Mid(nrm, idx, 1) = "\" Then Mid(nrm, idx, 1) = "/"
    Next idx
    If Right(nrm, 1) <> "/" Then nrm &= "/"
    Return nrm
End Function

' forward declaration -- vt_file_internal_copydir and vt_file_copy call each other
Declare Function vt_file_internal_copydir(ByRef src As Const String, ByRef dst As Const String, flags As Long) As Long

' -----------------------------------------------------------------------
' vt_file_copy(src, dst, flags) As Long
' Copy a file or directory tree.
'   src is a file -> copy byte-for-byte (reads whole file into memory)
'   src is a dir  -> recursively recreate directory tree under dst,
'                    copying every file; existing dst dir is merged into.
' flags : VT_FILE_OVERWRITE   overwrite existing destination files
' returns:
'   0   ok
'  -1   src not found (neither file nor directory)
'  -2   dst exists as a file but src is a directory (type mismatch),
'       OR dst file exists and VT_FILE_OVERWRITE was not set
'  -3   I/O error (open, read, write, or MkDir failure)
'  -4   recursion trap: dst is src itself or a subdirectory of src
' -----------------------------------------------------------------------
Function vt_file_copy(ByRef src As Const String, ByRef dst As Const String, flags As Long = 0) As Long
    Dim buf()    As UByte
    Dim src_num  As Long
    Dim dst_num  As Long
    Dim fsz      As Long
    Dim src_norm As String
    Dim dst_norm As String

    ' --- directory copy branch ---
    If vt_file_isdir(src) Then
        ' type mismatch check first: dst is an existing file (not a dir)
        ' must be before the normpath trap -- a file path can match the src prefix
        If vt_file_exists(dst) Then Return -2
        ' recursion trap: dst is src itself or lives inside src
        src_norm = vt_file_internal_normpath(src)
        dst_norm = vt_file_internal_normpath(dst)
        If Len(dst_norm) >= Len(src_norm) Then
            If Mid(dst_norm, 1, Len(src_norm)) = src_norm Then Return -4
        End If
        Return vt_file_internal_copydir(src, dst, flags)
    End If

    ' --- file copy branch ---
    If vt_file_exists(src) = 0 Then Return -1

    If vt_file_exists(dst) Then
        If (flags And VT_FILE_OVERWRITE) = 0 Then Return -2
    End If

    src_num = FreeFile()
    If Open(src, For Binary, As #src_num) <> 0 Then Return -3
    fsz = LOF(src_num)
    If fsz > 0 Then
        ReDim buf(0 To fsz - 1)
        Get #src_num, , buf()
    End If
    Close #src_num

    dst_num = FreeFile()
    If Open(dst, For Binary, As #dst_num) <> 0 Then Return -3
    If fsz > 0 Then
        Put #dst_num, , buf()
    End If
    Close #dst_num

    Return 0
End Function

' -----------------------------------------------------------------------
' vt_file_internal_copydir(src, dst, flags) As Long
' Recursive worker called by vt_file_copy for directory trees.
' Collects all entries in one Dir() pass before touching anything
' (same discipline as vt_file_rmdir) so Dir() state is never corrupted.
' MkDir dst if it does not exist; merges into dst if it does.
' VT_FILE_OVERWRITE propagates to per-file vt_file_copy calls.
' returns: 0=ok  -3=MkDir or file copy failure
' -----------------------------------------------------------------------
Function vt_file_internal_copydir(ByRef src As Const String, ByRef dst As Const String, flags As Long) As Long
    Dim attrib    As Integer
    Dim scan_mask As Integer
    Dim itm       As String
    Dim files()   As String
    Dim dirs()    As String
    Dim fcnt      As Long
    Dim dcnt      As Long
    Dim idx       As Long
    Dim ret       As Long

    ' create dst if needed
    If vt_file_isdir(dst) = 0 Then
        MkDir dst
        If vt_file_isdir(dst) = 0 Then Return -3
    End If

    ' collect all entries in one complete Dir() pass before touching anything
    fcnt = 0 : dcnt = 0
    ReDim files(0) : ReDim dirs(0)
    scan_mask = fbDirectory Or fbReadOnly Or fbHidden Or fbSystem Or fbArchive

    itm = Dir(src & "/*", scan_mask, attrib)
    Do While itm <> ""
        If attrib And fbDirectory Then
            If itm <> "." AndAlso itm <> ".." Then
                ReDim Preserve dirs(0 To dcnt)
                dirs(dcnt) = itm
                dcnt += 1
            End If
        Else
            ReDim Preserve files(0 To fcnt)
            files(fcnt) = itm
            fcnt += 1
        End If
        itm = Dir("", scan_mask, attrib)
    Loop

    ' copy files -- -2 means dst file exists without OVERWRITE: skip silently (merge behaviour)
    For idx = 0 To fcnt - 1
        ret = vt_file_copy(src & "/" & files(idx), dst & "/" & files(idx), flags)
        If ret <> 0 AndAlso ret <> -2 Then Return -3
    Next idx

    ' recurse into subdirectories
    For idx = 0 To dcnt - 1
        ret = vt_file_internal_copydir(src & "/" & dirs(idx), dst & "/" & dirs(idx), flags)
        If ret <> 0 Then Return ret
    Next idx

    Return 0
End Function

' -----------------------------------------------------------------------
' vt_file_rmdir(path, flags) As Long
' Remove a directory. Without VT_FILE_RECURSIVE only empty dirs succeed --
' for empty dirs prefer FreeBASIC's built-in RmDir directly.
' WARNING: VT_FILE_RECURSIVE kills all contents and subdirs -- no undo.
' All entries are collected in one Dir() pass before anything is deleted
' so the Dir() global state is never corrupted mid-scan.
' returns: 0=ok  -1=path not a directory  -2=not empty (no recursive flag)
'          -3=failed (permissions or partial recursive failure)
' -----------------------------------------------------------------------
Function vt_file_rmdir(ByRef path As Const String, flags As Long = 0) As Long
    Dim attrib  As Integer
    Dim itm     As String
    Dim files() As String
    Dim dirs()  As String
    Dim fcnt    As Long
    Dim dcnt    As Long
    Dim idx     As Long
    Dim sub_res As Long

    If vt_file_isdir(path) = 0 Then Return -1

    If flags And VT_FILE_RECURSIVE Then
        ' collect everything in one complete Dir() pass before touching anything
        fcnt = 0 : dcnt = 0
        ReDim files(0) : ReDim dirs(0)

        Dim scan_mask As Integer
        scan_mask = fbDirectory Or fbReadOnly Or fbHidden Or fbSystem Or fbArchive

        itm = Dir(path & "/*", scan_mask, attrib)
        Do While itm <> ""
            If attrib And fbDirectory Then
                If itm <> "." AndAlso itm <> ".." Then
                    ReDim Preserve dirs(0 To dcnt)
                    dirs(dcnt) = itm
                    dcnt += 1
                End If
            Else
                ReDim Preserve files(0 To fcnt)
                files(fcnt) = itm
                fcnt += 1
            End If
            itm = Dir("", scan_mask, attrib)   ' continue scan
        Loop

        For idx = 0 To fcnt - 1
            Kill path & "/" & files(idx)
        Next idx

        For idx = 0 To dcnt - 1
            sub_res = vt_file_rmdir(path & "/" & dirs(idx), VT_FILE_RECURSIVE)
            If sub_res <> 0 Then Return -3
        Next idx
    End If

    ' directory should now be empty -- attempt removal
    RmDir path
    If vt_file_isdir(path) Then
        If (flags And VT_FILE_RECURSIVE) = 0 Then Return -2
        Return -3
    End If

    Return 0
End Function

' -----------------------------------------------------------------------
' vt_file_list(path, pattern, arr(), flags) As Long
' Fill arr() with item names matching pattern inside path (e.g. "*.txt").
' Skips . and .. automatically. Names returned are bare (no path prefix).
' path=""  searches current directory.
' flags : VT_FILE_SHOW_HIDDEN   include hidden items
'         VT_FILE_SHOW_DIRS     include subdirectory names in results
'         VT_FILE_DIRS_ONLY     return only subdirs (implies SHOW_DIRS)
' arr() is ReDim'd. Returns item count (0 = nothing found).
' -----------------------------------------------------------------------
Function vt_file_list(ByRef path As Const String, ByRef pattern As Const String, arr() As String, flags As Long = 0) As Long
    Dim attrib    As Integer
    Dim dir_mask  As Long
    Dim full_pat  As String
    Dim itm       As String
    Dim cnt       As Long
    Dim is_dir    As Byte
    Dim show_hid  As Byte
    Dim show_dirs As Byte
    Dim dirs_only As Byte

    show_hid  = ((flags And VT_FILE_SHOW_HIDDEN) <> 0)
    dirs_only = ((flags And VT_FILE_DIRS_ONLY)   <> 0)
    show_dirs = (dirs_only OrElse ((flags And VT_FILE_SHOW_DIRS) <> 0))

    dir_mask = fbReadOnly Or fbArchive Or fbSystem
    If show_hid  Then dir_mask = dir_mask Or fbHidden
    If show_dirs Then dir_mask = dir_mask Or fbDirectory

    If path = "" Then
        full_pat = pattern
    Else
        full_pat = path & "/" & pattern
    End If

    ReDim arr(0)
    cnt = 0

    Dim scan_mask As Integer
    scan_mask = dir_mask   ' dir_mask already built from flags above

    itm = Dir(full_pat, scan_mask, attrib)
    Do While itm <> ""
        is_dir = ((attrib And fbDirectory) <> 0)

        If is_dir AndAlso (itm = "." OrElse itm = "..") Then
            itm = Dir("", scan_mask, attrib) : Continue Do
        End If

        If dirs_only AndAlso (is_dir = 0) Then
            itm = Dir("", scan_mask, attrib) : Continue Do
        End If

        ReDim Preserve arr(0 To cnt)
        arr(cnt) = itm
        cnt += 1
        itm = Dir("", scan_mask, attrib)
    Loop

    Return cnt
End Function
