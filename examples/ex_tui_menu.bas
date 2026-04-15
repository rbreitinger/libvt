' test_tui_menu.bas -- menubar test [fully pass]
#define VT_USE_TUI
#include once "../vt/vt.bi"

Sub draw_header(lbl As String)
    vt_color(VT_WHITE, VT_BLUE)
    vt_print_center(1, lbl)
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

Sub wait_key(prompt As String)
    Dim k As ULong
    vt_color(VT_YELLOW, VT_BLACK)
    vt_locate(25, 1) : vt_print(prompt & " -- press any key")
    Do
      k = vt_inkey()
      If k <> 0 Then Exit Do
      vt_sleep(10)
    Loop
    vt_color(VT_LIGHT_GREY, VT_BLACK)
End Sub

' =============================================================================
' Menu test: full interactive menubar with result display.
' =============================================================================
Sub test_menu()
    Dim groups(2) As String
    Dim items(10) As String
    Dim counts(2) As Long
    Dim k         As ULong
    Dim ret       As Long
    Dim grp       As Long
    Dim itm       As Long
    Dim item_off  As Long
    Dim quit_f    As Byte
    Dim smsg      As String

    groups(0) = "File" : groups(1) = "Edit" : groups(2) = "Help"

    items(0)  = "New"       : items(1) = "Open..."  : items(2)  = "Save"
    items(3)  = "Exit"      : items(4) = "Cut"      : items(5)  = "Copy"
    items(6)  = "Paste"     : items(7) = "About"    : items(8)  = "Contents"
    items(9)  = "Index"     : items(10) = "Search..."

    counts(0) = 4 : counts(1) = 3 : counts(2) = 4

    vt_cls()
    draw_header("MENU TEST -- click or Alt+F / Alt+E / Alt+H")
    vt_color(VT_LIGHT_GREY, VT_BLACK)
    vt_locate(5, 2) : vt_print("Mouse: click a menu header to open, click an item.")
    vt_locate(6, 2) : vt_print("Keys:  Alt+F/E/H opens group, arrows navigate, Enter selects.")
    vt_locate(7, 2) : vt_print("       Left/Right in open dropdown switches groups.")
    vt_locate(8, 2) : vt_print("       ESC closes dropdown. ESC in main loop also quits.")
    vt_locate(9, 2) : vt_print("File -> Exit (item 4) quits this test.")
    vt_tui_statusbar(24, " Alt+F=File  Alt+E=Edit  Alt+H=Help  |  File->Exit or ESC to quit")

    quit_f = 0
    smsg   = "(no selection yet)"

    Do
        vt_tui_menubar_draw(1, groups())
        vt_color(VT_YELLOW, VT_BLACK)
        vt_locate(12, 2) : vt_print("Last action: " & smsg & String(40, " "))
        
        k   = vt_inkey()
        ret = vt_tui_menubar_handle(1, groups(), items(), counts(), k)

        If ret <> 0 Then
            grp      = VT_TUI_MENU_GROUP(ret)
            itm      = VT_TUI_MENU_ITEM(ret)
            item_off = itm - 1
            If grp > 1 Then item_off += counts(0)
            If grp > 2 Then item_off += counts(1)
            smsg = groups(grp - 1) & " -> " & items(item_off) & _
                   "  (ret=" & ret & " grp=" & grp & " itm=" & itm & ")"
            If grp = 1 AndAlso itm = 4 Then quit_f = 1  ' File -> Exit
        End If

        If VT_SCAN(k) = VT_KEY_ESC AndAlso ret = 0 Then quit_f = 1
        If quit_f Then Exit Do
        vt_sleep(10)
    Loop
End Sub

' =============================================================================
' main
' =============================================================================
vt_screen(VT_SCREEN_0)
vt_title("TUI Menubar Test")
vt_mouse(1)
test_menu()
vt_shutdown()
