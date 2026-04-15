' =============================================================================
' vt_tty.bas - VT TTY backend
' =============================================================================

' --- Linux C API declarations -------------------------------------------------
#Ifdef __FB_LINUX__

Type termios_t
    c_iflag  As ULong
    c_oflag  As ULong
    c_cflag  As ULong
    c_lflag  As ULong
    c_line   As UByte
    c_cc(18) As UByte
    c_ispeed As ULong
    c_ospeed As ULong
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

#Else
' =============================================================================
' Windows 10+ console API declarations
' Requires Windows 10 build 1511+ for ENABLE_VIRTUAL_TERMINAL_PROCESSING.
' vt_internal_tty_init returns -1 on older Windows (SetConsoleMode fails).
' TODO (later): Win32 Console API fallback for Windows < 10
'               (WriteConsoleOutput / CHAR_INFO -- essentially a third
'               backend, VT_WIN32CON, no VT sequences involved)
' =============================================================================

' std handle ids
Const VT_TTY_STD_OUTPUT_HANDLE_ = &hFFFFFFF5UL
Const VT_TTY_STD_INPUT_HANDLE_  = &hFFFFFFF6UL

' output mode flags
Const VT_TTY_ENABLE_PROC_OUT_   = &h0001UL  ' ENABLE_PROCESSED_OUTPUT
Const VT_TTY_ENABLE_VT_PROC_    = &h0004UL  ' ENABLE_VIRTUAL_TERMINAL_PROCESSING

' input mode flags (cleared for raw mode)
Const VT_TTY_ENABLE_PROC_IN_    = &h0001UL  ' ENABLE_PROCESSED_INPUT
Const VT_TTY_ENABLE_LINE_IN_    = &h0002UL  ' ENABLE_LINE_INPUT
Const VT_TTY_ENABLE_ECHO_IN_    = &h0004UL  ' ENABLE_ECHO_INPUT

' control key state bits
Const VT_TTY_SHIFT_PRESSED_     = &h0010UL
Const VT_TTY_LEFT_CTRL_         = &h0008UL
Const VT_TTY_RIGHT_CTRL_        = &h0004UL
Const VT_TTY_LEFT_ALT_          = &h0002UL
Const VT_TTY_RIGHT_ALT_         = &h0001UL

' INPUT_RECORD event type
Const VT_TTY_KEY_EVENT_         = 1

' virtual key codes
Const VT_TTY_VK_BACK_           = &h08
Const VT_TTY_VK_TAB_            = &h09
Const VT_TTY_VK_RETURN_         = &h0D
Const VT_TTY_VK_ESCAPE_         = &h1B
Const VT_TTY_VK_PRIOR_          = &h21  ' PgUp
Const VT_TTY_VK_NEXT_           = &h22  ' PgDn
Const VT_TTY_VK_END_            = &h23
Const VT_TTY_VK_HOME_           = &h24
Const VT_TTY_VK_LEFT_           = &h25
Const VT_TTY_VK_UP_             = &h26
Const VT_TTY_VK_RIGHT_          = &h27
Const VT_TTY_VK_DOWN_           = &h28
Const VT_TTY_VK_INSERT_         = &h2D
Const VT_TTY_VK_DELETE_         = &h2E
Const VT_TTY_VK_F1_             = &h70
Const VT_TTY_VK_F2_             = &h71
Const VT_TTY_VK_F3_             = &h72
Const VT_TTY_VK_F4_             = &h73
Const VT_TTY_VK_F5_             = &h74
Const VT_TTY_VK_F6_             = &h75
Const VT_TTY_VK_F7_             = &h76
Const VT_TTY_VK_F8_             = &h77
Const VT_TTY_VK_F9_             = &h78
Const VT_TTY_VK_F10_            = &h79
Const VT_TTY_VK_F11_            = &h7A
Const VT_TTY_VK_F12_            = &h7B

' INPUT_RECORD layout for KEY_EVENT (20 bytes total):
'   EventType(2) + pad(2) + bKeyDown(4) + wRepeatCount(2) +
'   wVirtualKeyCode(2) + wVirtualScanCode(2) +
'   uChar/AsciiChar(1) + pad2(1) + dwControlKeyState(4)
Type vt_tty_input_rec
    event_type  As UShort
    pad_        As UShort
    key_down    As Long
    repeat_cnt  As UShort
    vk_code     As UShort
    vk_scan     As UShort
    ascii_ch    As UByte
    pad2_       As UByte
    ctrl_state  As ULong
End Type

Declare Function GetStdHandle_    Lib "kernel32" Alias "GetStdHandle"                  (nStdHandle As ULong) As Any Ptr
Declare Function GetConsoleMode_  Lib "kernel32" Alias "GetConsoleMode"                (hConsole As Any Ptr, ByRef dwMode As ULong) As Long
Declare Function SetConsoleMode_  Lib "kernel32" Alias "SetConsoleMode"                (hConsole As Any Ptr, dwMode As ULong) As Long
Declare Function WriteFile_       Lib "kernel32" Alias "WriteFile"                     (hFile As Any Ptr, buf As Any Ptr, nWrite As ULong, ByRef nWritten As ULong, overlapped As Any Ptr) As Long
Declare Function GetNumInEvts_    Lib "kernel32" Alias "GetNumberOfConsoleInputEvents" (hConsole As Any Ptr, ByRef nEvents As ULong) As Long
Declare Function ReadConsoleIn_   Lib "kernel32" Alias "ReadConsoleInputA"             (hConsole As Any Ptr, buf As Any Ptr, nLen As ULong, ByRef nRead As ULong) As Long

Dim Shared vt_tty_hout         As Any Ptr
Dim Shared vt_tty_hin          As Any Ptr
Dim Shared vt_tty_old_out_mode As ULong
Dim Shared vt_tty_old_in_mode  As ULong

#EndIf   ' Not __FB_LINUX__

' -----------------------------------------------------------------------------
' BSS buffers -- module level, no malloc, always valid
' shadow: max 80x50 = 4000 cells * 3 bytes = 12000 bytes
' out   : 128 KB covers worst-case full repaint on any supported screen mode
' -----------------------------------------------------------------------------
Dim Shared vt_tty_shadow_buf(11999) As UByte
Dim Shared vt_tty_shadow            As vt_cell Ptr
Dim Shared vt_tty_out_buf(131071)   As UByte

' --- color lookup tables: CGA order -> ANSI SGR codes ---
Static Shared vt_tty_fg_code(15) As UByte = {30, 34, 32, 36, 31, 35, 33, 37, 90, 94, 92, 96, 91, 95, 93, 97}
Static Shared vt_tty_bg_code(15) As UByte = {40, 44, 42, 46, 41, 45, 43, 47, 100, 104, 102, 106, 101, 105, 103, 107}

' =============================================================================
' vt_internal_tty_init
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

    ' --- shadow buffer: point at BSS array, no malloc ---
    ' fg=255 on every cell forces full repaint on first vt_present_tty call
    vt_tty_shadow = Cast(vt_cell Ptr, @vt_tty_shadow_buf(0))
    For si = 0 To cols * rows - 1
        vt_tty_shadow[si].fg = 255
    Next si

    ' --- scrollback ---
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
        tcgetattr_(0, @vt_tty_old_termios)
        Dim raw As termios_t = vt_tty_old_termios
        raw.c_lflag = raw.c_lflag And Not (VT_TTY_ECHO_ Or VT_TTY_ECHONL_ Or _
                                            VT_TTY_ICANON_ Or VT_TTY_ISIG_ Or VT_TTY_IEXTEN_)
        raw.c_iflag = raw.c_iflag And Not (VT_TTY_ICRNL_ Or VT_TTY_IXON_)
        raw.c_oflag = raw.c_oflag And Not VT_TTY_OPOST_
        raw.c_cc(VT_TTY_VMIN_)  = 0
        raw.c_cc(VT_TTY_VTIME_) = 0
        tcsetattr_(0, VT_TTY_TCSAFLUSH_, @raw)
        fflush_(0)
        ' switch console to 8-bit legacy mode (raw bytes = direct font indices)
        Dim init_seq As String = !"\x1b[2J\x1b[H\x1b[?25l\x1b%@"
        'Dim init_seq As String = !"\x1b[2J\x1b[H\x1b[?25l"
        write_unix(1, StrPtr(init_seq), CULng(Len(init_seq)))
    #Else
        ' Win10+ path: enable VT output processing
        ' TODO (later): add Win32 Console API fallback for Windows < 10
        Dim vt_nw As ULong
        vt_tty_hout = GetStdHandle_(VT_TTY_STD_OUTPUT_HANDLE_)
        vt_tty_hin  = GetStdHandle_(VT_TTY_STD_INPUT_HANDLE_)
        GetConsoleMode_(vt_tty_hout, vt_tty_old_out_mode)
        GetConsoleMode_(vt_tty_hin,  vt_tty_old_in_mode)
        ' SetConsoleMode returns 0 on Windows < 10 (flag not supported) -> bail
        If SetConsoleMode_(vt_tty_hout, VT_TTY_ENABLE_PROC_OUT_ Or VT_TTY_ENABLE_VT_PROC_) = 0 Then
            Return -1
        End If
        ' raw input: clear echo, line buffering, processed input (same as Linux ISIG off)
        SetConsoleMode_(vt_tty_hin, vt_tty_old_in_mode And Not _
                        (VT_TTY_ENABLE_ECHO_IN_ Or VT_TTY_ENABLE_LINE_IN_ Or VT_TTY_ENABLE_PROC_IN_))
        Dim init_seq As String = !"\x1b[2J\x1b[H\x1b[?25l"
        WriteFile_(vt_tty_hout, StrPtr(init_seq), CULng(Len(init_seq)), vt_nw, 0)
    #EndIf

    vt_internal.ready   = 1
    vt_internal.backend = 1

    ' NOTE: do NOT call vt_present() here.
    ' Cells are zero-filled (CAllocate). User calls vt_cls() + vt_present().
    Return 0
End Function

' =============================================================================
' vt_internal_tty_shutdown
' =============================================================================
Sub vt_internal_tty_shutdown()
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.ready = 0

    Dim sl As Long
    For sl = 0 To VT_PAGE_SLOTS - 1
        If vt_internal.page_buf(sl) <> 0 Then
            DeAllocate vt_internal.page_buf(sl)
            vt_internal.page_buf(sl) = 0
        End If
    Next sl
    vt_internal.cells = 0

    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If

    ' shadow is BSS -- no DeAllocate, just clear the pointer
    vt_tty_shadow = 0

    #Ifdef __FB_LINUX__
        ' Shutdown -- restore UTF-8 mode so subsequent programs (MC etc.) work correctly  
        Dim shut_seq As String = !"\x1b[?25h\x1b[0m\x1b%G"
        'Dim shut_seq As String = !"\x1b[?25h\x1b[0m"
        write_unix(1, StrPtr(shut_seq), CULng(Len(shut_seq)))
        tcsetattr_(0, VT_TTY_TCSAFLUSH_, @vt_tty_old_termios)
    #Else
        ' Win10+ path: restore cursor/colors then restore saved console modes
        Dim vt_nw     As ULong
        Dim shut_seq  As String = !"\x1b[?25h\x1b[0m"
        WriteFile_(vt_tty_hout, StrPtr(shut_seq), CULng(Len(shut_seq)), vt_nw, 0)
        SetConsoleMode_(vt_tty_hout, vt_tty_old_out_mode)
        SetConsoleMode_(vt_tty_hin,  vt_tty_old_in_mode)
    #EndIf
End Sub

' =============================================================================
' vt_tty_buf_num - append decimal integer into BSS output buffer
' =============================================================================
Private Sub vt_tty_buf_num(ByRef n As Long, v As Long)
    If v >= 100 Then
        vt_tty_out_buf(n) = Asc("0") + (v \ 100)          : n += 1
        vt_tty_out_buf(n) = Asc("0") + ((v Mod 100) \ 10) : n += 1
        vt_tty_out_buf(n) = Asc("0") + (v Mod 10)         : n += 1
    ElseIf v >= 10 Then
        vt_tty_out_buf(n) = Asc("0") + (v \ 10)           : n += 1
        vt_tty_out_buf(n) = Asc("0") + (v Mod 10)         : n += 1
    Else
        vt_tty_out_buf(n) = Asc("0") + v                  : n += 1
    End If
End Sub

' =============================================================================
' vt_present_tty
' Diff against shadow buffer, emit ANSI sequences for changed cells only.
' Uses BSS output buffer + write_unix (Linux) / WriteFile (Win10+).
' No heap allocation of any kind.
' =============================================================================
Sub vt_present_tty()
    If vt_internal.ready = 0 Then Exit Sub

    Dim cols    As Long        = vt_internal.scr_cols
    Dim rows    As Long        = vt_internal.scr_rows
    Dim vis_buf As vt_cell Ptr = vt_internal.page_buf(vt_internal.vis_page)
    Dim out_n   As Long        = 0
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
    Dim row_0   As Long
    Dim col_0   As Long
    Dim last_fg As Long = -1
    Dim last_bg As Long = -1
    Dim last_bk As Long = -1
    Dim vt_nw   As ULong   ' bytes written (Win10+ WriteFile, unused on Linux)

    For ci = 0 To cols * rows - 1
        ' Route through display_cellptr so scrollback content is shown when
        ' sb_offset > 0. Falls back to vis_buf + ci when no scrollback active.
        row_0   = ci \ cols
        col_0   = ci Mod cols
        cellptr = vt_internal_display_cellptr(col_0, row_0, vis_buf)
        shadptr = vt_tty_shadow + ci

        ' skip unchanged cells
        If cellptr->ch = shadptr->ch AndAlso _
           cellptr->fg = shadptr->fg AndAlso _
           cellptr->bg = shadptr->bg Then Continue For

        shadptr->ch = cellptr->ch
        shadptr->fg = cellptr->fg
        shadptr->bg = cellptr->bg

        ' mid-loop flush: keep 64 bytes headroom for one full cell sequence
        If out_n > 131008 Then
            #Ifdef __FB_LINUX__
                write_unix(1, @vt_tty_out_buf(0), CULng(out_n))
            #Else
                WriteFile_(vt_tty_hout, @vt_tty_out_buf(0), CULng(out_n), vt_nw, 0)
            #EndIf
            out_n = 0
        End If

        ' CUP: ESC [ row ; col H
        row_1 = ci \ cols + 1
        col_1 = ci Mod cols + 1
        vt_tty_out_buf(out_n) = 27        : out_n += 1
        vt_tty_out_buf(out_n) = Asc("[")  : out_n += 1
        vt_tty_buf_num(out_n, row_1)
        vt_tty_out_buf(out_n) = Asc(";")  : out_n += 1
        vt_tty_buf_num(out_n, col_1)
        vt_tty_out_buf(out_n) = Asc("H")  : out_n += 1

        ' SGR: only when color or blink changes
        fg_raw  = cellptr->fg And &hF
        bg_raw  = cellptr->bg And &hF
        blink_f = (cellptr->fg Shr 4) And 1

        fg_code = vt_tty_fg_code(fg_raw)
        bg_code = vt_tty_bg_code(bg_raw)

        If fg_code <> last_fg OrElse bg_code <> last_bg OrElse blink_f <> last_bk Then
            vt_tty_out_buf(out_n) = 27        : out_n += 1
            vt_tty_out_buf(out_n) = Asc("[")  : out_n += 1
            vt_tty_out_buf(out_n) = Asc("0")  : out_n += 1
            If blink_f Then
                vt_tty_out_buf(out_n) = Asc(";") : out_n += 1
                vt_tty_out_buf(out_n) = Asc("5") : out_n += 1
            End If
            vt_tty_out_buf(out_n) = Asc(";")  : out_n += 1
            vt_tty_buf_num(out_n, fg_code)
            vt_tty_out_buf(out_n) = Asc(";")  : out_n += 1
            vt_tty_buf_num(out_n, bg_code)
            vt_tty_out_buf(out_n) = Asc("m")  : out_n += 1
            last_fg = fg_code
            last_bg = bg_code
            last_bk = blink_f
        End If

        ' glyph -- space for control/null bytes
        vt_tty_out_buf(out_n) = IIf(cellptr->ch >= 32, cellptr->ch, 32)
        out_n += 1

    Next ci

    ' park terminal cursor
    vt_tty_out_buf(out_n) = 27        : out_n += 1
    vt_tty_out_buf(out_n) = Asc("[")  : out_n += 1
    vt_tty_buf_num(out_n, vt_internal.cur_row)
    vt_tty_out_buf(out_n) = Asc(";")  : out_n += 1
    vt_tty_buf_num(out_n, vt_internal.cur_col)
    vt_tty_out_buf(out_n) = Asc("H")  : out_n += 1

    If vt_internal.cur_visible Then
        vt_tty_out_buf(out_n) = 27        : out_n += 1
        vt_tty_out_buf(out_n) = Asc("[")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("?")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("2")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("5")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("h")  : out_n += 1
    Else
        vt_tty_out_buf(out_n) = 27        : out_n += 1
        vt_tty_out_buf(out_n) = Asc("[")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("?")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("2")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("5")  : out_n += 1
        vt_tty_out_buf(out_n) = Asc("l")  : out_n += 1
    End If

    If out_n > 0 Then
        #Ifdef __FB_LINUX__
            write_unix(1, @vt_tty_out_buf(0), CULng(out_n))
        #Else
            WriteFile_(vt_tty_hout, @vt_tty_out_buf(0), CULng(out_n), vt_nw, 0)
        #EndIf
    End If

    vt_internal.dirty = 0
End Sub

' =============================================================================
' vt_pump_tty
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
        Dim ct       As ULong
        Dim al       As ULong

        nb = read_unix(0, @ibuf(0), 32)
        If nb <= 0 Then Exit Sub

        bi = 0
        Do While bi < nb
            ch = ibuf(bi)
            bi += 1

            If ch = 27 Then
                If bi >= nb Then
                    ' Lone ESC at end of batch.
                    ' Short yield + retry handles split kernel tty writes --
                    ' raw VT console Alt+special generates ESC, then the key
                    ' sequence, as two separate writes to the tty device.
                    ' Without this, the ESC would be pushed as VT_KEY_ESC and
                    ' the next read would see the remainder out of context.
                    vt_sleep(5)
                    nb = read_unix(0, @ibuf(0), 32)
                    If nb <= 0 Then
                        vt_internal_key_push(CULng(VT_KEY_ESC) Shl 16)
                        Exit Do
                    End If
                    ' Got continuation bytes -- fall through to sequence handlers.
                    bi = 0
                End If

                ' ESC + printable: Alt+char (meta prefix from kernel or terminal).
                ' Covers a-z, A-Z, digits, symbols -- everything 32..126 except
                ' [ (91=CSI start) and O (79=SS3 start) which are sequence headers.
                ' ESC (27) is the double-ESC case handled separately below.
                ' Raw VT console scrollback bindings live here because Alt+PgUp/PgDn
                ' has no entry in the default Linux VT keymap, but Alt+symbol does.
                If ibuf(bi) >= 32 AndAlso ibuf(bi) <= 126 _
                   AndAlso ibuf(bi) <> Asc("[") AndAlso ibuf(bi) <> Asc("O") Then
                    keyrec = CULng(ibuf(bi)) Or (1UL Shl 31)
                    ' Alt+minus = scroll up (back in history)
                    ' Alt+period = scroll down (toward current)
                    ' Works in raw VT console and in terminal emulators that
                    ' send ESC+symbol (most do). Alt+PgUp/PgDn continues to
                    ' work in terminal emulators via the ESC[5;3~ CSI path.
                    If ibuf(bi) = Asc("-") Then vt_scroll(1)
                    If ibuf(bi) = Asc(".") Then vt_scroll(-1)
                    vt_internal_key_push(keyrec)
                    bi += 1
                    Continue Do
                End If

                ' ESC+ESC: raw VT console Alt/Meta prefix for special keys.
                ' e.g. Alt+PgUp on Linux VT console arrives as ESC ESC[5~.
                ' Terminal emulators encode Alt in param2 instead (ESC[5;3~).
                ' al starts here; the CSI parser below ORs in the param2 alt bit.
                al = 0
                If ibuf(bi) = 27 Then
                    al = 1
                    bi += 1
                    If bi >= nb Then
                        vt_internal_key_push(CULng(VT_KEY_ESC) Shl 16)
                        Exit Do
                    End If
                End If

                If ibuf(bi) = Asc("[") Then
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

                    If final_ch = 0 Then Exit Do

                    ' VT modifier param encoding: value = 1 + bitmask
                    ' where bitmask: bit0=shift, bit1=alt, bit2=ctrl.
                    ' param2=0 means the ; field was absent (no modifier).
                    ' param2=1 means field present but no bits set (same as absent).
                    sh = IIf(param2 >= 2 AndAlso ((param2 - 1) And 1) <> 0, 1UL, 0UL)
                    ct = IIf(param2 >= 2 AndAlso ((param2 - 1) And 4) <> 0, 1UL, 0UL)
                    ' OR in param2 alt bit -- covers terminal emulators (ESC[5;3~).
                    ' double-ESC prefix already set al=1 for raw VT console (ESC ESC[5~).
                    al = al Or IIf(param2 >= 2 AndAlso ((param2 - 1) And 2) <> 0, 1UL, 0UL)

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
                        ' Alt+PgUp/PgDn: scrollback. Works via ESC[5;3~ in terminal
                        ' emulators and via ESC ESC[5~ on raw Linux VT console.
                        ' Shift+PgUp is intercepted by the host in TTY mode so al
                        ' is the reliable binding here.
                        If al Then
                            If vtscan = VT_KEY_PGUP Then
                                vt_scroll(1)
                            ElseIf vtscan = VT_KEY_PGDN Then
                                vt_scroll(-1)
                            End If
                        End If
                        keyrec = (CULng(vtscan) Shl 16) Or (sh Shl 29) Or (ct Shl 30) Or (al Shl 31)
                        vt_internal_key_push(keyrec)
                    End If

                ElseIf ibuf(bi) = Asc("O") Then
                    bi += 1
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
                            vt_internal_key_push((CULng(vtscan) Shl 16) Or (al Shl 31))
                        End If
                    End If

                End If

            ElseIf ch = 127 Then
                vt_internal_key_push(CULng(VT_KEY_BKSP) Shl 16)

            ElseIf ch = 9 Then
                vt_internal_key_push((CULng(VT_KEY_TAB) Shl 16) Or 9UL)

            ElseIf ch = 13 OrElse ch = 10 Then
                vt_internal_key_push((CULng(VT_KEY_ENTER) Shl 16) Or 13UL)

            ElseIf ch >= 1 AndAlso ch <= 26 Then
                vt_internal_key_push(CULng(ch) Or (1UL Shl 30))

            ElseIf ch = 32 Then
                vt_internal_key_push((CULng(VT_KEY_SPACE) Shl 16) Or 32UL)
                
            ElseIf ch >= 33 Then
                vt_internal_key_push(CULng(ch))

            End If
        Loop

    #Else
        ' Win10+ path: structured KEY_EVENT records via ReadConsoleInputA.
        ' VK codes map directly to VT scancodes -- no escape sequence parsing needed.
        ' TODO (later): add Win32 Console API fallback for Windows < 10
        Dim irec    As vt_tty_input_rec
        Dim nevents As ULong
        Dim nread   As ULong
        Dim vtscan  As Long
        Dim keyrec  As ULong
        Dim shf     As ULong
        Dim ctf     As ULong
        Dim alf     As ULong

        GetNumInEvts_(vt_tty_hin, nevents)
        If nevents = 0 Then Exit Sub

        Do While nevents > 0
            ReadConsoleIn_(vt_tty_hin, @irec, 1, nread)
            nevents -= 1

            ' only process key-down events
            If irec.event_type <> VT_TTY_KEY_EVENT_ Then Continue Do
            If irec.key_down = 0 Then Continue Do

            ' modifier bits -> keyrec flags (matching Linux path bit positions)
            ' SHIFT_PRESSED=&h10 -> bit 29, LEFT/RIGHT_CTRL -> bit 30, LEFT/RIGHT_ALT -> bit 31
            shf = (irec.ctrl_state And VT_TTY_SHIFT_PRESSED_) Shr 4
            ctf = IIf((irec.ctrl_state And (VT_TTY_LEFT_CTRL_ Or VT_TTY_RIGHT_CTRL_)) <> 0, 1UL, 0UL)
            alf = IIf((irec.ctrl_state And (VT_TTY_LEFT_ALT_  Or VT_TTY_RIGHT_ALT_))  <> 0, 1UL, 0UL)

            ' check vk_code first for all well-known keys, then fall through
            ' to ascii_ch for printable chars and ctrl/alt combos
            Select Case irec.vk_code
                Case VT_TTY_VK_BACK_   : vt_internal_key_push(CULng(VT_KEY_BKSP) Shl 16)
                Case VT_TTY_VK_TAB_    : vt_internal_key_push((CULng(VT_KEY_TAB)   Shl 16) Or 9UL)
                Case VT_TTY_VK_RETURN_ : vt_internal_key_push((CULng(VT_KEY_ENTER) Shl 16) Or 13UL)
                Case VT_TTY_VK_ESCAPE_ : vt_internal_key_push(CULng(VT_KEY_ESC)   Shl 16)
                Case VT_TTY_VK_PRIOR_
                    ' scrollback: Shift+PgUp, Ctrl+Shift = half-page (mirrors SDL2 path)
                    If shf Then vt_scroll(IIf(ctf, vt_internal.scr_rows \ 2, 1))
                    vt_internal_key_push((CULng(VT_KEY_PGUP) Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_NEXT_
                    ' scrollback: Shift+PgDn, Ctrl+Shift = half-page (mirrors SDL2 path)
                    If shf Then vt_scroll(-IIf(ctf, vt_internal.scr_rows \ 2, 1))
                    vt_internal_key_push((CULng(VT_KEY_PGDN) Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_END_    : vt_internal_key_push((CULng(VT_KEY_END)   Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_HOME_   : vt_internal_key_push((CULng(VT_KEY_HOME)  Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_LEFT_   : vt_internal_key_push((CULng(VT_KEY_LEFT)  Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_UP_     : vt_internal_key_push((CULng(VT_KEY_UP)    Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_RIGHT_  : vt_internal_key_push((CULng(VT_KEY_RIGHT) Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_DOWN_   : vt_internal_key_push((CULng(VT_KEY_DOWN)  Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_INSERT_ : vt_internal_key_push((CULng(VT_KEY_INS)   Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_DELETE_ : vt_internal_key_push((CULng(VT_KEY_DEL)   Shl 16) Or (shf Shl 29) Or (ctf Shl 30) Or (alf Shl 31))
                Case VT_TTY_VK_F1_     : vt_internal_key_push(CULng(VT_KEY_F1)    Shl 16)
                Case VT_TTY_VK_F2_     : vt_internal_key_push(CULng(VT_KEY_F2)    Shl 16)
                Case VT_TTY_VK_F3_     : vt_internal_key_push(CULng(VT_KEY_F3)    Shl 16)
                Case VT_TTY_VK_F4_     : vt_internal_key_push(CULng(VT_KEY_F4)    Shl 16)
                Case VT_TTY_VK_F5_     : vt_internal_key_push(CULng(VT_KEY_F5)    Shl 16)
                Case VT_TTY_VK_F6_     : vt_internal_key_push(CULng(VT_KEY_F6)    Shl 16)
                Case VT_TTY_VK_F7_     : vt_internal_key_push(CULng(VT_KEY_F7)    Shl 16)
                Case VT_TTY_VK_F8_     : vt_internal_key_push(CULng(VT_KEY_F8)    Shl 16)
                Case VT_TTY_VK_F9_     : vt_internal_key_push(CULng(VT_KEY_F9)    Shl 16)
                Case VT_TTY_VK_F10_    : vt_internal_key_push(CULng(VT_KEY_F10)   Shl 16)
                Case VT_TTY_VK_F11_    : vt_internal_key_push(CULng(VT_KEY_F11)   Shl 16)
                Case VT_TTY_VK_F12_    : vt_internal_key_push(CULng(VT_KEY_F12)   Shl 16)
                Case Else
                    ' printable char or ctrl/alt combo -- use ascii_ch
                    ' alf folds into bit 31 so VT_ALT(k) works for all callers
                    If irec.ascii_ch >= 32 Then
                        vt_internal_key_push(CULng(irec.ascii_ch) Or (alf Shl 31))
                    ElseIf irec.ascii_ch >= 1 AndAlso irec.ascii_ch <= 26 Then
                        vt_internal_key_push(CULng(irec.ascii_ch) Or (1UL Shl 30))
                    End If
            End Select
        Loop

    #EndIf
End Sub

#Undef vt_internal_ticks
#Undef vt_pump_tty
#Undef vt_present_tty
#Undef vt_internal_tty_init
#Undef vt_internal_tty_shutdown
