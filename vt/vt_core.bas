' =============================================================================
' vt_core.bas - VT Virtual Text Screen Library
' SDL2 window, cell buffer, blink timer, palette, vt_present.
' Compile as part of the VT library - not a standalone module.
' =============================================================================

#include once "vt.bi"

' forward declarations - defined later in this file
Declare Sub      vt_present()
Declare Sub      vt_shutdown()
Declare Function vt_init(cols_or_mode As Long, rows As Long = 0, flags As Long = VT_WINDOWED, scrollback As Long = 0) As Long


' -----------------------------------------------------------------------------
' Internal: push one key event ULong into the circular buffer
' Called from vt_internal_pump only.
' -----------------------------------------------------------------------------
Private Sub vt_internal_key_push(evt As ULong)
    If vt_internal.key_count >= VT_KEY_BUFFER_SIZE Then
        ' buffer full - drop oldest entry to make room
        vt_internal.key_read = (vt_internal.key_read + 1) Mod VT_KEY_BUFFER_SIZE
        vt_internal.key_count -= 1
    End If
    vt_internal.key_buf(vt_internal.key_write) = evt
    vt_internal.key_write = (vt_internal.key_write + 1) Mod VT_KEY_BUFFER_SIZE
    vt_internal.key_count += 1
End Sub


' -----------------------------------------------------------------------------
' Internal: map SDL scancode to VT scancode
' Returns 0 for keys we do not map (caller should still check ASCII).
' -----------------------------------------------------------------------------
Private Function vt_internal_sdl_to_vtscan(sdlscan As Long) As Long
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
' Internal: SDL event pump
' Must be called regularly to keep the window alive and fill the key buffer.
' Called automatically by vt_print, vt_cls, vt_present, vt_inkey, vt_input.
' User programs that do heavy computation without any VT calls should call
' vt_present() occasionally to keep the window responsive.
' -----------------------------------------------------------------------------
Sub vt_internal_pump()
    If vt_internal.ready = 0 Then Exit Sub

    Dim evt       As SDL_Event
    Dim modstate  As SDL_Keymod
    Dim vtscan    As Long
    Dim keyrec    As ULong
    Dim tick      As ULong
    Dim ascii_ch  As UByte

    ' --- handle key repeat via our own timer ---
    tick = SDL_GetTicks()
    If vt_internal.rep_scan <> 0 Then
        Dim rep_due As Long = 0
        If vt_internal.rep_last = 0 Then
            ' waiting for initial delay
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
            ' re-push the held key as a repeat event
            keyrec = vt_internal.key_buf((vt_internal.key_write + VT_KEY_BUFFER_SIZE - 1) _
                     Mod VT_KEY_BUFFER_SIZE)
            keyrec = keyrec Or (1UL Shl 28)   ' set repeat flag
            vt_internal_key_push(keyrec)
        End If
    End If

    ' --- drain SDL event queue ---
    While SDL_PollEvent(@evt)
        Select Case evt.type
            Case SDL_QUIT_
                ' signal shutdown - set a flag, user checks vt_should_quit()
                vt_internal.ready = 2   ' 2 = quit requested

            Case SDL_KEYDOWN
                ' build modifier flags
                modstate = SDL_GetModState()
                Dim sh As ULong = IIf((modstate And KMOD_SHIFT) <> 0, 1UL, 0UL)
                Dim ct As ULong = IIf((modstate And KMOD_CTRL)  <> 0, 1UL, 0UL)
                Dim al As ULong = IIf((modstate And KMOD_ALT)   <> 0, 1UL, 0UL)

                vtscan = vt_internal_sdl_to_vtscan(evt.key.keysym.scancode)

                ' built-in scrollback keys: Shift+PgUp / Shift+PgDn
                If sh AndAlso vtscan = VT_KEY_PGUP AndAlso vt_internal.sb_lines > 0 Then
                    vt_internal.sb_offset += vt_internal.scr_rows \ 2
                    If vt_internal.sb_offset > vt_internal.sb_used Then
                        vt_internal.sb_offset = vt_internal.sb_used
                    End If
                    vt_present()
                ElseIf sh AndAlso vtscan = VT_KEY_PGDN AndAlso vt_internal.sb_lines > 0 Then
                    vt_internal.sb_offset -= vt_internal.scr_rows \ 2
                    If vt_internal.sb_offset < 0 Then vt_internal.sb_offset = 0
                    vt_present()
                Else
                    ' ASCII for printable keys is delivered via SDL_TEXTINPUT,
                    ' so here we only push scancode + modifiers (ascii = 0).
                    ' Exception: Ctrl combos don't fire TEXTINPUT, handle them here.
                    ascii_ch = 0
                    If ct Then
                        Dim sym As Long = evt.key.keysym.sym
                        If sym >= SDLK_a AndAlso sym <= SDLK_z Then
                            ascii_ch = CByte(sym - SDLK_a + 1)  ' Ctrl+A=1 .. Ctrl+Z=26
                        End If
                    End If

                    keyrec = CULng(ascii_ch)        Or _
                             (CULng(vtscan) Shl 16) Or _
                             (sh Shl 29)             Or _
                             (ct Shl 30)             Or _
                             (al Shl 31)
                    vt_internal_key_push(keyrec)

                    ' start repeat tracking for this key
                    vt_internal.rep_scan = vtscan
                    vt_internal.rep_tick = tick
                    vt_internal.rep_last = 0
                End If

            Case SDL_KEYUP
                ' stop repeat if this is the key we were tracking
                If vt_internal_sdl_to_vtscan(evt.key.keysym.scancode) = vt_internal.rep_scan Then
                    vt_internal.rep_scan = 0
                    vt_internal.rep_last = 0
                End If

            Case SDL_TEXTINPUT
                ' one printable character (already layout/IME processed by OS)
                ' evt.text.text is a null-terminated UTF-8 string
                ' We take only the first byte - for CP437 range this is correct
                Dim ch As UByte = CPtr(UByte Ptr, @evt.text.text)[0]
                If ch >= 32 AndAlso ch <> 127 Then
                    ' re-use the scancode from the last keydown we recorded
                    keyrec = CULng(ch) Or (CULng(vt_internal.rep_scan) Shl 16)
                    ' modifiers: SDL_GetModState() still valid here
                    modstate = SDL_GetModState()
                    If (modstate And KMOD_SHIFT) Then keyrec = keyrec Or (1UL Shl 29)
                    If (modstate And KMOD_CTRL)  Then keyrec = keyrec Or (1UL Shl 30)
                    If (modstate And KMOD_ALT)   Then keyrec = keyrec Or (1UL Shl 31)
                    ' overwrite the bare-scancode event we pushed in KEYDOWN with this
                    ' richer version (pop last, push new)
                    If vt_internal.key_count > 0 Then
                        vt_internal.key_write = (vt_internal.key_write + VT_KEY_BUFFER_SIZE - 1) _
                                                Mod VT_KEY_BUFFER_SIZE
                        vt_internal.key_count -= 1
                    End If
                    vt_internal_key_push(keyrec)
                End If

            Case SDL_WINDOWEVENT
                If evt.window.event = SDL_WINDOWEVENT_RESIZED Then
                    ' window was resized - snap to nearest cell-grid multiple
                    Dim new_w As Long = evt.window.data1
                    Dim new_h As Long = evt.window.data2
                    Dim snapped_w As Long = (new_w \ vt_internal.glyph_w) * vt_internal.glyph_w
                    Dim snapped_h As Long = (new_h \ vt_internal.glyph_h) * vt_internal.glyph_h
                    If snapped_w < vt_internal.glyph_w Then snapped_w = vt_internal.glyph_w
                    If snapped_h < vt_internal.glyph_h Then snapped_h = vt_internal.glyph_h
                    SDL_SetWindowSize(vt_internal.sdl_window, snapped_w, snapped_h)
                    vt_present()
                End If

        End Select
    Wend
End Sub


' -----------------------------------------------------------------------------
' Internal: update blink phase based on elapsed time
' Returns 1 if the phase changed (caller may want to re-present)
' -----------------------------------------------------------------------------
Private Function vt_internal_blink_update() As Byte
    Dim tick As ULong = SDL_GetTicks()
    If tick - vt_internal.blink_tick >= VT_BLINK_MS Then
        vt_internal.blink_visible = 1 - vt_internal.blink_visible
        vt_internal.blink_tick    = tick
        Return 1
    End If
    Return 0
End Function


' -----------------------------------------------------------------------------
' vt_present - compose and display the cell buffer
' Called automatically by vt_print family. Call manually after vt_set_cell loops.
'
' Rendering strategy: GPU-accelerated blit via SDL_RenderFillRect + SDL_RenderCopy.
' The font texture (sdl_texture) holds all 256 glyphs, white on transparent.
' Per cell: fill bg rect, colormod the font texture to fg colour, blit glyph.
' This replaces the old pixel-by-pixel streaming texture lock which was ~0.5s
' per full screen fill. GPU path is effectively instant.
' -----------------------------------------------------------------------------
Sub vt_present()
    If vt_internal.ready = 0 Then Exit Sub

    vt_internal_blink_update()

    Dim cells_src As vt_cell Ptr
    If vt_internal.sb_offset > 0 Then
        ' scrollback view - compute pointer into scrollback buffer
        Dim sb_row As Long = vt_internal.sb_used - vt_internal.sb_offset
        If sb_row < 0 Then sb_row = 0
        cells_src = vt_internal.sb_cells + (sb_row * vt_internal.scr_cols)
    Else
        cells_src = vt_internal.cells
    End If

    Dim gw   As Long = vt_internal.glyph_w
    Dim gh   As Long = vt_internal.glyph_h
    Dim cols As Long = vt_internal.scr_cols
    Dim rows As Long = vt_internal.scr_rows

    SDL_RenderClear(vt_internal.sdl_renderer)

    Dim src_rect As SDL_Rect
    Dim dst_rect As SDL_Rect
    src_rect.w = gw
    src_rect.h = gh
    dst_rect.w = gw
    dst_rect.h = gh

    Dim row_idx As Long
    Dim col_idx As Long
    Dim last_fg_r As UByte = 255
    Dim last_fg_g As UByte = 255
    Dim last_fg_b As UByte = 255

    For row_idx = 0 To rows - 1
        For col_idx = 0 To cols - 1
            Dim cellptr As vt_cell Ptr = cells_src + (row_idx * cols + col_idx)
            Dim ch  As UByte = cellptr->ch
            Dim fg  As UByte = cellptr->fg
            Dim bg  As UByte = cellptr->bg

            ' blink: blink bit set and phase off -> render fg as bg (invisible)
            If (fg And 16) AndAlso vt_internal.blink_visible = 0 Then fg = bg
            fg = fg And 15

            Dim fg_r As UByte = vt_internal.palette(fg * 3)
            Dim fg_g As UByte = vt_internal.palette(fg * 3 + 1)
            Dim fg_b As UByte = vt_internal.palette(fg * 3 + 2)
            Dim bg_r As UByte = vt_internal.palette(bg * 3)
            Dim bg_g As UByte = vt_internal.palette(bg * 3 + 1)
            Dim bg_b As UByte = vt_internal.palette(bg * 3 + 2)

            dst_rect.x = col_idx * gw
            dst_rect.y = row_idx * gh

            ' fill background colour
            SDL_SetRenderDrawColor(vt_internal.sdl_renderer, bg_r, bg_g, bg_b, 255)
            SDL_RenderFillRect(vt_internal.sdl_renderer, @dst_rect)

            ' blit glyph - skip colormod call if fg colour unchanged from last cell
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

    ' draw cursor on top if visible and not in scrollback view
    If vt_internal.sb_offset = 0 AndAlso vt_internal.cur_visible AndAlso _
       vt_internal.blink_visible Then
        Dim c_col As Long = vt_internal.cur_col - 1
        Dim c_row As Long = vt_internal.cur_row - 1
        Dim cfg_r As UByte = vt_internal.palette(vt_internal.clr_fg * 3)
        Dim cfg_g As UByte = vt_internal.palette(vt_internal.clr_fg * 3 + 1)
        Dim cfg_b As UByte = vt_internal.palette(vt_internal.clr_fg * 3 + 2)
        src_rect.x = (vt_internal.cur_ch Mod 16) * gw
        src_rect.y = (vt_internal.cur_ch \ 16)   * gh
        dst_rect.x = c_col * gw
        dst_rect.y = c_row * gh
        SDL_SetTextureColorMod(vt_internal.sdl_texture, cfg_r, cfg_g, cfg_b)
        SDL_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
    End If

    vt_internal.dirty = 0
    SDL_RenderPresent(vt_internal.sdl_renderer)
End Sub


' -----------------------------------------------------------------------------
' vt_init_impl - core initialisation, called by both vt_init overloads
' -----------------------------------------------------------------------------
Function vt_init_impl(cols As Long, rows As Long, glyph_w As Long, glyph_h As Long, _
                      flags As Long, scrollback As Long) As Long

    If vt_internal.ready Then vt_shutdown()  ' re-init: clean up first

    ' --- SDL2 init ---
    If SDL_Init(SDL_INIT_VIDEO) <> 0 Then Return -1

    ' --- window flags ---
    Dim wflags As ULong = SDL_WINDOW_SHOWN
    If (flags And VT_NO_RESIZE) = 0 Then wflags = wflags Or SDL_WINDOW_RESIZABLE

    Dim win_w As Long = cols * glyph_w
    Dim win_h As Long = rows * glyph_h

    vt_internal.sdl_window = SDL_CreateWindow("VT", _
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, _
        win_w, win_h, wflags)
    If vt_internal.sdl_window = 0 Then
        SDL_Quit()
        Return -2
    End If

    ' --- fullscreen ---
    If flags And VT_FULLSCREEN_ASPECT Then
        SDL_SetWindowFullscreen(vt_internal.sdl_window, SDL_WINDOW_FULLSCREEN_DESKTOP)
    ElseIf flags And VT_FULLSCREEN_STRETCH Then
        SDL_SetWindowFullscreen(vt_internal.sdl_window, SDL_WINDOW_FULLSCREEN)
    End If

    ' --- renderer with vsync ---
    Dim rflags As ULong = SDL_RENDERER_ACCELERATED
    If flags And VT_VSYNC Then rflags = rflags Or SDL_RENDERER_PRESENTVSYNC
    vt_internal.sdl_renderer = SDL_CreateRenderer(vt_internal.sdl_window, -1, rflags)
    If vt_internal.sdl_renderer = 0 Then
        SDL_DestroyWindow(vt_internal.sdl_window)
        SDL_Quit()
        Return -3
    End If

    If flags And VT_FULLSCREEN_ASPECT Then
        SDL_RenderSetIntegerScale(vt_internal.sdl_renderer, SDL_TRUE)
        SDL_RenderSetLogicalSize(vt_internal.sdl_renderer, win_w, win_h)
    End If

    ' --- build font surface: 16x16 glyph grid, white glyphs on transparent bg ---
    ' ARGB8888, glyph pixels = &hFFFFFFFF (white, opaque)
    '           bg pixels    = &h00000000 (transparent - lets RenderFillRect bg show through)
    Dim font_surf As SDL_Surface Ptr
    font_surf = SDL_CreateRGBSurface(0, 16 * glyph_w, 16 * glyph_h, 32, _
        &h00FF0000, &h0000FF00, &h000000FF, &hFF000000)
    If font_surf = 0 Then
        SDL_DestroyRenderer(vt_internal.sdl_renderer)
        SDL_DestroyWindow(vt_internal.sdl_window)
        SDL_Quit()
        Return -4
    End If

    ' paint all 256 glyphs into the surface
    SDL_LockSurface(font_surf)
    Dim surf_px    As ULong Ptr = CPtr(ULong Ptr, font_surf->pixels)
    Dim surf_pitch As Long      = font_surf->pitch \ 4  ' pitch in pixels (ULong stride)
    Dim glyph_idx  As Long
    For glyph_idx = 0 To 255
        Dim gx As Long = (glyph_idx Mod 16) * glyph_w
        Dim gy As Long = (glyph_idx \ 16)   * glyph_h
        Dim glyph_row As Long
        For glyph_row = 0 To glyph_h - 1
            Dim font_byte As UByte = vt_font_data(glyph_idx * glyph_h + glyph_row)
            Dim bit_idx As Long
            For bit_idx = 0 To glyph_w - 1
                Dim on_px As Byte = (font_byte Shr (7 - bit_idx)) And 1
                ' opaque white for glyph pixels, fully transparent for background
                surf_px[(gy + glyph_row) * surf_pitch + gx + bit_idx] = _
                    IIf(on_px, &hFFFFFFFF, &h00000000)
            Next bit_idx
        Next glyph_row
    Next glyph_idx
    SDL_UnlockSurface(font_surf)

    ' convert surface to GPU texture and enable alpha blending
    vt_internal.sdl_texture = SDL_CreateTextureFromSurface(vt_internal.sdl_renderer, font_surf)
    SDL_FreeSurface(font_surf)   ' surface no longer needed - GPU texture owns the data
    vt_internal.sdl_font = 0    ' not stored - freed above

    If vt_internal.sdl_texture = 0 Then
        SDL_DestroyRenderer(vt_internal.sdl_renderer)
        SDL_DestroyWindow(vt_internal.sdl_window)
        SDL_Quit()
        Return -5
    End If

    SDL_SetTextureBlendMode(vt_internal.sdl_texture, SDL_BLENDMODE_BLEND)

    ' --- store geometry ---
    vt_internal.scr_cols = cols
    vt_internal.scr_rows = rows
    vt_internal.glyph_w  = glyph_w
    vt_internal.glyph_h  = glyph_h

    ' --- allocate cell buffer ---
    Dim cell_count As Long = cols * rows
    vt_internal.cells = CAllocate(cell_count, SizeOf(vt_cell))
    If vt_internal.cells = 0 Then Return -6

    ' --- allocate scrollback buffer ---
    vt_internal.sb_lines  = scrollback
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0
    If scrollback > 0 Then
        vt_internal.sb_cells = CAllocate(scrollback * cols, SizeOf(vt_cell))
    Else
        vt_internal.sb_cells = 0
    End If

    ' --- allocate page save slots (null until first use) ---
    Dim sl As Long
    For sl = 0 To VT_PAGE_SLOTS - 1
        vt_internal.page_slot(sl) = 0
    Next sl

    ' --- cursor defaults ---
    vt_internal.cur_col     = 1
    vt_internal.cur_row     = 1
    vt_internal.cur_visible = 1
    vt_internal.cur_ch      = 219

    ' --- colour defaults ---
    vt_internal.clr_fg = VT_LIGHT_GREY
    vt_internal.clr_bg = VT_BLACK

    ' --- scroll defaults ---
    vt_internal.scroll_on = 1
    vt_internal.view_top  = 1
    vt_internal.view_bot  = rows

    ' --- blink ---
    vt_internal.blink_visible = 1
    vt_internal.blink_tick    = SDL_GetTicks()
    
    ' --- dirty starts clean (first present will draw the blank screen) ---
    vt_internal.dirty = 0

    ' --- key repeat defaults ---
    vt_internal.rep_scan    = 0
    vt_internal.rep_initial = VT_KEY_REPEAT_INITIAL
    vt_internal.rep_rate    = VT_KEY_REPEAT_RATE

    ' --- mouse off ---
    vt_internal.mouse_on  = 0
    vt_internal.mouse_ch  = 219
    vt_internal.mouse_fg  = VT_WHITE
    vt_internal.mouse_bg  = VT_BLACK

    ' --- apply default palette ---
    Dim pi As Long
    For pi = 0 To 47
        vt_internal.palette(pi) = vt_default_palette(pi)
    Next pi

    ' --- mark ready and do first present ---
    vt_internal.ready = 1
    vt_present()

    Return 0
End Function


' -----------------------------------------------------------------------------
' vt_init - mode constant or explicit cols/rows
' -----------------------------------------------------------------------------
Function vt_init(cols_or_mode As Long, rows As Long = 0, flags As Long = VT_WINDOWED, scrollback As Long = 0) As Long
    Dim cols As Long
    Dim rws  As Long
    Dim gw   As Long
    Dim gh   As Long

    If rows = 0 Then
        Select Case cols_or_mode
            Case VT_MODE_80x25 : cols = 80 : rws = 25 : gw = 8  : gh = 16
            Case VT_MODE_80x43 : cols = 80 : rws = 43 : gw = 8  : gh = 8
            Case VT_MODE_80x50 : cols = 80 : rws = 50 : gw = 8  : gh = 8
            Case VT_MODE_40x25 : cols = 40 : rws = 25 : gw = 16 : gh = 16
            Case Else           : cols = 80 : rws = 25 : gw = 8  : gh = 16
        End Select
    Else
        cols = cols_or_mode
        rws  = rows
        gw   = 8
        gh   = IIf(rws <= 30, 16, 8)
    End If

    Return vt_init_impl(cols, rws, gw, gh, flags, scrollback)
End Function


' -----------------------------------------------------------------------------
' vt_shutdown - free all SDL resources and reset state
' -----------------------------------------------------------------------------
Sub vt_shutdown()
    If vt_internal.ready = 0 Then Exit Sub
    vt_internal.ready = 0

    ' free page slots
    Dim sl As Long
    For sl = 0 To VT_PAGE_SLOTS - 1
        If vt_internal.page_slot(sl) <> 0 Then
            DeAllocate vt_internal.page_slot(sl)
            vt_internal.page_slot(sl) = 0
        End If
    Next sl

    ' free cell buffers
    If vt_internal.cells    <> 0 Then DeAllocate vt_internal.cells    : vt_internal.cells    = 0
    If vt_internal.sb_cells <> 0 Then DeAllocate vt_internal.sb_cells : vt_internal.sb_cells = 0

    ' free SDL objects (sdl_font is always 0 after init - freed there)
    If vt_internal.sdl_texture  <> 0 Then SDL_DestroyTexture(vt_internal.sdl_texture)  : vt_internal.sdl_texture  = 0
    If vt_internal.sdl_renderer <> 0 Then SDL_DestroyRenderer(vt_internal.sdl_renderer): vt_internal.sdl_renderer = 0
    If vt_internal.sdl_window   <> 0 Then SDL_DestroyWindow(vt_internal.sdl_window)    : vt_internal.sdl_window   = 0

    SDL_Quit()
End Sub


' -----------------------------------------------------------------------------
' vt_should_quit - returns 1 if the user closed the window
' -----------------------------------------------------------------------------
Function vt_should_quit() As Byte
    Return IIf(vt_internal.ready = 2, 1, 0)
End Function


' -----------------------------------------------------------------------------
' Palette API
' -----------------------------------------------------------------------------
Sub vt_palette(idx As Long, r As Long, g As Long, b As Long)
    If idx < 0 Or idx > 15 Then Exit Sub
    vt_internal.palette(idx * 3)     = r And 255
    vt_internal.palette(idx * 3 + 1) = g And 255
    vt_internal.palette(idx * 3 + 2) = b And 255
End Sub

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
' Key repeat config
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
' vt_inkey - non-blocking key read
' Pumps events, redraws if blink phase changed, pops one key from the buffer.
' Returns 0 if no key is waiting.
' -----------------------------------------------------------------------------
Function vt_inkey() As ULong
    If vt_internal.ready = 0 Then Return 0
    vt_internal_pump()
    If vt_internal_blink_update() Then vt_internal.dirty = 1
    If vt_internal.dirty Then vt_present()
    If vt_internal.key_count = 0 Then Return 0
    Dim evt As ULong = vt_internal.key_buf(vt_internal.key_read)
    vt_internal.key_read  = (vt_internal.key_read + 1) Mod VT_KEY_BUFFER_SIZE
    vt_internal.key_count -= 1
    Return evt
End Function


' -----------------------------------------------------------------------------
' vt_key_flush - discard all pending keys in the buffer
' -----------------------------------------------------------------------------
Sub vt_key_flush()
    vt_internal.key_read  = 0
    vt_internal.key_write = 0
    vt_internal.key_count = 0
End Sub
