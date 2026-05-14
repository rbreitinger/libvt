' -----------------------------------------------------------------------
' vt_file.bas : opt-in file/directory helpers for libvt.
' -----------------------------------------------------------------------
#Include Once "dir.bi"

'>>>
':topic fileflags
':short File helper flags (opt-in: VT_USE_FILE)
':group File Helpers
'Bit-flags for vt_file_copy, vt_file_rmdir,
'and vt_file_list. Combine with Or.
':params
#Define VT_FILE_SHOW_HIDDEN   1
'      vt_file_list: include hidden items.
'
#Define VT_FILE_SHOW_DIRS     2
'      vt_file_list: include subdirectory names.
'
#Define VT_FILE_DIRS_ONLY     4
'      vt_file_list: only subdirectory names.
'
#Define VT_FILE_OVERWRITE     8
'      vt_file_copy: allow overwrite of dst.
'
#Define VT_FILE_RECURSIVE    16
'      vt_file_rmdir: delete all contents first.
'      Destructive -- no undo.
'
':see
'vt_file_copy
'vt_file_rmdir
'vt_file_list
'<<<

Declare Function vt_file_exists(ByRef path As Const String) As Byte
Declare Function vt_file_isdir(ByRef path As Const String) As Byte
Declare Function vt_file_copy(ByRef src As Const String, ByRef dst As Const String, flags As Long = 0) As Long
Declare Function vt_file_rmdir(ByRef path As Const String, flags As Long = 0) As Long
Declare Function vt_file_list(ByRef path As Const String, ByRef pattern As Const String, arr() As String, flags As Long = 0) As Long

'>>>
':topic vt_file_exists
':short Test whether a file exists
':group File Helpers
'Returns 1 if path names an existing file, 0 if
'the path does not exist or is a directory.
'Uses Dir() directly - no vbcompat.bi required.
'Opt-in: define VT_USE_FILE before the include.
':syntax
Function vt_file_exists(ByRef path As Const String) As Byte
        ':params
        'path  Path to test. May be relative or absolute.
        ':notes
        'Return values:
        '  1  File exists.
        '  0  Not found, or path is a directory.
        ':example
        'If vt_file_exists("savegame.vts") Then
        '    vt_bload("savegame.vts")
        'End If
        ':see
        'vt_file_isdir
        'vt_bload
    '<<<

    ' attrib As Integer: Dir() ByRef out_attrib requires Integer (exception to Long rule)
    Dim attrib As Integer
    Dim res    As String
    res = Dir(path, fbReadOnly Or fbHidden Or fbSystem Or fbArchive, attrib)
    If res = "" Then Return 0
    If (attrib And fbDirectory) Then Return 0
    Return 1
End Function

'>>>
':topic vt_file_isdir
':short Test whether a path is a directory
':group File Helpers
'Returns 1 if path is an existing directory, 0
'otherwise. Hides the fbDirectory constant and
'dir.bi dependency from caller code entirely.
'Opt-in: define VT_USE_FILE before the include.
':syntax
Function vt_file_isdir(ByRef path As Const String) As Byte
        ':params
        'path  Path to test. May be relative or absolute.
        ':notes
        'Return values:
        '  1  Path is an existing directory.
        '  0  Not found, or path is a file.
        ':example
        'If vt_file_isdir("output") = 0 Then
        '    MkDir("output")
        'End If
        ':see
        'vt_file_exists
        'vt_file_list
    '<<<
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
Private Function vt_file_internal_normpath(ByRef p As Const String) As String
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

'>>>
':topic vt_file_copy
':short Copy a file or a full directory tree
':group File Helpers
'Copy a file or directory tree. Auto-detects
'whether src is a file or directory.
'File mode: source is read and written to
'destination in a single binary I/O operation.
'Fails if destination already exists unless
'VT_FILE_OVERWRITE is passed.
'Directory mode: the full tree is recreated
'under dst. If dst does not exist it is created;
'if it exists the trees are merged. Individual
'files already in dst are silently skipped
'unless VT_FILE_OVERWRITE is set. All entries
'are collected in a single Dir() pass before
'anything is written.
'NOTE: Copying a directory into itself or one
'of its subdirectories is detected and refused
'with -4. E.g. vt_file_copy("data","data/bak")
'returns -4 before any file is touched.
'Opt-in: define VT_USE_FILE before the include.
':syntax
Function vt_file_copy(ByRef src As Const String, _
                      ByRef dst As Const String, _
                      flags As Long = 0) As Long

        ':params
        'src    Source file or directory path.
        'dst    Destination file or directory path.
        'flags  VT_FILE_OVERWRITE to allow overwriting
        '       existing destination files.
        ':notes
        'Return values:
        '   0  success
        '  -1  source not found (file nor directory)
        '  -2  dst file exists without OVERWRITE, or
        '      type mismatch (dst is file, src is dir)
        '  -3  I/O error (open, read/write, or MkDir)
        '  -4  recursion trap: dst is inside src
        ':example
        '' Backup before overwriting:
        'vt_file_copy("config.ini", "config.bak")
        '
        '' Overwrite existing destination:
        'vt_file_copy("save_new.vts", "slot1.vts", _
        '             VT_FILE_OVERWRITE)
        '
        '' Copy full directory tree:
        'vt_file_copy("data", "data_backup")
        ':see
        'vt_file_rmdir
        'vt_file_exists
        'fileflags
    '<<<

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
Private Function vt_file_internal_copydir(ByRef src As Const String, ByRef dst As Const String, flags As Long) As Long
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

'>>>
':topic vt_file_rmdir
':short Remove a directory, optionally recursive
':group File Helpers
'Remove a directory. Without VT_FILE_RECURSIVE
'the directory must be empty. Use vt_file_rmdir
'when recursive deletion of a populated tree is
'needed. When VT_FILE_RECURSIVE is set, all files
'and subdirectories are collected in a single
'Dir() pass before anything is deleted.
'WARNING: VT_FILE_RECURSIVE is permanently
'destructive. There is no undo. The flag must
'be passed explicitly -- the default is always
'safe (empty-dir only).
'Opt-in: define VT_USE_FILE before the include.
':syntax
Function vt_file_rmdir(ByRef path As Const String, _
                       flags As Long = 0) As Long

        ':params
        'path   Path to the directory to remove.
        'flags  Optional. VT_FILE_RECURSIVE deletes all
        '       contents first.
        ':notes
        'Return values:
        '   0  success
        '  -1  path is not an existing directory
        '  -2  directory is not empty and
        '      VT_FILE_RECURSIVE was not set
        '  -3  failed (permissions or partial failure)
        ':example
        '' Remove a populated tree (explicit opt-in):
        'vt_file_rmdir("build_output", VT_FILE_RECURSIVE)
        ':see
        'vt_file_copy
        'fileflags
    '<<<
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

'>>>
':topic vt_file_list
':short List directory contents into a String array
':group File Helpers
'Scan a directory for items matching pattern and
'fill arr() with their bare names (no path
'prefix). The . and .. entries are always silently
'skipped. The array is ReDim'd by this function;
'the caller only needs to declare Dim arr() As
'String. By default only files are returned. Pass
'VT_FILE_SHOW_DIRS to include subdirectory names,
'or VT_FILE_DIRS_ONLY to return only directories.
'Opt-in: define VT_USE_FILE before the include.
':syntax
Function vt_file_list(ByRef path As Const String, _
                      ByRef pattern As Const String, _
                      arr() As String, _
                      flags As Long = 0) As Long
        ':params
        'path     Directory to scan. "" = current dir.
        'pattern  Filename pattern, e.g. "*.txt" or "*".
        '         Supports * and ? wildcards.
        'arr()    Receives item names. ReDim'd to
        '         0 To count-1.
        'flags    Optional: VT_FILE_SHOW_HIDDEN,
        '         VT_FILE_SHOW_DIRS, VT_FILE_DIRS_ONLY.
        ':notes
        'Return: number of items placed in arr(). 0 if
        'nothing matched.
        ':example
        'Dim files() As String
        'Dim cnt As Long = _
        '    vt_file_list("notes", "*.txt", files())
        'For i As Long = 0 To cnt - 1
        '    vt_print(files(i) & VT_LF)
        'Next i
        '
        '' List dirs only:
        'cnt = vt_file_list("data", "*", files(), _
        '                   VT_FILE_DIRS_ONLY)
        ':see
        'vt_file_exists
        'vt_file_isdir
        'fileflags
    '<<<
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

#Undef vt_file_internal_normpath
#Undef vt_file_internal_copydir
