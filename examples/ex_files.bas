' ex_files.bas
' vt_file extension example / test program
' Run from /examples -- all paths are relative to that working directory.

' vt_file_rmdir + Windows Explorer:
' If Explorer (or any shell/tool) has the target directory open,
' RmDir may fail or vt_file_isdir may briefly return 1 immediately
' after deletion due to Explorer holding a filesystem watch handle.
' This is OS behaviour -- not a library bug. Close Explorer or any
' open file manager window pointing at the target before recursive
' deletion if you need reliable return codes.

#define VT_USE_FILE
#include once "../vt/vt.bi"

' -----------------------------------------------------------------------
Dim cnt  As Long
Dim idx  As Long
Dim ret  As Long
Dim arr() As String

vt_screen(VT_SCREEN_0)
vt_title("vt_file test")
vt_copypaste(VT_CP_KBD Or VT_CP_MOUSE)

' -----------------------------------------------------------------------
vt_cls()
vt_color(11, 0)
vt_print_center(1, "=== vt_file extension test ===")
vt_color(7, 0)

' --- vt_file_isdir / vt_file_exists on known paths ---
vt_locate(3, 1)
vt_color(14, 0) : vt_print("vt_file_isdir / vt_file_exists" & VT_NEWLINE)
vt_color(7, 0)

If vt_file_isdir("filetest") Then
    vt_color(12, 0)
    vt_print("  WARN: 'filetest' already exists -- delete it first for a clean run." & VT_NEWLINE)
    vt_color(7, 0)
Else
    vt_print("  isdir('filetest')     = " & vt_file_isdir("filetest")     & "  (expect 0)" & VT_NEWLINE)
End If
vt_print("  isdir('.')            = " & vt_file_isdir(".")             & "  (expect 1)" & VT_NEWLINE)
vt_print("  exists('ex_files.bas')= " & vt_file_exists("ex_files.bas") & "  (expect 1)" & VT_NEWLINE)
vt_print("  exists('no_such.txt') = " & vt_file_exists("no_such.txt")  & "  (expect 0)" & VT_NEWLINE)

vt_color(8, 0) : vt_print(VT_NEWLINE & "  press any key..." & VT_NEWLINE) : vt_color(7, 0)
vt_present() : vt_sleep(0)

' --- create directory structure ---
vt_cls()
vt_locate(1, 1)
vt_color(14, 0) : vt_print("MkDir + vt_file_isdir" & VT_NEWLINE)
vt_color(7, 0)

MkDir "filetest"
MkDir "filetest/sub_a"
MkDir "filetest/sub_b"

vt_print("  created 'filetest', 'filetest/sub_a', 'filetest/sub_b'" & VT_NEWLINE)
vt_print("  isdir('filetest')       = " & vt_file_isdir("filetest")       & "  (expect 1)" & VT_NEWLINE)
vt_print("  isdir('filetest/sub_a') = " & vt_file_isdir("filetest/sub_a") & "  (expect 1)" & VT_NEWLINE)
vt_print("  isdir('filetest/sub_b') = " & vt_file_isdir("filetest/sub_b") & "  (expect 1)" & VT_NEWLINE)

' write a couple of test files
Dim fnum As Long
fnum = FreeFile()
Open "filetest/hello.txt"   For Output As #fnum : Print #fnum, "hello world" : Close #fnum
fnum = FreeFile()
Open "filetest/data.dat"    For Output As #fnum : Print #fnum, "some data"   : Close #fnum
fnum = FreeFile()
Open "filetest/sub_a/nested.txt" For Output As #fnum : Print #fnum, "nested" : Close #fnum

vt_print("  created filetest/hello.txt, filetest/data.dat, filetest/sub_a/nested.txt" & VT_NEWLINE)
vt_print("  exists('filetest/hello.txt')      = " & vt_file_exists("filetest/hello.txt")      & "  (expect 1)" & VT_NEWLINE)
vt_print("  exists('filetest/sub_a/nested.txt')= " & vt_file_exists("filetest/sub_a/nested.txt") & "  (expect 1)" & VT_NEWLINE)

vt_color(8, 0) : vt_print(VT_NEWLINE & "  press any key..." & VT_NEWLINE) : vt_color(7, 0)
vt_present() : vt_sleep(0)

' --- vt_file_list ---
vt_cls()
vt_locate(1, 1)
vt_color(14, 0) : vt_print("vt_file_list" & VT_NEWLINE)
vt_color(7, 0)

cnt = vt_file_list("filetest", "*", arr())
vt_print("  list('filetest', '*', no flags)  count=" & cnt & VT_NEWLINE)
For idx = 0 To cnt - 1
    vt_print("    [" & idx & "] " & arr(idx) & VT_NEWLINE)
Next idx

vt_print(VT_NEWLINE)
cnt = vt_file_list("filetest", "*", arr(), VT_FILE_SHOW_DIRS)
vt_print("  list('filetest', '*', SHOW_DIRS) count=" & cnt & VT_NEWLINE)
For idx = 0 To cnt - 1
    vt_print("    [" & idx & "] " & arr(idx) & VT_NEWLINE)
Next idx

vt_print(VT_NEWLINE)
cnt = vt_file_list("filetest", "*", arr(), VT_FILE_DIRS_ONLY)
vt_print("  list('filetest', '*', DIRS_ONLY) count=" & cnt & VT_NEWLINE)
For idx = 0 To cnt - 1
    vt_print("    [" & idx & "] " & arr(idx) & VT_NEWLINE)
Next idx

vt_color(8, 0) : vt_print(VT_NEWLINE & "  press any key..." & VT_NEWLINE) : vt_color(7, 0)
vt_present() : vt_sleep(0)

' --- vt_file_copy ---
vt_cls()
vt_locate(1, 1)
vt_color(14, 0) : vt_print("vt_file_copy" & VT_NEWLINE)
vt_color(7, 0)

ret = vt_file_copy("filetest/hello.txt", "filetest/hello_copy.txt")
vt_print("  copy hello.txt -> hello_copy.txt              ret=" & ret & "  (expect 0)"  & VT_NEWLINE)
vt_print("  exists('filetest/hello_copy.txt')            = " & vt_file_exists("filetest/hello_copy.txt") & "  (expect 1)" & VT_NEWLINE)

ret = vt_file_copy("filetest/hello.txt", "filetest/hello_copy.txt")
vt_print("  copy again, no overwrite flag                 ret=" & ret & "  (expect -2)" & VT_NEWLINE)

ret = vt_file_copy("filetest/hello.txt", "filetest/hello_copy.txt", VT_FILE_OVERWRITE)
vt_print("  copy again, VT_FILE_OVERWRITE                 ret=" & ret & "  (expect 0)"  & VT_NEWLINE)

ret = vt_file_copy("filetest/no_such.txt", "filetest/whatever.txt")
vt_print("  copy nonexistent src                          ret=" & ret & "  (expect -1)" & VT_NEWLINE)

vt_color(8, 0) : vt_print(VT_NEWLINE & "  press any key..." & VT_NEWLINE) : vt_color(7, 0)
vt_present() : vt_sleep(0)

' --- vt_file_rmdir recursive ---
vt_cls()
vt_locate(1, 1)
vt_color(14, 0) : vt_print("vt_file_rmdir (recursive)" & VT_NEWLINE)
vt_color(7, 0)

ret = vt_file_rmdir("filetest")
vt_print("  rmdir 'filetest', no flag (not empty)         ret=" & ret & "  (expect -2)" & VT_NEWLINE)
vt_print("  isdir('filetest') still                      = " & vt_file_isdir("filetest") & "  (expect 1)" & VT_NEWLINE)

vt_print(VT_NEWLINE)
vt_color(12, 0) : vt_print("  WARNING: next step deletes 'filetest' and all contents!" & VT_NEWLINE)
vt_color(8, 0)  : vt_print("  press any key to proceed..." & VT_NEWLINE)
vt_color(7, 0)
vt_present() : vt_sleep(0)

ret = vt_file_rmdir("filetest", VT_FILE_RECURSIVE)
vt_print("  rmdir 'filetest', VT_FILE_RECURSIVE           ret=" & ret & "  (expect 0)"  & VT_NEWLINE)
vt_print("  isdir('filetest') after                      = " & vt_file_isdir("filetest") & "  (expect 0)" & VT_NEWLINE)

vt_color(8, 0) : vt_print(VT_NEWLINE & "  all tests done -- press any key to exit." & VT_NEWLINE)
vt_color(7, 0)
vt_present() : vt_sleep(0)

vt_shutdown()
