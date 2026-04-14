' =============================================================================
' vt_tty.bas - VT TTY backend (Milestone 1: Linux termios)
' Included only when VT_TTY is defined -- zero impact on SDL2 builds.
' =============================================================================

' --- Linux C API declarations -------------------------------------------------
#Ifdef __FB_LINUX__

Type termios_t
    c_iflag  As ULong        ' input flags
    c_oflag  As ULong        ' output flags
    c_cflag  As ULong        ' control flags
    c_lflag  As ULong        ' local flags
    c_line   As UByte        ' line discipline
    c_cc(18) As UByte        ' control chars  (NCCS=19, indices 0..18)
    c_ispeed As ULong        ' input speed
    c_ospeed As ULong        ' output speed
End Type

' c_lflag bits
Const VT_TTY_ISIG_    = &h1UL
Const VT_TTY_ICANON_  = &h2UL
Const VT_TTY_ECHO_    = &h8UL
Const VT_TTY_ECHONL_  = &h40UL
Const VT_TTY_IEXTEN_  = &h8000UL

' c_iflag bits
Const VT_TTY_ICRNL_   = &h100UL
Const VT_TTY_IXON_    = &h400UL

' c_oflag bits
Const VT_TTY_OPOST_   = &h1UL

' tcsetattr action
Const VT_TTY_TCSAFLUSH_ = 2

' c_cc indices
Const VT_TTY_VTIME_   = 5
Const VT_TTY_VMIN_    = 6

Declare Function tcgetattr_  Lib "c" Alias "tcgetattr" (fd As Long, t As Any Ptr) As Long
Declare Function tcsetattr_  Lib "c" Alias "tcsetattr" (fd As Long, act As Long, t As Any Ptr) As Long
Declare Function read_unix   Lib "c" Alias "read"      (fd As Long, buf As Any Ptr, cnt As ULong) As Long
Declare Function write_unix  Lib "c" Alias "write"     (fd As Long, buf As Any Ptr, cnt As ULong) As Long
Declare Sub      fflush_     Lib "c" Alias "fflush"    (f As Any Ptr)

Dim Shared vt_tty_old_termios As termios_t

#EndIf   ' __FB_LINUX__

' shadow buffer: diff against this to minimise terminal output
' allocated in tty_init, freed in tty_shutdown
Dim Shared vt_tty_shadow As vt_cell Ptr

' =============================================================================
' vt_internal_tty_init
' mirrors the state setup in vt_init_impl (SDL2 path) plus termios raw mode
' =============================================================================
Function vt_internal_tty_init(mode As Long, flags As Long, pages As Long) As Long
    Dim cols As Long
    Dim rows As Long
    Dim gw   As Long
    Dim gh   As Long
    Dim pg   As Long
    Dim pi   As Long
    Dim si   As Long

    If vt_internal.ready Then vt_internal_tty_shutdown()

    ' --- resolve mode -> geometry (mirrors vt_screen select case) ---
    Select Case mode
        Case VT_SCREEN_0     : cols = 80 : rows = 25 : gw = 8  : gh = 16
        Case VT_SCREEN_2     : cols = 80 : rows = 25 : gw = 8  : gh = 8
        Case VT_SCREEN_9     : cols = 80 : rows = 25 : gw = 8  : gh = 14
        Case VT_SCREEN_12    : cols = 80 : rows = 30 : gw = 8  : gh = 16
        Case VT_SCREEN_13    : cols = 40 : rows = 25 : gw = 8  : gh = 8
        Case VT_SCREEN_EGA43 : cols = 80 : rows = 43 : gw = 8  : gh = 8
        Case VT_SCREEN_VGA50 : cols = 80 : rows = 50 : gw = 8  : gh = 8
        Case VT_SCREEN_TILES : cols = 40 : rows = 25 : gw = 16 : gh = 16
        Case Else            : cols = 80 : rows = 25 : gw = 8  : gh = 16
    End Select

    vt_internal.scr_cols = cols
    vt_internal.scr_rows = rows
    vt_internal.glyph_w  = gw
    vt_internal.glyph_h  = gh

    ' --- page buffers ---
    If pages < 1 Then pages = 1
    If pages > VT_PAGE_SLOTS Then pages = VT_PAGE_SLOTS
    For pg = 0 To VT_PAGE_SLOTS - 1
        vt_internal.page_buf(pg) = 0
    Next pg
    For pg = 0 To pages - 1
        vt_internal.page_buf(pg) = CAllocate(cols * rows, SizeOf(vt_cell))
        If vt_internal.page_buf(pg) = 0 Then
            Dim fc As Long
            For fc = 0 To pg - 1
                DeAllocate vt_internal.page_buf(fc)
                vt_internal.page_buf(fc) = 0
            Next fc
            Return -6
        End If
    Next pg
    vt_internal.num_pages = pages
    vt_internal.work_page = 0
    vt_internal.vis_page  = 0
    vt_internal.cells     = vt_internal.page_buf(0)

    ' --- shadow buffer ---
    ' fg=255 on every cell is invalid -- guarantees full repaint on first present
    If vt_tty_shadow <> 0 Then DeAllocate vt_tty_shadow
    vt_tty_shadow = Allocate(cols * rows * SizeOf(vt_cell))
    If vt_tty_shadow = 0 Then
        For pg = 0 To pages - 1
            DeAllocate vt_internal.page_buf(pg)
            vt_internal.page_buf(pg) = 0
        Next pg
        Return -7
    End If
    For si = 0 To cols * rows - 1
        vt_tty_shadow[si].fg = 255
    Next si

    ' --- scrollback (user calls vt_scrollback after vt_screen if wanted) ---
    vt_internal.sb_lines  = 0
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0
    vt_internal.sb_cells  = 0

    ' --- cursor ---
    vt_internal.cur_col     = 1
    vt_internal.cur_row     = 1
    vt_internal.cur_visible = 1
    vt_internal.cur_ch      = 219

    ' --- colour ---
    vt_internal.clr_fg = VT_LIGHT_GREY
    vt_internal.clr_bg = VT_BLACK

    ' --- scroll region ---
    vt_internal.scroll_on = 1
    vt_internal.view_top  = 1
    vt_internal.view_bot  = rows

    ' --- blink ---
    vt_internal.blink_visible = 1
    vt_internal.blink_tick    = vt_internal_ticks()

    ' --- key repeat ---
    vt_internal.rep_scan    = 0
    vt_internal.rep_initial = VT_KEY_REPEAT_INITIAL
    vt_internal.rep_rate    = VT_KEY_REPEAT_RATE

    ' --- mouse (no-op in TTY mode) ---
    vt_internal.mouse_on    = 0
    vt_internal.mouse_col   = 1
    vt_internal.mouse_row   = 1
    vt_internal.mouse_btns  = 0
    vt_internal.mouse_vis   = 0
    vt_internal.mouse_wheel = 0
    vt_internal.mouse_lock  = 0

    ' --- copy/paste ---
    vt_internal.cp_flags       = 0
    vt_internal.sel_active     = 0
    vt_internal.sel_anchor_col = 1
    vt_internal.sel_anchor_row = 1
    vt_internal.sel_end_col    = 1
    vt_internal.sel_end_row    = 1
    vt_internal.sel_dragging   = 0
    vt_internal.cp_paste_pend  = 0

    ' --- palette ---
    For pi = 0 To 47
        vt_internal.palette(pi) = vt_default_palette(pi)
    Next pi

    vt_internal.init_flags = flags
    vt_internal.dirty      = 0

    ' --- platform init ---
    #Ifdef __FB_LINUX__
        ' save current termios, enter raw mode
        tcgetattr_(0, @vt_tty_old_termios)
        Dim raw As termios_t = vt_tty_old_termios
        ' disable echo, canonical mode, signals, extended input processing
        raw.c_lflag = raw.c_lflag And Not (VT_TTY_ECHO_ Or VT_TTY_ECHONL_ Or _
                                            VT_TTY_ICANON_ Or VT_TTY_ISIG_ Or VT_TTY_IEXTEN_)
        ' disable CR->LF translation, software flow control
        raw.c_iflag = raw.c_iflag And Not (VT_TTY_ICRNL_ Or VT_TTY_IXON_)
        ' disable output processing (we emit explicit ANSI sequences)
        raw.c_oflag = raw.c_oflag And Not VT_TTY_OPOST_
        ' VMIN=0 VTIME=0: read() returns immediately with whatever is available
        raw.c_cc(VT_TTY_VMIN_)  = 0
        raw.c_cc(VT_TTY_VTIME_) = 0
        tcsetattr_(0, VT_TTY_TCSAFLUSH_, @raw)

        ' flush any pending libc stdio output before switching to write_unix
        fflush_(0)

        ' clear screen, home cursor, hide text cursor -- use write() directly,
        ' bypassing libc stdio which may misbehave after OPOST is disabled
        Dim init_seq As String = !"\x1b[2J\x1b[H\x1b[?25l"
        write_unix(1, StrPtr(init_seq), CULng(Len(init_seq)))
    #Else
        ' Windows TTY path: Milestone 2
        ' TODO: GetStdHandle(STD_OUTPUT_HANDLE) + SetConsoleMode(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        Return -1
    #EndIf

    vt_internal.ready   = 1
    vt_internal.backend = 1

    ' NOTE: do NOT call vt_present() here.
    ' Cells are all zeros (CAllocate) -- nothing meaningful to show yet.
    ' User code calls vt_cls() + vt_present() after vt_screen() returns.
    Return 0
End Function

' =============================================================================
' vt_internal_tty_shutdown
' =============================================================================
Sub vt_internal_tty_shutdown()
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.ready = 0

    ' free page buffers
    Dim sl As Long
    For sl = 0 To VT_PAGE_SLOTS - 1
        If vt_internal.page_buf(sl) <> 0 Then
            DeAllocate vt_internal.page_buf(sl)
            vt_internal.page_buf(sl) = 0
        End If
    Next sl
    vt_internal.cells = 0

    ' free scrollback
    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If

    ' free shadow buffer
    If vt_tty_shadow <> 0 Then
        DeAllocate vt_tty_shadow
        vt_tty_shadow = 0
    End If

    #Ifdef __FB_LINUX__
        ' show cursor, reset all attributes -- write() directly, same reason as init
        Dim shut_seq As String = !"\x1b[?25h\x1b[0m"
        write_unix(1, StrPtr(shut_seq), CULng(Len(shut_seq)))
        tcsetattr_(0, VT_TTY_TCSAFLUSH_, @vt_tty_old_termios)
    #EndIf
End Sub

' =============================================================================
' vt_present_tty
' Diff against shadow buffer, emit ANSI sequences for changed cells only.
' CGA->ANSI:  index 0..7  -> 30..37 fg / 40..47 bg  (normal)
'             index 8..15 -> 90..97 fg / 100..107 bg (bright)
' Direct formula:  fg < 8 -> 30+fg,  else 82+fg  (82+8=90, 82+15=97)
'                  bg < 8 -> 40+bg,  else 92+bg  (92+8=100, 92+15=107)
' Uses write_unix(fd=1) directly -- bypasses libc stdio after OPOST disabled.
' =============================================================================
Sub vt_present_tty()
    If vt_internal.ready = 0 Then Exit Sub

    Dim cols    As Long        = vt_internal.scr_cols
    Dim rows    As Long        = vt_internal.scr_rows
    Dim vis_buf As vt_cell Ptr = vt_internal.page_buf(vt_internal.vis_page)
    Dim outstr  As String      = ""
    Dim ci      As Long
    Dim fg_raw  As UByte
    Dim bg_raw  As UByte
    Dim blink_f As Long
    Dim fg_code As Long
    Dim bg_code As Long
    Dim row_1   As Long
    Dim col_1   As Long
    Dim cellptr As vt_cell Ptr
    Dim shadptr As vt_cell Ptr
    ' track last emitted color to skip redundant SGR sequences
    Dim last_fg As Long = -1
    Dim last_bg As Long = -1
    Dim last_bk As Long = -1

    For ci = 0 To cols * rows - 1
        cellptr = vis_buf + ci
        shadptr = vt_tty_shadow + ci

        ' skip unchanged cells
        If cellptr->ch = shadptr->ch AndAlso _
           cellptr->fg = shadptr->fg AndAlso _
           cellptr->bg = shadptr->bg Then Continue For

        shadptr->ch = cellptr->ch
        shadptr->fg = cellptr->fg
        shadptr->bg = cellptr->bg

        ' move cursor to this cell (1-based row;col)
        row_1 = ci \ cols + 1
        col_1 = ci Mod cols + 1
        outstr = outstr & !"\x1b[" & row_1 & ";" & col_1 & "H"

        ' decode CGA color to ANSI codes
        fg_raw  = cellptr->fg And &hF
        bg_raw  = cellptr->bg And &hF
        blink_f = (cellptr->fg Shr 4) And 1
        fg_code = IIf(fg_raw < 8, 30 + fg_raw, 82 + fg_raw)
        bg_code = IIf(bg_raw < 8, 40 + bg_raw, 92 + bg_raw)

        ' emit SGR only when color/blink changes from last emitted cell
        If fg_code <> last_fg OrElse bg_code <> last_bg OrElse blink_f <> last_bk Then
            If blink_f Then
                outstr = outstr & !"\x1b[0;5;" & fg_code & ";" & bg_code & "m"
            Else
                outstr = outstr & !"\x1b[0;" & fg_code & ";" & bg_code & "m"
            End If
            last_fg = fg_code
            last_bg = bg_code
            last_bk = blink_f
        End If

        ' emit the character (space for null/control bytes)
        If cellptr->ch >= 32 Then
            outstr = outstr & Chr(cellptr->ch)
        Else
            outstr = outstr & " "
        End If
    Next ci

    ' park terminal cursor at VT cursor position (or hide it)
    If vt_internal.cur_visible Then
        outstr = outstr & !"\x1b[" & vt_internal.cur_row & ";" & vt_internal.cur_col & "H"
        outstr = outstr & !"\x1b[?25h"
    Else
        outstr = outstr & !"\x1b[?25l"
    End If

    ' write directly via write() syscall -- bypasses libc stdio entirely,
    ' which avoids misbehaviour after OPOST is disabled on the pty slave
    If Len(outstr) > 0 Then
        #Ifdef __FB_LINUX__
            write_unix(1, StrPtr(outstr), CULng(Len(outstr)))
        #EndIf
    End If

    vt_internal.dirty = 0
End Sub

' =============================================================================
' vt_pump_tty
' Non-blocking stdin read with VMIN=0/VTIME=0.
' The raw terminal delivers natural key repeat via repeated bytes -- no manual
' repeat needed here. Escape sequences arrive as a single atomic read batch.
' =============================================================================
Sub vt_pump_tty()
    If vt_internal.ready = 0 Then Exit Sub

    #Ifdef __FB_LINUX__
        Dim ibuf(31) As UByte
        Dim nb       As Long
        Dim bi       As Long
        Dim ch       As UByte
        Dim sc       As UByte
        Dim vtscan   As Long
        Dim keyrec   As ULong
        Dim param1   As Long
        Dim param2   As Long
        Dim cur_p    As Long
        Dim final_ch As UByte
        Dim sh       As ULong

        nb = read_unix(0, @ibuf(0), 32)
        If nb <= 0 Then Exit Sub

        bi = 0
        Do While bi < nb
            ch = ibuf(bi)
            bi += 1

            If ch = 27 Then
                ' --- ESC: lone key or sequence prefix ---
                If bi >= nb Then
                    ' nothing follows in this read batch: treat as Escape key
                    vt_internal_key_push(CULng(VT_KEY_ESC) Shl 16)
                    Exit Do
                End If

                If ibuf(bi) = Asc("[") Then
                    ' --- CSI: ESC [ param1 ; param2 finalchar ---
                    bi += 1
                    param1 = 0 : param2 = 0 : cur_p = 0 : final_ch = 0
                    Do While bi < nb
                        sc = ibuf(bi)
                        bi += 1
                        If sc >= Asc("0") AndAlso sc <= Asc("9") Then
                            If cur_p = 0 Then
                                param1 = param1 * 10 + (sc - Asc("0"))
                            Else
                                param2 = param2 * 10 + (sc - Asc("0"))
                            End If
                        ElseIf sc = Asc(";") Then
                            cur_p = 1
                        Else
                            final_ch = sc
                            Exit Do
                        End If
                    Loop

                    If final_ch = 0 Then Exit Do   ' incomplete sequence, drop remainder

                    ' Shift modifier: ESC[1;2X
                    sh = IIf(param1 = 1 AndAlso param2 = 2, 1UL, 0UL)

                    vtscan = 0
                    Select Case final_ch
                        Case Asc("A") : vtscan = VT_KEY_UP
                        Case Asc("B") : vtscan = VT_KEY_DOWN
                        Case Asc("C") : vtscan = VT_KEY_RIGHT
                        Case Asc("D") : vtscan = VT_KEY_LEFT
                        Case Asc("H") : vtscan = VT_KEY_HOME
                        Case Asc("F") : vtscan = VT_KEY_END
                        Case Asc("~")
                            Select Case param1
                                Case 2  : vtscan = VT_KEY_INS
                                Case 3  : vtscan = VT_KEY_DEL
                                Case 5  : vtscan = VT_KEY_PGUP
                                Case 6  : vtscan = VT_KEY_PGDN
                                Case 11 : vtscan = VT_KEY_F1
                                Case 12 : vtscan = VT_KEY_F2
                                Case 13 : vtscan = VT_KEY_F3
                                Case 14 : vtscan = VT_KEY_F4
                                Case 15 : vtscan = VT_KEY_F5
                                Case 17 : vtscan = VT_KEY_F6
                                Case 18 : vtscan = VT_KEY_F7
                                Case 19 : vtscan = VT_KEY_F8
                                Case 20 : vtscan = VT_KEY_F9
                                Case 21 : vtscan = VT_KEY_F10
                                Case 23 : vtscan = VT_KEY_F11
                                Case 24 : vtscan = VT_KEY_F12
                            End Select
                    End Select

                    If vtscan <> 0 Then
                        keyrec = (CULng(vtscan) Shl 16) Or (sh Shl 29)
                        vt_internal_key_push(keyrec)
                    End If

                ElseIf ibuf(bi) = Asc("O") Then
                    ' --- SS3: ESC O X  (F1-F4 on some terminals, also Home/End) ---
                    bi += 1   ' skip 'O'
                    If bi < nb Then
                        sc = ibuf(bi)
                        bi += 1
                        vtscan = 0
                        Select Case sc
                            Case Asc("P") : vtscan = VT_KEY_F1
                            Case Asc("Q") : vtscan = VT_KEY_F2
                            Case Asc("R") : vtscan = VT_KEY_F3
                            Case Asc("S") : vtscan = VT_KEY_F4
                            Case Asc("H") : vtscan = VT_KEY_HOME
                            Case Asc("F") : vtscan = VT_KEY_END
                        End Select
                        If vtscan <> 0 Then
                            vt_internal_key_push(CULng(vtscan) Shl 16)
                        End If
                    End If

                End If

            ElseIf ch = 127 Then
                ' DEL byte = Backspace in termios raw mode
                vt_internal_key_push(CULng(VT_KEY_BKSP) Shl 16)

            ElseIf ch = 9 Then
                ' Tab
                vt_internal_key_push((CULng(VT_KEY_TAB) Shl 16) Or 9UL)

            ElseIf ch = 13 OrElse ch = 10 Then
                ' Enter (CR or LF -- raw mode may send either)
                vt_internal_key_push((CULng(VT_KEY_ENTER) Shl 16) Or 13UL)

            ElseIf ch >= 1 AndAlso ch <= 26 Then
                ' Ctrl+A (1) .. Ctrl+Z (26)
                ' ch itself is the control byte; set Ctrl flag, no vtscan
                vt_internal_key_push(CULng(ch) Or (1UL Shl 30))

            ElseIf ch >= 32 Then
                ' printable ASCII or high CP437 byte
                vt_internal_key_push(CULng(ch))

            End If
        Loop
    #EndIf
    ' Windows: Milestone 2
End Sub

#Undef vt_internal_ticks
#Undef vt_pump_tty
#Undef vt_present_tty
#Undef vt_internal_tty_init
#Undef vt_internal_tty_shutdown
