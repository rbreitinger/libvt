' =============================================================================
' vt_core.bas - VT Virtual Text Screen Library
' SDL2 window, cell buffer, blink, palette, vt_present, key handling.
' =============================================================================

' forward declarations
Declare Sub      vt_present()
Declare Sub      vt_shutdown()
Declare Sub      vt_internal_shutdown()
Declare Function vt_screen(mode As Long = VT_SCREEN_0, flags As Long = VT_WINDOWED, pages As Long = 1) As Long
Declare Function vt_scroll(amount As Long) As Byte
Declare Sub      vt_internal_pixel_to_cell(px As Long, py As Long, col_out As Long Ptr, row_out As Long Ptr)
Declare Sub      vt_page(work As Long, vis As Long)
Declare Sub      vt_pcopy(src As Long, dst As Long)
Declare Sub      vt_internal_cp_build_text()
Declare Function vt_internal_display_cellptr(col As Long, row_0 As Long, vis_buf As vt_cell Ptr) As vt_cell Ptr
Declare Function vt_internal_build_embedded_tex() As SDL_Texture Ptr

' Auto-cleanup destructor -- disabled. See Known Issues in vt_status.md.
' SDL appears to have its own cleanup destructor; combining them causes a hang
' when the FreeBASIC console window is closed (graphical window close works fine).
' Call vt_shutdown() explicitly if you need to tear down mid-program.

'Sub vt_auto_cleanup() Destructor
'    vt_internal_shutdown()
'End Sub

' -----------------------------------------------------------------------------
' Internal: push one key event into the circular buffer
' -----------------------------------------------------------------------------
Sub vt_internal_key_push(evt As ULong)
    If vt_internal.key_count >= VT_KEY_BUFFER_SIZE Then
        vt_internal.key_read  = (vt_internal.key_read + 1) Mod VT_KEY_BUFFER_SIZE
        vt_internal.key_count -= 1
    End If
    vt_internal.key_buf(vt_internal.key_write) = evt
    vt_internal.key_write = (vt_internal.key_write + 1) Mod VT_KEY_BUFFER_SIZE
    vt_internal.key_count += 1
End Sub

' -----------------------------------------------------------------------------
' Internal: map SDL scancode to VT scancode
' -----------------------------------------------------------------------------
Function vt_internal_sdl_to_vtscan(sdlscan As Long) As Long
    Select Case sdlscan
        Case SDL_SCANCODE_F1      : Return VT_KEY_F1
        Case SDL_SCANCODE_F2      : Return VT_KEY_F2
        Case SDL_SCANCODE_F3      : Return VT_KEY_F3
        Case SDL_SCANCODE_F4      : Return VT_KEY_F4
        Case SDL_SCANCODE_F5      : Return VT_KEY_F5
        Case SDL_SCANCODE_F6      : Return VT_KEY_F6
        Case SDL_SCANCODE_F7      : Return VT_KEY_F7
        Case SDL_SCANCODE_F8      : Return VT_KEY_F8
        Case SDL_SCANCODE_F9      : Return VT_KEY_F9
        Case SDL_SCANCODE_F10     : Return VT_KEY_F10
        Case SDL_SCANCODE_F11     : Return VT_KEY_F11
        Case SDL_SCANCODE_F12     : Return VT_KEY_F12
        Case SDL_SCANCODE_UP      : Return VT_KEY_UP
        Case SDL_SCANCODE_DOWN    : Return VT_KEY_DOWN
        Case SDL_SCANCODE_LEFT    : Return VT_KEY_LEFT
        Case SDL_SCANCODE_RIGHT   : Return VT_KEY_RIGHT
        Case SDL_SCANCODE_HOME    : Return VT_KEY_HOME
        Case SDL_SCANCODE_END     : Return VT_KEY_END
        Case SDL_SCANCODE_PAGEUP  : Return VT_KEY_PGUP
        Case SDL_SCANCODE_PAGEDOWN: Return VT_KEY_PGDN
        Case SDL_SCANCODE_INSERT  : Return VT_KEY_INS
        Case SDL_SCANCODE_DELETE  : Return VT_KEY_DEL
        Case SDL_SCANCODE_ESCAPE  : Return VT_KEY_ESC
        Case SDL_SCANCODE_RETURN  : Return VT_KEY_ENTER
        Case SDL_SCANCODE_KP_ENTER: Return VT_KEY_ENTER
        Case SDL_SCANCODE_BACKSPACE:Return VT_KEY_BKSP
        Case SDL_SCANCODE_TAB     : Return VT_KEY_TAB
        Case SDL_SCANCODE_SPACE   : Return VT_KEY_SPACE
        Case SDL_SCANCODE_LSHIFT  : Return VT_KEY_LSHIFT
        Case SDL_SCANCODE_RSHIFT  : Return VT_KEY_RSHIFT
        Case SDL_SCANCODE_LCTRL   : Return VT_KEY_LCTRL
        Case SDL_SCANCODE_RCTRL   : Return VT_KEY_RCTRL
        Case SDL_SCANCODE_LALT    : Return VT_KEY_LALT
        Case SDL_SCANCODE_RALT    : Return VT_KEY_RALT
        Case SDL_SCANCODE_LGUI    : Return VT_KEY_LWIN
        Case SDL_SCANCODE_RGUI    : Return VT_KEY_RWIN
    End Select
    Return 0
End Function

' -----------------------------------------------------------------------------
' Internal: convert raw SDL window pixel coords to 1-based cell coords.
' Uses SDL_RenderGetScale so the result is correct under all window modes:
' VT_WINDOWED, VT_FULLSCREEN_ASPECT (integer scale), VT_FULLSCREEN_STRETCH,
' and maximized windows. No stored flags needed -- SDL tells us what it used.
' -----------------------------------------------------------------------------
Sub vt_internal_pixel_to_cell(px As Long, py As Long, _
                              col_out As Long Ptr, row_out As Long Ptr)
    Dim sx    As Single
    Dim sy    As Single
    Dim out_w As Long
    Dim out_h As Long
    Dim vp_x  As Long
    Dim vp_y  As Long
    Dim log_w As Long
    Dim log_h As Long

    SDL_RenderGetScale(vt_internal.sdl_renderer, @sx, @sy)
    SDL_GetRendererOutputSize(vt_internal.sdl_renderer, @out_w, @out_h)

    log_w = vt_internal.scr_cols * vt_internal.glyph_w
    log_h = vt_internal.scr_rows * vt_internal.glyph_h

    ' Letterbox offset in output pixels -- matches what SDL computed internally
    vp_x = (out_w - CLng(log_w * sx)) \ 2
    vp_y = (out_h - CLng(log_h * sy)) \ 2

    ' Convert to logical pixel, then to 1-based cell
    *col_out = CLng((px - vp_x) / sx) \ vt_internal.glyph_w + 1
    *row_out = CLng((py - vp_y) / sy) \ vt_internal.glyph_h + 1
End Sub

' -----------------------------------------------------------------------------
' Internal: SDL event pump
' -----------------------------------------------------------------------------
Sub vt_pump()
    If vt_internal.ready = 0 Then Exit Sub

    Static pump_active As Byte
    If pump_active Then Exit Sub
    pump_active = 1

    Dim evt       As SDL_Event
    Dim modstate  As SDL_Keymod
    Dim vtscan    As Long
    Dim keyrec    As ULong
    Dim tick      As ULong
    Dim ascii_ch  As UByte
    
    Dim consumed  As Byte
    Dim new_col   As Long
    Dim new_row   As Long
    Dim click_col As Long
    Dim click_row As Long

    ' --- key repeat ---
    tick = SDL_GetTicks()
    If vt_internal.rep_scan <> 0 Then
        Dim rep_due As Long = 0
        If vt_internal.rep_last = 0 Then
            If tick - vt_internal.rep_tick >= CULng(vt_internal.rep_initial) Then
                rep_due = 1
                vt_internal.rep_last = tick
            End If
        Else
            If tick - vt_internal.rep_last >= CULng(vt_internal.rep_rate) Then
                rep_due = 1
                vt_internal.rep_last = tick
            End If
        End If
        If rep_due AndAlso vt_internal.rep_rate > 0 AndAlso vt_internal.rep_initial > 0 Then
            keyrec = vt_internal.key_buf((vt_internal.key_write + VT_KEY_BUFFER_SIZE - 1) _
                     Mod VT_KEY_BUFFER_SIZE)
            keyrec = keyrec Or (1UL Shl 28)
            vt_internal_key_push(keyrec)
        End If
    End If

    ' --- drain SDL event queue ---
    While SDL_PollEvent(@evt)
        Select Case evt.type
            Case SDL_QUIT_
                ' Window closed -- shut down and terminate.
                ' vt_internal_shutdown() frees SDL before End is called.
                vt_internal_shutdown()
                End

            Case SDL_KEYDOWN
                modstate = SDL_GetModState()
                Dim sh As ULong = IIf((modstate And KMOD_SHIFT) <> 0, 1UL, 0UL)
                Dim ct As ULong = IIf((modstate And KMOD_CTRL)  <> 0, 1UL, 0UL)
                Dim al As ULong = IIf((modstate And KMOD_ALT)   <> 0, 1UL, 0UL)

                vtscan = vt_internal_sdl_to_vtscan(evt.key.keysym.scancode)

                ' scrollback
                If ct = 0 Then
                    If (sh) AndAlso (vtscan = VT_KEY_PGUP) Then
                        vt_scroll(1)
                    ElseIf (sh) AndAlso (vtscan = VT_KEY_PGDN) Then
                        vt_scroll(-1)
                    End If
                Else
                    If (sh) AndAlso (vtscan = VT_KEY_PGUP) Then
                        vt_scroll(vt_internal.scr_rows \ 2)
                    ElseIf (sh) AndAlso (vtscan = VT_KEY_PGDN) Then
                        vt_scroll(-(vt_internal.scr_rows \ 2))
                    End If
                End If

                ' --- copy/paste key interception ---
                ' Selection extension and paste only make sense at live view (sb_offset=0).
                ' Ctrl+INS copy is allowed during scrollback -- selection may span history.
                consumed = 0
                If (vt_internal.cp_flags And VT_CP_KBD) Then

                    ' Ctrl+INS: copy selection to clipboard -- works during scrollback too
                    If ct AndAlso sh = 0 AndAlso al = 0 AndAlso vtscan = VT_KEY_INS Then
                        vt_internal_cp_build_text()
                        vt_internal.sel_active = 0
                        vt_internal.dirty      = 1
                        consumed = 1
                    End If

                    If vt_internal.sb_offset = 0 Then

                        ' Shift+arrow/Home/End: start or extend keyboard selection
                        If sh AndAlso ct = 0 AndAlso al = 0 Then
                            Select Case vtscan
                                Case VT_KEY_LEFT, VT_KEY_RIGHT, VT_KEY_UP, VT_KEY_DOWN, _
                                     VT_KEY_HOME, VT_KEY_END
                                    ' anchor at cursor position on first key of a new selection
                                    If vt_internal.sel_active = 0 Then
                                        vt_internal.sel_active     = 1
                                        vt_internal.sel_anchor_col = vt_internal.cur_col
                                        vt_internal.sel_anchor_row = vt_internal.cur_row
                                        vt_internal.sel_end_col    = vt_internal.cur_col
                                        vt_internal.sel_end_row    = vt_internal.cur_row
                                    End If
                                    ' move the end point
                                    Select Case vtscan
                                        Case VT_KEY_LEFT
                                            vt_internal.sel_end_col -= 1
                                            If vt_internal.sel_end_col < 1 Then
                                                If vt_internal.sel_end_row > 1 Then
                                                    vt_internal.sel_end_row -= 1
                                                    vt_internal.sel_end_col  = vt_internal.scr_cols
                                                Else
                                                    vt_internal.sel_end_col = 1
                                                End If
                                            End If
                                        Case VT_KEY_RIGHT
                                            vt_internal.sel_end_col += 1
                                            If vt_internal.sel_end_col > vt_internal.scr_cols Then
                                                If vt_internal.sel_end_row < vt_internal.scr_rows Then
                                                    vt_internal.sel_end_row += 1
                                                    vt_internal.sel_end_col  = 1
                                                Else
                                                    vt_internal.sel_end_col = vt_internal.scr_cols
                                                End If
                                            End If
                                        Case VT_KEY_UP
                                            If vt_internal.sel_end_row > 1 Then
                                                vt_internal.sel_end_row -= 1
                                            End If
                                        Case VT_KEY_DOWN
                                            If vt_internal.sel_end_row < vt_internal.scr_rows Then
                                                vt_internal.sel_end_row += 1
                                            End If
                                        Case VT_KEY_HOME
                                            vt_internal.sel_end_col = 1
                                        Case VT_KEY_END
                                            vt_internal.sel_end_col = vt_internal.scr_cols
                                    End Select
                                    vt_internal.dirty = 1
                                    consumed = 1
                            End Select
                        End If

                        ' Shift+INS: request paste -- vt_input drains cp_paste_pend
                        If sh AndAlso ct = 0 AndAlso al = 0 AndAlso vtscan = VT_KEY_INS Then
                            vt_internal.cp_paste_pend = 1
                            consumed = 1
                        End If

                    End If  ' sb_offset = 0

                End If

                ' Any non-intercepted, non-modifier key clears an active selection.
                ' The key itself still goes to key_buf -- we only clear the highlight.
                If vt_internal.sel_active AndAlso consumed = 0 Then
                    Select Case vtscan
                        Case VT_KEY_LSHIFT, VT_KEY_RSHIFT, VT_KEY_LCTRL, VT_KEY_RCTRL, _
                             VT_KEY_LALT,   VT_KEY_RALT,   VT_KEY_LWIN,  VT_KEY_RWIN
                            ' pure modifier -- leave selection alive
                        Case Else
                            vt_internal.sel_active = 0
                            vt_internal.dirty      = 1
                    End Select
                End If

                ascii_ch = 0
                If ct Then
                    Dim sym As Long = evt.key.keysym.sym
                    If sym >= SDLK_a AndAlso sym <= SDLK_z Then
                        ascii_ch = CByte(sym - SDLK_a + 1)
                    End If
                End If

                ' only push key and arm repeat when the key was not consumed
                If consumed = 0 Then
                    keyrec = CULng(ascii_ch)        Or _
                             (CULng(vtscan) Shl 16) Or _
                             (sh Shl 29)            Or _
                             (ct Shl 30)            Or _
                             (al Shl 31)
                    vt_internal_key_push(keyrec)
                    vt_internal.rep_scan = vtscan
                    vt_internal.rep_tick = tick
                    vt_internal.rep_last = 0
                End If

            Case SDL_KEYUP
                If vt_internal_sdl_to_vtscan(evt.key.keysym.scancode) = vt_internal.rep_scan Then
                    vt_internal.rep_scan = 0
                    vt_internal.rep_last = 0
                End If

            Case SDL_TEXTINPUT
                Dim ch As UByte = CPtr(UByte Ptr, @evt.text.text)[0]
                If ch >= 32 AndAlso ch <> 127 Then
                    keyrec = CULng(ch) Or (CULng(vt_internal.rep_scan) Shl 16)
                    modstate = SDL_GetModState()
                    If (modstate And KMOD_SHIFT) Then keyrec = keyrec Or (1UL Shl 29)
                    If (modstate And KMOD_CTRL)  Then keyrec = keyrec Or (1UL Shl 30)
                    If (modstate And KMOD_ALT)   Then keyrec = keyrec Or (1UL Shl 31)
                    If vt_internal.key_count > 0 Then
                        vt_internal.key_write = (vt_internal.key_write + VT_KEY_BUFFER_SIZE - 1) _
                                                Mod VT_KEY_BUFFER_SIZE
                        vt_internal.key_count -= 1
                    End If
                    vt_internal_key_push(keyrec)
                End If

            Case SDL_WINDOWEVENT
                If evt.window.event = SDL_WINDOWEVENT_RESIZED Then
                    vt_present()
                End If

            Case SDL_MOUSEMOTION
                ' Coordinate computation hoisted so both mouse cursor and drag
                ' selection can share it without duplicating the clamping logic.
                new_col = evt.motion.x \ vt_internal.glyph_w + 1
                new_row = evt.motion.y \ vt_internal.glyph_h + 1
                If new_col < 1 Then new_col = 1
                If new_col > vt_internal.scr_cols Then new_col = vt_internal.scr_cols
                If new_row < 1 Then new_row = 1
                If new_row > vt_internal.scr_rows Then new_row = vt_internal.scr_rows

                If vt_internal.mouse_on Then
                    If new_col <> vt_internal.mouse_col OrElse _
                       new_row <> vt_internal.mouse_row Then
                        vt_internal.mouse_col = new_col
                        vt_internal.mouse_row = new_row
                        vt_internal.dirty = 1
                    End If
                End If

                ' selection drag -- independent of mouse_on / cursor visibility
                If (vt_internal.cp_flags And VT_CP_MOUSE) AndAlso vt_internal.sel_dragging Then
                    If new_col <> vt_internal.sel_end_col OrElse _
                       new_row <> vt_internal.sel_end_row Then
                        vt_internal.sel_end_col = new_col
                        vt_internal.sel_end_row = new_row
                        vt_internal.dirty       = 1
                    End If
                End If

            Case SDL_MOUSEBUTTONDOWN
                If vt_internal.mouse_on Then
                    Select Case evt.button.button
                        Case SDL_BUTTON_LEFT   : vt_internal.mouse_btns Or= VT_MOUSE_BTN_LEFT
                        Case SDL_BUTTON_RIGHT  : vt_internal.mouse_btns Or= VT_MOUSE_BTN_RIGHT
                        Case SDL_BUTTON_MIDDLE : vt_internal.mouse_btns Or= VT_MOUSE_BTN_MIDDLE
                    End Select
                End If

                ' copy/paste mouse -- independent of mouse_on
                If (vt_internal.cp_flags And VT_CP_MOUSE) Then
                    click_col = evt.button.x \ vt_internal.glyph_w + 1
                    click_row = evt.button.y \ vt_internal.glyph_h + 1
                    If click_col < 1 Then click_col = 1
                    If click_col > vt_internal.scr_cols Then click_col = vt_internal.scr_cols
                    If click_row < 1 Then click_row = 1
                    If click_row > vt_internal.scr_rows Then click_row = vt_internal.scr_rows
                    Select Case evt.button.button
                        Case SDL_BUTTON_LEFT
                            ' start a fresh selection at the click cell
                            vt_internal.sel_active     = 1
                            vt_internal.sel_anchor_col = click_col
                            vt_internal.sel_anchor_row = click_row
                            vt_internal.sel_end_col    = click_col
                            vt_internal.sel_end_row    = click_row
                            vt_internal.sel_dragging   = 1
                            vt_internal.dirty          = 1
                        Case SDL_BUTTON_RIGHT
                            ' copy whatever is selected (no-op if sel_active = 0)
                            vt_internal_cp_build_text()
                            vt_internal.dirty = 1
                        Case SDL_BUTTON_MIDDLE
                            ' request paste -- vt_input drains this
                            vt_internal.cp_paste_pend = 1
                    End Select
                End If

            Case SDL_MOUSEBUTTONUP
                If vt_internal.mouse_on Then
                    Select Case evt.button.button
                        Case SDL_BUTTON_LEFT   : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_LEFT
                        Case SDL_BUTTON_RIGHT  : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_RIGHT
                        Case SDL_BUTTON_MIDDLE : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_MIDDLE
                    End Select
                End If
                ' finalize drag -- selection stays visible until overwritten
                If (vt_internal.cp_flags And VT_CP_MOUSE) Then
                    If evt.button.button = SDL_BUTTON_LEFT Then
                        vt_internal.sel_dragging = 0
                    End If
                End If

            Case SDL_MOUSEWHEEL
                If vt_internal.mouse_on Then
                    vt_internal.mouse_wheel += evt.wheel.y
                End If

        End Select
    Wend

    pump_active = 0
End Sub

' -----------------------------------------------------------------------------
' Internal: blink phase update
' -----------------------------------------------------------------------------
Function vt_internal_blink_update() As Byte
    Dim tick As ULong = SDL_GetTicks()
    If tick - vt_internal.blink_tick >= VT_BLINK_MS Then
        vt_internal.blink_visible = 1 - vt_internal.blink_visible
        vt_internal.blink_tick    = tick
        Return 1
    End If
    Return 0
End Function

' -----------------------------------------------------------------------------
' Internal: free all SDL and heap resources, reset state
' Called by the auto-cleanup destructor and by vt_shutdown.
' Also called at the top of vt_init_impl for re-init (mode change).
' -----------------------------------------------------------------------------
Sub vt_internal_shutdown()
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

    If vt_internal.sb_cells <> 0 Then DeAllocate vt_internal.sb_cells : vt_internal.sb_cells = 0

    If vt_internal.sdl_texture  <> 0 Then SDL_DestroyTexture(vt_internal.sdl_texture)  : vt_internal.sdl_texture  = 0
    If vt_internal.sdl_renderer <> 0 Then SDL_DestroyRenderer(vt_internal.sdl_renderer): vt_internal.sdl_renderer = 0
    If vt_internal.sdl_window   <> 0 Then SDL_DestroyWindow(vt_internal.sdl_window)    : vt_internal.sdl_window   = 0

    SDL_Quit()
End Sub

' -----------------------------------------------------------------------------
' Internal: core init -- called by vt_screen
' -----------------------------------------------------------------------------
Function vt_init_impl(cols As Long, rows As Long, glyph_w As Long, glyph_h As Long, _
                      fptr As UByte Ptr, fsrc_h As Long, flags As Long, _
                      pages As Long) As Long

    If vt_internal.ready Then vt_internal_shutdown()  ' re-init: clean up first

    If SDL_Init(SDL_INIT_VIDEO) <> 0 Then Return -1

    Dim wflags As ULong = SDL_WINDOW_SHOWN
    If (flags And VT_NO_RESIZE) = 0 Then wflags = wflags Or SDL_WINDOW_RESIZABLE

    Dim win_w As Long = cols * glyph_w
    Dim win_h As Long = rows * glyph_h

    Dim wtitle As String = vt_internal.win_title
    If wtitle = "" Then wtitle = "VT"

    vt_internal.sdl_window = SDL_CreateWindow(wtitle, _
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, _
        win_w, win_h, wflags)

    If vt_internal.sdl_window = 0 Then
        SDL_Quit()
        Return -2
    End If

    If flags And VT_FULLSCREEN_ASPECT Then
        SDL_SetWindowFullscreen(vt_internal.sdl_window, SDL_WINDOW_FULLSCREEN_DESKTOP)
    ElseIf flags And VT_FULLSCREEN_STRETCH Then
        SDL_SetWindowFullscreen(vt_internal.sdl_window, SDL_WINDOW_FULLSCREEN)
    ElseIf flags And VT_WINDOWED_MAX Then
        SDL_MaximizeWindow(vt_internal.sdl_window)
    End If

    Dim rflags As ULong = SDL_RENDERER_ACCELERATED
    If flags And VT_VSYNC Then rflags = rflags Or SDL_RENDERER_PRESENTVSYNC
    vt_internal.sdl_renderer = SDL_CreateRenderer(vt_internal.sdl_window, -1, rflags)
    If vt_internal.sdl_renderer = 0 Then
        SDL_DestroyWindow(vt_internal.sdl_window)
        SDL_Quit()
        Return -3
    End If

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0")
    SDL_RenderSetLogicalSize(vt_internal.sdl_renderer, win_w, win_h)
    If flags And VT_FULLSCREEN_ASPECT Then
        SDL_RenderSetIntegerScale(vt_internal.sdl_renderer, SDL_TRUE)
    End If

    ' --- store geometry and font (must precede texture build -- helper reads these) ---
    vt_internal.scr_cols   = cols
    vt_internal.scr_rows   = rows
    vt_internal.glyph_w    = glyph_w
    vt_internal.glyph_h    = glyph_h
    vt_internal.font_ptr   = fptr
    vt_internal.font_src_h = fsrc_h

    ' --- build font texture ---
    vt_internal.sdl_texture = vt_internal_build_embedded_tex()
    If vt_internal.sdl_texture = 0 Then
        SDL_DestroyRenderer(vt_internal.sdl_renderer)
        SDL_DestroyWindow(vt_internal.sdl_window)
        SDL_Quit()
        Return -4
    End If
    SDL_SetTextureBlendMode(vt_internal.sdl_texture, SDL_BLENDMODE_BLEND)

    ' --- pages ---
    ' Clamp requested page count, allocate each buffer, wire cells to page 0.
    Dim pg As Long
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

    ' --- scrollback not allocated here -- call vt_scrollback() after vt_screen() ---
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
    vt_internal.blink_tick    = SDL_GetTicks()

    ' --- dirty ---
    vt_internal.dirty = 0

    ' --- key repeat ---
    vt_internal.rep_scan    = 0
    vt_internal.rep_initial = VT_KEY_REPEAT_INITIAL
    vt_internal.rep_rate    = VT_KEY_REPEAT_RATE

    ' --- mouse ---
    vt_internal.mouse_on    = 0
    vt_internal.mouse_col   = 1
    vt_internal.mouse_row   = 1
    vt_internal.mouse_btns  = 0
    vt_internal.mouse_vis   = 1
    vt_internal.mouse_wheel = 0
    
    ' --- copy/paste ---
    vt_internal.cp_flags       = 0
    vt_internal.sel_active     = 0
    vt_internal.sel_anchor_col = 1
    vt_internal.sel_anchor_row = 1
    vt_internal.sel_end_col    = 1
    vt_internal.sel_end_row    = 1
    vt_internal.sel_dragging   = 0
    vt_internal.cp_paste_pend  = 0

    ' auto-lock in fullscreen, user can override with vt_mouselock()
    If flags And (VT_FULLSCREEN_ASPECT Or VT_FULLSCREEN_STRETCH) Then
        vt_internal.mouse_lock = 1
    Else
        vt_internal.mouse_lock = 0
    End If

    ' --- palette ---
    Dim pi As Long
    For pi = 0 To 47
        vt_internal.palette(pi) = vt_default_palette(pi)
    Next pi

    ' --- init flags ---
    vt_internal.init_flags = flags

    vt_internal.ready = 1
    vt_present()

    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_screen - open the virtual text screen
' mode  : VT_SCREEN_0 .. VT_SCREEN_TILES
' flags : VT_WINDOWED, VT_FULLSCREEN_ASPECT, VT_NO_RESIZE, VT_VSYNC, ...
' pages : number of cell buffers to allocate (1..VT_PAGE_SLOTS, default 1)
'         page 0 = VT_VIDEO (always the display page at startup)
'         extra pages used as work pages via vt_page() and vt_pcopy()
' Call vt_title() before to set the window title.
' Call vt_scrollback() after to enable the scrollback buffer.
' Calling vt_screen() again closes and re-opens with the new mode.
' -----------------------------------------------------------------------------
Function vt_screen(mode As Long, flags As Long, pages As Long) As Long
    Dim cols   As Long
    Dim rows   As Long
    Dim gw     As Long
    Dim gh     As Long
    Dim fptr   As UByte Ptr
    Dim fsrc_h As Long

    Select Case mode
        Case VT_SCREEN_0
            cols = 80 : rows = 25 : gw = 8  : gh = 16
            fptr = @vt_font_data_8x16(0) : fsrc_h = 16
        Case VT_SCREEN_2
            cols = 80 : rows = 25 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case VT_SCREEN_9
            cols = 80 : rows = 25 : gw = 8  : gh = 14
            fptr = @vt_font_data_8x14(0) : fsrc_h = 14
        Case VT_SCREEN_12
            cols = 80 : rows = 30 : gw = 8  : gh = 16
            fptr = @vt_font_data_8x16(0) : fsrc_h = 16
        Case VT_SCREEN_13
            cols = 40 : rows = 25 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case VT_SCREEN_EGA43
            cols = 80 : rows = 43 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case VT_SCREEN_VGA50
            cols = 80 : rows = 50 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case VT_SCREEN_TILES
            cols = 40 : rows = 25 : gw = 16 : gh = 16
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case Else
            cols = 80 : rows = 25 : gw = 8  : gh = 16
            fptr = @vt_font_data_8x16(0) : fsrc_h = 16
    End Select

    Return vt_init_impl(cols, rows, gw, gh, fptr, fsrc_h, flags, pages)
End Function

' -----------------------------------------------------------------------------
' Internal: resolve a 0-based (col, row) screen coordinate to the correct
' vt_cell pointer, reading from sb_cells or vis_buf as appropriate.
' Mirrors the row-source decision in the vt_present cell loop exactly.
' Used by: mouse cursor render, selection render, vt_internal_cp_build_text.
' vis_buf must be page_buf(vis_page) -- pass it in to avoid re-fetching.
' -----------------------------------------------------------------------------
Function vt_internal_display_cellptr(col As Long, row_0 As Long, _
                                     vis_buf As vt_cell Ptr) As vt_cell Ptr
    Dim cols        As Long = vt_internal.scr_cols
    Dim scroll_pos  As Long
    Dim logical_row As Long
    Dim live_row    As Long

    If vt_internal.sb_offset > 0 AndAlso _
       row_0 >= vt_internal.view_top - 1 AndAlso _
       row_0 <= vt_internal.view_bot - 1 Then
        scroll_pos  = row_0 - (vt_internal.view_top - 1)
        logical_row = (vt_internal.sb_used - vt_internal.sb_offset) + scroll_pos
        If logical_row < 0 Then logical_row = 0
        If logical_row < vt_internal.sb_used Then
            Return vt_internal.sb_cells + (logical_row * cols + col)
        Else
            live_row = logical_row - vt_internal.sb_used + (vt_internal.view_top - 1)
            Return vis_buf + (live_row * cols + col)
        End If
    Else
        Return vis_buf + (row_0 * cols + col)
    End If
End Function

' -----------------------------------------------------------------------------
' vt_present - composite and flip the cell buffer to the screen
' Always renders from vis_page -- independent of the active work_page.
' -----------------------------------------------------------------------------
Sub vt_present()
    If vt_internal.ready = 0 Then Exit Sub
    vt_pump()

    Dim gw          As Long
    Dim gh          As Long
    Dim cols        As Long
    Dim rows        As Long
    Dim src_rect    As SDL_Rect
    Dim dst_rect    As SDL_Rect
    Dim row_idx     As Long
    Dim col_idx     As Long
    Dim last_fg_r   As UByte
    Dim last_fg_g   As UByte
    Dim last_fg_b   As UByte
    Dim cellptr     As vt_cell Ptr
    Dim ch          As UByte
    Dim fg          As UByte
    Dim bg          As UByte
    Dim fg_r        As UByte
    Dim fg_g        As UByte
    Dim fg_b        As UByte
    Dim bg_r        As UByte
    Dim bg_g        As UByte
    Dim bg_b        As UByte
    Dim c_col       As Long
    Dim c_row       As Long
    Dim cfg_r       As UByte
    Dim cfg_g       As UByte
    Dim cfg_b       As UByte
    Dim scroll_pos  As Long
    Dim logical_row As Long
    Dim live_row    As Long
    Dim vis_buf     As vt_cell Ptr

    vt_internal_blink_update()

    gw      = vt_internal.glyph_w
    gh      = vt_internal.glyph_h
    cols    = vt_internal.scr_cols
    rows    = vt_internal.scr_rows
    vis_buf = vt_internal.page_buf(vt_internal.vis_page)

    SDL_SetRenderDrawColor(vt_internal.sdl_renderer, _
        vt_internal.border_r, vt_internal.border_g, vt_internal.border_b, 255)
    SDL_RenderClear(vt_internal.sdl_renderer)

    src_rect.w = gw
    src_rect.h = gh
    dst_rect.w = gw
    dst_rect.h = gh

    ' Reset texture colormod to white before cell loop each frame.
    ' Cursor render from previous frame would otherwise taint fg=white cells.
    SDL_SetTextureColorMod(vt_internal.sdl_texture, 255, 255, 255)
    last_fg_r = 255
    last_fg_g = 255
    last_fg_b = 255

    For row_idx = 0 To rows - 1
        If vt_internal.sb_offset > 0 AndAlso _
           row_idx >= vt_internal.view_top - 1 AndAlso _
           row_idx <= vt_internal.view_bot - 1 Then
            scroll_pos  = row_idx - (vt_internal.view_top - 1)
            logical_row = (vt_internal.sb_used - vt_internal.sb_offset) + scroll_pos
            If logical_row < 0 Then logical_row = 0
            If logical_row < vt_internal.sb_used Then
                cellptr = vt_internal.sb_cells + (logical_row * cols)
            Else
                live_row = logical_row - vt_internal.sb_used + (vt_internal.view_top - 1)
                cellptr  = vis_buf + (live_row * cols)
            End If
        Else
            cellptr = vis_buf + (row_idx * cols)
        End If

        For col_idx = 0 To cols - 1
            ch  = cellptr[col_idx].ch
            fg  = cellptr[col_idx].fg
            bg  = cellptr[col_idx].bg

            If (fg And 16) AndAlso vt_internal.blink_visible = 0 Then fg = bg
            fg = fg And 15

            fg_r = vt_internal.palette(fg * 3)
            fg_g = vt_internal.palette(fg * 3 + 1)
            fg_b = vt_internal.palette(fg * 3 + 2)
            bg_r = vt_internal.palette(bg * 3)
            bg_g = vt_internal.palette(bg * 3 + 1)
            bg_b = vt_internal.palette(bg * 3 + 2)

            dst_rect.x = col_idx * gw
            dst_rect.y = row_idx * gh

            SDL_SetRenderDrawColor(vt_internal.sdl_renderer, bg_r, bg_g, bg_b, 255)
            SDL_RenderFillRect(vt_internal.sdl_renderer, @dst_rect)

            If fg_r <> last_fg_r OrElse fg_g <> last_fg_g OrElse fg_b <> last_fg_b Then
                SDL_SetTextureColorMod(vt_internal.sdl_texture, fg_r, fg_g, fg_b)
                last_fg_r = fg_r
                last_fg_g = fg_g
                last_fg_b = fg_b
            End If
            src_rect.x = (ch Mod 16) * gw
            src_rect.y = (ch \ 16)   * gh
            SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)

        Next col_idx
    Next row_idx
    
    ' --- selection highlight: inverted cell colours ---
    ' Same two-pass invert technique as the mouse cursor.
    ' Rendered after cells, before text cursor and mouse cursor.
    ' Visible during scrollback -- vt_internal_display_cellptr reads the correct
    ' buffer (sb_cells or vis_buf) for each cell, same as the main cell loop.
    If vt_internal.sel_active Then
        Dim flat1      As Long
        Dim flat2      As Long
        Dim flat_cur   As Long
        Dim sl_row     As Long
        Dim sl_col     As Long
        Dim sl_cellptr As vt_cell Ptr
        Dim sl_ch      As UByte
        Dim sl_cfg     As UByte
        Dim sl_cbg     As UByte
        Dim si_bg_r    As UByte
        Dim si_bg_g    As UByte
        Dim si_bg_b    As UByte
        Dim si_fg_r    As UByte
        Dim si_fg_g    As UByte
        Dim si_fg_b    As UByte

        flat1 = (vt_internal.sel_anchor_row - 1) * cols + (vt_internal.sel_anchor_col - 1)
        flat2 = (vt_internal.sel_end_row    - 1) * cols + (vt_internal.sel_end_col    - 1)
        If flat1 > flat2 Then Swap flat1, flat2

        For flat_cur = flat1 To flat2
            sl_row = flat_cur \ cols
            sl_col = flat_cur Mod cols

            sl_cellptr = vt_internal_display_cellptr(sl_col, sl_row, vis_buf)
            sl_ch  = sl_cellptr->ch
            sl_cfg = sl_cellptr->fg And 15
            sl_cbg = sl_cellptr->bg And 15

            si_bg_r = 255 - vt_internal.palette(sl_cbg * 3)
            si_bg_g = 255 - vt_internal.palette(sl_cbg * 3 + 1)
            si_bg_b = 255 - vt_internal.palette(sl_cbg * 3 + 2)
            si_fg_r = 255 - vt_internal.palette(sl_cfg * 3)
            si_fg_g = 255 - vt_internal.palette(sl_cfg * 3 + 1)
            si_fg_b = 255 - vt_internal.palette(sl_cfg * 3 + 2)

            dst_rect.x = sl_col * gw
            dst_rect.y = sl_row * gh

            ' pass 1: solid block in inverted background colour
            src_rect.x = (219 Mod 16) * gw
            src_rect.y = (219 \ 16)   * gh
            SDL_SetTextureColorMod(vt_internal.sdl_texture, si_bg_r, si_bg_g, si_bg_b)
            SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)

            ' pass 2: original glyph in inverted foreground colour
            src_rect.x = (sl_ch Mod 16) * gw
            src_rect.y = (sl_ch \ 16)   * gh
            SDL_SetTextureColorMod(vt_internal.sdl_texture, si_fg_r, si_fg_g, si_fg_b)
            SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
        Next flat_cur
    End If

    ' --- cursor ---
    If vt_internal.sb_offset = 0 AndAlso vt_internal.cur_visible AndAlso _
       vt_internal.blink_visible Then
        c_col = vt_internal.cur_col - 1
        c_row = vt_internal.cur_row - 1
        cfg_r = vt_internal.palette(vt_internal.clr_fg * 3)
        cfg_g = vt_internal.palette(vt_internal.clr_fg * 3 + 1)
        cfg_b = vt_internal.palette(vt_internal.clr_fg * 3 + 2)
        src_rect.x = (vt_internal.cur_ch Mod 16) * gw
        src_rect.y = (vt_internal.cur_ch \ 16)   * gh
        dst_rect.x = c_col * gw
        dst_rect.y = c_row * gh
        SDL_SetTextureColorMod(vt_internal.sdl_texture, cfg_r, cfg_g, cfg_b)
        SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
    End If

    ' --- mouse cursor: inverted cell colors ---
    ' Chr(219) filled with inverted bg, original char on top with inverted fg.
    ' Always fully opaque -- readable on any background, no blending needed.
    ' Drawn last so it sits on top of text cursor and all cell content.
    ' vt_internal_display_cellptr reads from sb_cells or vis_buf as appropriate
    ' so the cursor stays visible and color-correct during scrollback.
    If vt_internal.mouse_on AndAlso vt_internal.mouse_vis Then
        Dim mc_col   As Long
        Dim mc_row   As Long
        Dim mc_cellptr As vt_cell Ptr
        Dim mc_ch    As UByte
        Dim mc_cfg   As UByte
        Dim mc_cbg   As UByte
        Dim inv_bg_r As UByte
        Dim inv_bg_g As UByte
        Dim inv_bg_b As UByte
        Dim inv_fg_r As UByte
        Dim inv_fg_g As UByte
        Dim inv_fg_b As UByte

        mc_col = vt_internal.mouse_col - 1
        mc_row = vt_internal.mouse_row - 1

        mc_cellptr = vt_internal_display_cellptr(mc_col, mc_row, vis_buf)
        mc_ch  = mc_cellptr->ch
        mc_cfg = mc_cellptr->fg And 15   ' strip blink bit before palette lookup
        mc_cbg = mc_cellptr->bg And 15

        ' Invert the actual palette RGB -- works with any custom palette
        inv_bg_r = 255 - vt_internal.palette(mc_cbg * 3)
        inv_bg_g = 255 - vt_internal.palette(mc_cbg * 3 + 1)
        inv_bg_b = 255 - vt_internal.palette(mc_cbg * 3 + 2)
        inv_fg_r = 255 - vt_internal.palette(mc_cfg * 3)
        inv_fg_g = 255 - vt_internal.palette(mc_cfg * 3 + 1)
        inv_fg_b = 255 - vt_internal.palette(mc_cfg * 3 + 2)

        dst_rect.x = mc_col * gw
        dst_rect.y = mc_row * gh

        ' Pass 1: Chr(219) solid block tinted with inverted bg -- fills the cell
        src_rect.x = (219 Mod 16) * gw
        src_rect.y = (219 \ 16)   * gh
        SDL_SetTextureColorMod(vt_internal.sdl_texture, inv_bg_r, inv_bg_g, inv_bg_b)
        SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)

        ' Pass 2: original char tinted with inverted fg -- draws the glyph on top
        src_rect.x = (mc_ch Mod 16) * gw
        src_rect.y = (mc_ch \ 16)   * gh
        SDL_SetTextureColorMod(vt_internal.sdl_texture, inv_fg_r, inv_fg_g, inv_fg_b)
        SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
    End If

    vt_internal.dirty = 0
    SDL_RenderPresent(vt_internal.sdl_renderer)
End Sub

' -----------------------------------------------------------------------------
' vt_shutdown - optional explicit teardown (auto-cleanup handles this on exit)
' Useful if you want to close the VT screen mid-program.
' -----------------------------------------------------------------------------
Sub vt_shutdown()
    vt_internal_shutdown()
End Sub

' -----------------------------------------------------------------------------
' vt_title - set the window title
' Safe to call before or after vt_screen().
' Before: stored and used when the window is created.
' After:  applied to the live window immediately.
' -----------------------------------------------------------------------------
Sub vt_title(txt As String)
    vt_internal.win_title = txt
    If vt_internal.ready Then
        SDL_SetWindowTitle(vt_internal.sdl_window, txt)
    End If
End Sub

' -----------------------------------------------------------------------------
' vt_scroll - scroll the scrollback view by amount lines
' Positive = scroll back (older content), negative = toward live view.
' Returns 1 if the offset changed, 0 if already at limit or scrollback disabled.
' Does not call vt_present -- caller handles that.
' -----------------------------------------------------------------------------
Function vt_scroll(amount As Long) As Byte
    If vt_internal.ready   = 0 Then Return 0
    If vt_internal.sb_lines = 0 Then Return 0
    If amount = 0               Then Return 0

    Dim prev As Long = vt_internal.sb_offset

    vt_internal.sb_offset += amount
    If vt_internal.sb_offset > vt_internal.sb_used Then _
        vt_internal.sb_offset = vt_internal.sb_used
    If vt_internal.sb_offset < 0 Then _
        vt_internal.sb_offset = 0

    If vt_internal.sb_offset = prev Then Return 0

    vt_internal.dirty = 1
    Return 1
End Function

' -----------------------------------------------------------------------------
' vt_screen_to_live_row - translate a screen row to the live vis_buf row,
' accounting for any active scrollback offset.
'
' During scrollback the scroll region rows no longer map 1:1 to vis_buf.
' Call this BEFORE snapping back with vt_scroll, while sb_offset is still set.
'
' Returns the 1-based vis_buf row that corresponds to screen_row, or 0 if that
' screen position is showing pure scrollback history with no live equivalent.
'
' Fixed rows outside view_top..view_bot are not affected by scrollback and are
' returned as-is. When sb_offset = 0 the function is a trivial pass-through.
'
' Typical click-to-locate pattern:
'   Dim lr As Long = vt_screen_to_live_row(my)
'   If lr > 0 Then
'       vt_scroll -99999
'       vt_locate lr, mx
'   End If
' -----------------------------------------------------------------------------
Function vt_screen_to_live_row(screen_row As Long) As Long
    Dim scroll_pos  As Long
    Dim logical_row As Long
    Dim live_r      As Long

    ' Pass-through: no scrollback active, or row is a fixed row outside the
    ' scroll region -- screen row equals live row in both cases.
    If vt_internal.sb_offset = 0 OrElse _
       screen_row < vt_internal.view_top OrElse _
       screen_row > vt_internal.view_bot Then
        Return screen_row
    End If

    ' Mirror the exact arithmetic used by the vt_present cell loop.
    scroll_pos  = (screen_row - 1) - (vt_internal.view_top - 1)
    logical_row = (vt_internal.sb_used - vt_internal.sb_offset) + scroll_pos
    If logical_row < 0 Then logical_row = 0

    If logical_row < vt_internal.sb_used Then
        ' Row is pure scrollback history -- no live buffer equivalent.
        Return 0
    End If

    ' Row is still within vis_buf. Compute its 1-based live row index.
    live_r = logical_row - vt_internal.sb_used + vt_internal.view_top
    Return live_r
End Function

' -----------------------------------------------------------------------------
' vt_scrollback - enable or resize the scrollback buffer
' Must be called after vt_screen(). Calling again clears the existing buffer.
' lines = 0 disables scrollback and frees the buffer.
' -----------------------------------------------------------------------------
Sub vt_scrollback(lines As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If
    vt_internal.sb_lines  = lines
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0
    If lines > 0 Then
        vt_internal.sb_cells = CAllocate(lines * vt_internal.scr_cols, SizeOf(vt_cell))
    End If
End Sub

' -----------------------------------------------------------------------------
' vt_page - set the active drawing page and the visible display page
' work : page index written to by all drawing commands (0..num_pages-1)
' vis  : page index rendered to screen by vt_present (0..num_pages-1)
' Default after vt_screen: both 0 -- identical to single-page behaviour.
' Classic double-buffer setup: vt_page(1, 0)
'   draw freely on page 1, page 0 stays clean until vt_pcopy(1, VT_VIDEO).
' Swapping back: vt_page(0, 0)
' Invalid indices are silently ignored.
' -----------------------------------------------------------------------------
Sub vt_page(work As Long, vis As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If work < 0 Or work >= vt_internal.num_pages Then Exit Sub
    If vis  < 0 Or vis  >= vt_internal.num_pages Then Exit Sub
    vt_internal.work_page = work
    vt_internal.vis_page  = vis
    vt_internal.cells     = vt_internal.page_buf(work)
    vt_internal.dirty     = 1
End Sub

' -----------------------------------------------------------------------------
' vt_pcopy - copy one page buffer to another
' Equivalent to QBasic PCOPY. Marks display dirty but does not call vt_present.
' src = dst is a no-op. Invalid indices are silently ignored.
' Typical use: vt_pcopy(1, VT_VIDEO) : vt_present()
' -----------------------------------------------------------------------------
Sub vt_pcopy(src As Long, dst As Long)
    If vt_internal.ready = 0 Then Exit Sub
    If src < 0 Or src >= vt_internal.num_pages Then Exit Sub
    If dst < 0 Or dst >= vt_internal.num_pages Then Exit Sub
    If src = dst Then Exit Sub
    Dim buf_sz As Long = vt_internal.scr_cols * vt_internal.scr_rows * SizeOf(vt_cell)
    CopyMemory(vt_internal.page_buf(dst), vt_internal.page_buf(src), buf_sz)
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' Palette API
' -----------------------------------------------------------------------------
Sub vt_palette_set(pal() As UByte)
    Dim pi As Long
    For pi = 0 To 47
        vt_internal.palette(pi) = pal(pi)
    Next pi
End Sub

Sub vt_palette_get(pal() As UByte)
    Dim pi As Long
    For pi = 0 To 47
        pal(pi) = vt_internal.palette(pi)
    Next pi
End Sub

' -----------------------------------------------------------------------------
' Palette API
' -----------------------------------------------------------------------------
' vt_palette: idx = -1 resets all 16 colours to CGA defaults.
'             idx = 0..15 sets one colour. r, g, b must be provided (0..255).
'             NOTE: r/g/b default to -1 purely to allow omitting them in the
'             reset case (idx = -1). When idx >= 0, always pass all three
'             channels explicitly -- omitting them produces 255 (white) because
'             -1 And 255 = 255.
Sub vt_palette(idx As Long = -1, r As Long = -1, g As Long = -1, b As Long = -1)
    If idx < 0 Or idx > 15 Then
        vt_palette_set(vt_default_palette())
        Exit Sub
    End If
    vt_internal.palette(idx * 3)     = r And 255
    vt_internal.palette(idx * 3 + 1) = g And 255
    vt_internal.palette(idx * 3 + 2) = b And 255
End Sub

' -----------------------------------------------------------------------------
' vt_border_color - letterbox colour outside the logical viewport
' -----------------------------------------------------------------------------
Sub vt_border_color(r As Long, g As Long, b As Long)
    vt_internal.border_r = r And 255
    vt_internal.border_g = g And 255
    vt_internal.border_b = b And 255
End Sub

' -----------------------------------------------------------------------------
' vt_key_repeat - configure key repeat timing
' -----------------------------------------------------------------------------
Sub vt_key_repeat(initial_ms As Long, rate_ms As Long)
    vt_internal.rep_initial = initial_ms
    vt_internal.rep_rate    = rate_ms
End Sub

' -----------------------------------------------------------------------------
' Query functions
' -----------------------------------------------------------------------------
Function vt_csrlin() As Long : Return vt_internal.cur_row  : End Function
Function vt_pos()    As Long : Return vt_internal.cur_col  : End Function
Function vt_cols()   As Long : Return vt_internal.scr_cols : End Function
Function vt_rows()   As Long : Return vt_internal.scr_rows : End Function

' -----------------------------------------------------------------------------
' vt_get_cell / vt_set_cell
' Both operate on the active work page (via vt_internal.cells).
' -----------------------------------------------------------------------------
Sub vt_get_cell(col As Long, row As Long, ByRef ch As UByte, ByRef fg As UByte, ByRef bg As UByte)
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    ch = cellptr->ch
    fg = cellptr->fg
    bg = cellptr->bg
End Sub

Sub vt_set_cell(col As Long, row As Long, ch As UByte, fg As UByte, bg As UByte)
    If vt_internal.ready = 0 Then Exit Sub
    If col < 1 Or col > vt_internal.scr_cols Then Exit Sub
    If row < 1 Or row > vt_internal.scr_rows Then Exit Sub
    Dim cellptr As vt_cell Ptr = vt_internal.cells + ((row - 1) * vt_internal.scr_cols + (col - 1))
    cellptr->ch = ch
    cellptr->fg = fg
    cellptr->bg = bg
    vt_internal.dirty = 1
End Sub

' -----------------------------------------------------------------------------
' Internal: auto-present for vt_inkey -- throttled, skips if not dirty
' -----------------------------------------------------------------------------
Sub vt_internal_present_if_dirty()
    If vt_internal.dirty = 0 Then Exit Sub
    Static last_auto_tick As ULong
    Dim now_tick As ULong
    now_tick = SDL_GetTicks()
    If now_tick - last_auto_tick < 2 Then Exit Sub
    vt_present()
    last_auto_tick = SDL_GetTicks()
End Sub

' -----------------------------------------------------------------------------
' vt_inkey - non-blocking key read
' -----------------------------------------------------------------------------
Function vt_inkey() As ULong
    If vt_internal.ready = 0 Then Return 0
    vt_pump()
    If vt_internal_blink_update() Then vt_internal.dirty = 1
    vt_internal_present_if_dirty()
    If vt_internal.key_count = 0 Then Return 0
    Dim evt As ULong = vt_internal.key_buf(vt_internal.key_read)
    vt_internal.key_read  = (vt_internal.key_read + 1) Mod VT_KEY_BUFFER_SIZE
    vt_internal.key_count -= 1
    Return evt
End Function

' -----------------------------------------------------------------------------
' vt_key_held - real-time key state poll for game loops
' -----------------------------------------------------------------------------
Function vt_key_held(vtscan As Long) As Byte
    Dim sdl_scan As Long
    Dim numkeys  As Long
    Dim states   As Const UByte Ptr

    Select Case vtscan
        Case VT_KEY_F1     : sdl_scan = SDL_SCANCODE_F1
        Case VT_KEY_F2     : sdl_scan = SDL_SCANCODE_F2
        Case VT_KEY_F3     : sdl_scan = SDL_SCANCODE_F3
        Case VT_KEY_F4     : sdl_scan = SDL_SCANCODE_F4
        Case VT_KEY_F5     : sdl_scan = SDL_SCANCODE_F5
        Case VT_KEY_F6     : sdl_scan = SDL_SCANCODE_F6
        Case VT_KEY_F7     : sdl_scan = SDL_SCANCODE_F7
        Case VT_KEY_F8     : sdl_scan = SDL_SCANCODE_F8
        Case VT_KEY_F9     : sdl_scan = SDL_SCANCODE_F9
        Case VT_KEY_F10    : sdl_scan = SDL_SCANCODE_F10
        Case VT_KEY_F11    : sdl_scan = SDL_SCANCODE_F11
        Case VT_KEY_F12    : sdl_scan = SDL_SCANCODE_F12
        Case VT_KEY_ESC    : sdl_scan = SDL_SCANCODE_ESCAPE
        Case VT_KEY_ENTER  : sdl_scan = SDL_SCANCODE_RETURN
        Case VT_KEY_BKSP   : sdl_scan = SDL_SCANCODE_BACKSPACE
        Case VT_KEY_TAB    : sdl_scan = SDL_SCANCODE_TAB
        Case VT_KEY_SPACE  : sdl_scan = SDL_SCANCODE_SPACE
        Case VT_KEY_UP     : sdl_scan = SDL_SCANCODE_UP
        Case VT_KEY_DOWN   : sdl_scan = SDL_SCANCODE_DOWN
        Case VT_KEY_LEFT   : sdl_scan = SDL_SCANCODE_LEFT
        Case VT_KEY_RIGHT  : sdl_scan = SDL_SCANCODE_RIGHT
        Case VT_KEY_HOME   : sdl_scan = SDL_SCANCODE_HOME
        Case VT_KEY_END    : sdl_scan = SDL_SCANCODE_END
        Case VT_KEY_PGUP   : sdl_scan = SDL_SCANCODE_PAGEUP
        Case VT_KEY_PGDN   : sdl_scan = SDL_SCANCODE_PAGEDOWN
        Case VT_KEY_INS    : sdl_scan = SDL_SCANCODE_INSERT
        Case VT_KEY_DEL    : sdl_scan = SDL_SCANCODE_DELETE
        Case VT_KEY_LSHIFT : sdl_scan = SDL_SCANCODE_LSHIFT
        Case VT_KEY_RSHIFT : sdl_scan = SDL_SCANCODE_RSHIFT
        Case VT_KEY_LCTRL  : sdl_scan = SDL_SCANCODE_LCTRL
        Case VT_KEY_RCTRL  : sdl_scan = SDL_SCANCODE_RCTRL
        Case VT_KEY_LALT   : sdl_scan = SDL_SCANCODE_LALT
        Case VT_KEY_RALT   : sdl_scan = SDL_SCANCODE_RALT
        Case VT_KEY_LWIN   : sdl_scan = SDL_SCANCODE_LGUI
        Case VT_KEY_RWIN   : sdl_scan = SDL_SCANCODE_RGUI
        Case Else          : Return 0
    End Select

    states = SDL_GetKeyboardState(@numkeys)
    If states = 0 Then Return 0
    If sdl_scan >= numkeys Then Return 0
    Return states[sdl_scan]
End Function

' -----------------------------------------------------------------------------
' vt_sleep
' ms = 0 : wait for any key
' ms > 0 : delay for ms milliseconds
' -----------------------------------------------------------------------------
Sub vt_sleep(ms As Long = 0)
    Dim t_start As ULong
    Dim t_now   As ULong
    Dim k       As ULong

    t_start = SDL_GetTicks()

    Do
        vt_pump()
        If vt_internal_blink_update() Then vt_internal.dirty = 1
        vt_internal_present_if_dirty()

        If ms = 0 Then
            k = vt_inkey()
            If k <> 0 Then Exit Do
            Sleep 10, 1
        Else
            t_now = SDL_GetTicks()
            If t_now - t_start >= CULng(ms) Then Exit Do
            Sleep 1, 1
        End If
    Loop
End Sub

' -----------------------------------------------------------------------------
' vt_getkey - blocking vt_inkey
' -----------------------------------------------------------------------------
Function vt_getkey() As ULong
    Dim k As ULong
    Do
        k = vt_inkey()
        If k <> 0 Then Return k
        Sleep 10, 1
    Loop
End Function

' -----------------------------------------------------------------------------
' vt_getchar - blocking single printable character
' -----------------------------------------------------------------------------
Function vt_getchar(allowed As String = "") As String
    Dim k  As ULong
    Dim ch As UByte
    Do
        k  = vt_getkey()
        ch = VT_CHAR(k)
        If ch >= 32 Then
            If allowed = "" Then Return Chr(ch)
            If InStr(allowed, Chr(ch)) > 0 Then Return Chr(ch)
        End If
    Loop
End Function

' -----------------------------------------------------------------------------
' vt_key_flush - discard all pending keys
' -----------------------------------------------------------------------------
Sub vt_key_flush()
    vt_internal.key_read  = 0
    vt_internal.key_write = 0
    vt_internal.key_count = 0
End Sub
