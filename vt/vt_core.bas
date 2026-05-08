' =============================================================================
' vt_core.bas - VT Virtual Text Screen Library
' =============================================================================
Declare Sub      vt_present()
Declare Sub      vt_on_close(cb As Function() As Byte)
Declare Sub      vt_shutdown()
Declare Sub      vt_internal_shutdown()
Declare Function vt_screen(mode As Long = VT_SCREEN_0, flags As Long = VT_WINDOWED, pages As Long = 1) As Long
Declare Function vt_scroll(amount As Long) As Byte
Declare Sub      vt_internal_scroll_rect(amount As Long)
Declare Sub      vt_internal_pixel_to_cell(px As Long, py As Long, col_out As Long Ptr, row_out As Long Ptr)
Declare Function vt_internal_display_cellptr(col As Long, row_0 As Long, vis_buf As vt_cell Ptr) As vt_cell Ptr
Declare Sub      vt_internal_cp_build_text()
Declare Function vt_internal_build_embedded_tex() As _VT_DRV_Texture Ptr
#Ifdef VT_USE_SOUND
    Declare Sub  vt_internal_sound_shutdown()
#Endif

Function vt_internal_ticks() As ULong
    Return _VT_DRV_GetTicks()
End Function

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
        Case _VT_DRV_SCANCODE_F1      : Return VT_KEY_F1
        Case _VT_DRV_SCANCODE_F2      : Return VT_KEY_F2
        Case _VT_DRV_SCANCODE_F3      : Return VT_KEY_F3
        Case _VT_DRV_SCANCODE_F4      : Return VT_KEY_F4
        Case _VT_DRV_SCANCODE_F5      : Return VT_KEY_F5
        Case _VT_DRV_SCANCODE_F6      : Return VT_KEY_F6
        Case _VT_DRV_SCANCODE_F7      : Return VT_KEY_F7
        Case _VT_DRV_SCANCODE_F8      : Return VT_KEY_F8
        Case _VT_DRV_SCANCODE_F9      : Return VT_KEY_F9
        Case _VT_DRV_SCANCODE_F10     : Return VT_KEY_F10
        Case _VT_DRV_SCANCODE_F11     : Return VT_KEY_F11
        Case _VT_DRV_SCANCODE_F12     : Return VT_KEY_F12
        Case _VT_DRV_SCANCODE_UP      : Return VT_KEY_UP
        Case _VT_DRV_SCANCODE_DOWN    : Return VT_KEY_DOWN
        Case _VT_DRV_SCANCODE_LEFT    : Return VT_KEY_LEFT
        Case _VT_DRV_SCANCODE_RIGHT   : Return VT_KEY_RIGHT
        Case _VT_DRV_SCANCODE_HOME    : Return VT_KEY_HOME
        Case _VT_DRV_SCANCODE_END     : Return VT_KEY_END
        Case _VT_DRV_SCANCODE_PAGEUP  : Return VT_KEY_PGUP
        Case _VT_DRV_SCANCODE_PAGEDOWN: Return VT_KEY_PGDN
        Case _VT_DRV_SCANCODE_INSERT  : Return VT_KEY_INS
        Case _VT_DRV_SCANCODE_DELETE  : Return VT_KEY_DEL
        Case _VT_DRV_SCANCODE_ESCAPE  : Return VT_KEY_ESC
        Case _VT_DRV_SCANCODE_RETURN  : Return VT_KEY_ENTER
        Case _VT_DRV_SCANCODE_KP_ENTER: Return VT_KEY_ENTER
        Case _VT_DRV_SCANCODE_BACKSPACE:Return VT_KEY_BKSP
        Case _VT_DRV_SCANCODE_TAB     : Return VT_KEY_TAB
        Case _VT_DRV_SCANCODE_SPACE   : Return VT_KEY_SPACE
        Case _VT_DRV_SCANCODE_LSHIFT  : Return VT_KEY_LSHIFT
        Case _VT_DRV_SCANCODE_RSHIFT  : Return VT_KEY_RSHIFT
        Case _VT_DRV_SCANCODE_LCTRL   : Return VT_KEY_LCTRL
        Case _VT_DRV_SCANCODE_RCTRL   : Return VT_KEY_RCTRL
        Case _VT_DRV_SCANCODE_LALT    : Return VT_KEY_LALT
        Case _VT_DRV_SCANCODE_RALT    : Return VT_KEY_RALT
        Case _VT_DRV_SCANCODE_LGUI    : Return VT_KEY_LWIN
        Case _VT_DRV_SCANCODE_RGUI    : Return VT_KEY_RWIN
    End Select
    Return 0
End Function

' -----------------------------------------------------------------------------
' Internal: convert raw SDL window pixel coords to 1-based cell coords.
' Uses _VT_DRV_RenderGetScale so the result is correct under all window modes:
' VT_WINDOWED, VT_FULLSCREEN_ASPECT (integer scale), VT_FULLSCREEN_STRETCH,
' and maximized windows. No stored flags needed -- SDL tells us what it used.
' -----------------------------------------------------------------------------
Sub vt_internal_pixel_to_cell(px As Long, py As Long, col_out As Long Ptr, row_out As Long Ptr)
    Dim sx    As Single
    Dim sy    As Single
    Dim out_w As Long
    Dim out_h As Long
    Dim vp_x  As Long
    Dim vp_y  As Long
    Dim log_w As Long
    Dim log_h As Long

    _VT_DRV_RenderGetScale(vt_internal.sdl_renderer, @sx, @sy)
    _VT_DRV_GetRendererOutputSize(vt_internal.sdl_renderer, @out_w, @out_h)

    log_w = vt_internal.scr_cols * vt_internal.glyph_w
    log_h = vt_internal.scr_rows * vt_internal.glyph_h

    ' Letterbox offset in output pixels -- matches what SDL computed internally
    vp_x = (out_w - CLng(log_w * sx)) \ 2
    vp_y = (out_h - CLng(log_h * sy)) \ 2

    ' Convert to logical pixel, then to 1-based cell
    *col_out = CLng((px - vp_x) / sx) \ vt_internal.glyph_w + 1
    *row_out = CLng((py - vp_y) / sy) \ vt_internal.glyph_h + 1
End Sub


' =============================================================================
' vt_internal_unicode_to_cp437
' Map a Unicode codepoint to its CP437 byte equivalent.
' Returns 0 if there is no CP437 mapping (caller should discard the byte).
' Covers CP437 1..31 (graphical low chars), 127, and 128..255.
' =============================================================================
Function vt_internal_unicode_to_cp437(codepoint As Long) As UByte
    Select Case codepoint
        ' --- CP437 1..31 : graphical low chars ---
        Case &h263A : Return 1    ' ☺
        Case &h263B : Return 2    ' ☻
        Case &h2665 : Return 3    ' ♥
        Case &h2666 : Return 4    ' ♦
        Case &h2663 : Return 5    ' ♣
        Case &h2660 : Return 6    ' ♠
        Case &h2022 : Return 7    ' •
        Case &h25D8 : Return 8    ' ◘
        Case &h25CB : Return 9    ' ○
        Case &h25D9 : Return 10   ' ◙
        Case &h2642 : Return 11   ' ♂
        Case &h2640 : Return 12   ' ♀
        Case &h266A : Return 13   ' ♪
        Case &h266B : Return 14   ' ♫
        Case &h263C : Return 15   ' ☼
        Case &h25BA : Return 16   ' ►
        Case &h25C4 : Return 17   ' ◄
        Case &h2195 : Return 18   ' ↕
        Case &h203C : Return 19   ' ‼
        Case &h00B6 : Return 20   ' ¶
        Case &h00A7 : Return 21   ' §
        Case &h25AC : Return 22   ' ▬
        Case &h21A8 : Return 23   ' ↨
        Case &h2191 : Return 24   ' ↑
        Case &h2193 : Return 25   ' ↓
        Case &h2192 : Return 26   ' →
        Case &h2190 : Return 27   ' ←
        Case &h221F : Return 28   ' ∟
        Case &h2194 : Return 29   ' ↔
        Case &h25B2 : Return 30   ' ▲
        Case &h25BC : Return 31   ' ▼
        ' --- CP437 127 ---
        Case &h2302 : Return 127  ' ⌂
        ' --- CP437 128..159 ---
        Case &h00C7 : Return 128  ' Ç
        Case &h00FC : Return 129  ' ü
        Case &h00E9 : Return 130  ' é
        Case &h00E2 : Return 131  ' â
        Case &h00E4 : Return 132  ' ä
        Case &h00E0 : Return 133  ' à
        Case &h00E5 : Return 134  ' å
        Case &h00E7 : Return 135  ' ç
        Case &h00EA : Return 136  ' ê
        Case &h00EB : Return 137  ' ë
        Case &h00E8 : Return 138  ' è
        Case &h00EF : Return 139  ' ï
        Case &h00EE : Return 140  ' î
        Case &h00EC : Return 141  ' ì
        Case &h00C4 : Return 142  ' Ä
        Case &h00C5 : Return 143  ' Å
        Case &h00C9 : Return 144  ' É
        Case &h00E6 : Return 145  ' æ
        Case &h00C6 : Return 146  ' Æ
        Case &h00F4 : Return 147  ' ô
        Case &h00F6 : Return 148  ' ö
        Case &h00F2 : Return 149  ' ò
        Case &h00FB : Return 150  ' û
        Case &h00F9 : Return 151  ' ù
        Case &h00FF : Return 152  ' ÿ
        Case &h00D6 : Return 153  ' Ö
        Case &h00DC : Return 154  ' Ü
        Case &h00A2 : Return 155  ' ¢
        Case &h00A3 : Return 156  ' £
        Case &h00A5 : Return 157  ' ¥
        Case &h20A7 : Return 158  ' ₧
        Case &h0192 : Return 159  ' ƒ
        ' --- CP437 160..175 ---
        Case &h00E1 : Return 160  ' á
        Case &h00ED : Return 161  ' í
        Case &h00F3 : Return 162  ' ó
        Case &h00FA : Return 163  ' ú
        Case &h00F1 : Return 164  ' ñ
        Case &h00D1 : Return 165  ' Ñ
        Case &h00AA : Return 166  ' ª
        Case &h00BA : Return 167  ' º
        Case &h00BF : Return 168  ' ¿
        Case &h2310 : Return 169  ' ⌐
        Case &h00AC : Return 170  ' ¬
        Case &h00BD : Return 171  ' ½
        Case &h00BC : Return 172  ' ¼
        Case &h00A1 : Return 173  ' ¡
        Case &h00AB : Return 174  ' «
        Case &h00BB : Return 175  ' »
        ' --- CP437 176..223 : box drawing and blocks ---
        Case &h2591 : Return 176  ' ░
        Case &h2592 : Return 177  ' ▒
        Case &h2593 : Return 178  ' ▓
        Case &h2502 : Return 179  ' │
        Case &h2524 : Return 180  ' ┤
        Case &h2561 : Return 181  ' ╡
        Case &h2562 : Return 182  ' ╢
        Case &h2556 : Return 183  ' ╖
        Case &h2555 : Return 184  ' ╕
        Case &h2563 : Return 185  ' ╣
        Case &h2551 : Return 186  ' ║
        Case &h2557 : Return 187  ' ╗
        Case &h255D : Return 188  ' ╝
        Case &h255C : Return 189  ' ╜
        Case &h255B : Return 190  ' ╛
        Case &h2510 : Return 191  ' ┐
        Case &h2514 : Return 192  ' └
        Case &h2534 : Return 193  ' ┴
        Case &h252C : Return 194  ' ┬
        Case &h251C : Return 195  ' ├
        Case &h2500 : Return 196  ' ─
        Case &h253C : Return 197  ' ┼
        Case &h255E : Return 198  ' ╞
        Case &h255F : Return 199  ' ╟
        Case &h255A : Return 200  ' ╚
        Case &h2554 : Return 201  ' ╔
        Case &h2569 : Return 202  ' ╩
        Case &h2566 : Return 203  ' ╦
        Case &h2560 : Return 204  ' ╠
        Case &h2550 : Return 205  ' ═
        Case &h256C : Return 206  ' ╬
        Case &h2567 : Return 207  ' ╧
        Case &h2568 : Return 208  ' ╨
        Case &h2564 : Return 209  ' ╤
        Case &h2565 : Return 210  ' ╥
        Case &h2559 : Return 211  ' ╙
        Case &h2558 : Return 212  ' ╘
        Case &h2552 : Return 213  ' ╒
        Case &h2553 : Return 214  ' ╓
        Case &h256B : Return 215  ' ╫
        Case &h256A : Return 216  ' ╪
        Case &h2518 : Return 217  ' ┘
        Case &h250C : Return 218  ' ┌
        Case &h2588 : Return 219  ' █
        Case &h2584 : Return 220  ' ▄
        Case &h258C : Return 221  ' ▌
        Case &h2590 : Return 222  ' ▐
        Case &h2580 : Return 223  ' ▀
        ' --- CP437 224..255 : Greek / math / misc ---
        Case &h03B1 : Return 224  ' α
        Case &h00DF : Return 225  ' ß
        Case &h0393 : Return 226  ' Γ
        Case &h03C0 : Return 227  ' π
        Case &h03A3 : Return 228  ' Σ
        Case &h03C3 : Return 229  ' σ
        Case &h00B5 : Return 230  ' µ
        Case &h03C4 : Return 231  ' τ
        Case &h03A6 : Return 232  ' Φ
        Case &h0398 : Return 233  ' Θ
        Case &h03A9 : Return 234  ' Ω
        Case &h03B4 : Return 235  ' δ
        Case &h221E : Return 236  ' ∞
        Case &h03C6 : Return 237  ' φ
        Case &h03B5 : Return 238  ' ε
        Case &h2229 : Return 239  ' ∩
        Case &h2261 : Return 240  ' ≡
        Case &h00B1 : Return 241  ' ±
        Case &h2265 : Return 242  ' ≥
        Case &h2264 : Return 243  ' ≤
        Case &h2320 : Return 244  ' ⌠
        Case &h2321 : Return 245  ' ⌡
        Case &h00F7 : Return 246  ' ÷
        Case &h2248 : Return 247  ' ≈
        Case &h00B0 : Return 248  ' °
        Case &h2219 : Return 249  ' ∙
        Case &h00B7 : Return 250  ' ·
        Case &h221A : Return 251  ' √
        Case &h207F : Return 252  ' ⁿ
        Case &h00B2 : Return 253  ' ²
        Case &h25A0 : Return 254  ' ■
        Case &h00A0 : Return 255  ' non-breaking space
    End Select
    Return 0   ' no CP437 equivalent
End Function

' -----------------------------------------------------------------------------
' Internal: event pump
' -----------------------------------------------------------------------------
Sub vt_pump()
    If vt_internal.ready = 0 Then Exit Sub

    Static pump_active As Byte
    If pump_active Then Exit Sub
    pump_active = 1

    Dim evt       As _VT_DRV_Event
    Dim modstate  As _VT_DRV_Keymod
    Dim vtscan    As Long
    Dim keyrec    As ULong
    Dim tick      As ULong
    Dim ascii_ch  As UByte
    
    Dim consumed  As Byte
    Dim new_col   As Long
    Dim new_row   As Long
    Dim click_col As Long
    Dim click_row As Long
    Dim sc_raw    As Long

    ' --- key repeat ---
    tick = vt_internal_ticks()
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
    While _VT_DRV_PollEvent(@evt)
        Select Case evt.type
            Case _VT_DRV_QUIT_
                If vt_internal.close_cb <> 0 Then
                    ' Release pump guard so the callback can use VT input freely
                    pump_active = 0
                    Dim close_result As Byte = vt_internal.close_cb()
                    pump_active = 1
                    If close_result = 0 Then
                        vt_internal_shutdown()
                        End
                    End If
                    ' close_result = 1: user vetoed, continue normally
                Else
                    vt_internal_shutdown()
                    End
                End If

            Case _VT_DRV_KEYDOWN
                modstate = _VT_DRV_GetModState()
                Dim sh As ULong = IIf((modstate And _VT_DRVKMOD_SHIFT) <> 0, 1UL, 0UL)
                Dim ct As ULong = IIf((modstate And _VT_DRVKMOD_CTRL)  <> 0, 1UL, 0UL)
                Dim al As ULong = IIf((modstate And _VT_DRVKMOD_ALT)   <> 0, 1UL, 0UL)

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

                ' --- paste key interception ---
                consumed = 0

                ' Shift+INS: request paste -- always available at live view (paste only)
                If sh AndAlso ct = 0 AndAlso al = 0 AndAlso vtscan = VT_KEY_INS Then
                    If vt_internal.sb_offset = 0 Then
                        vt_internal.cp_paste_pend = 1
                        consumed = 1
                    End If
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
                    If sym >= _VT_DRVK_a andalso sym <= _VT_DRVK_z Then
                        ascii_ch = CByte(sym - _VT_DRVK_a + 1)
                    End If
                ElseIf al Then
                    ' Alt+letter: SDL suppresses _VT_DRV_TEXTINPUT while Alt is held,
                    ' so VT_CHAR would stay 0 in the keyrec without this.
                    ' Recover the letter from the raw SDL scancode.
                    ' _VT_DRV_SCANCODE_A=4, Asc("a")=97, formula: ch = scancode + 93.
                    sc_raw = evt.key.keysym.scancode
                    If sc_raw >= 4 AndAlso sc_raw <= 29 Then
                        ascii_ch = CByte(sc_raw + 93)
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

            Case _VT_DRV_KEYUP
                If vt_internal_sdl_to_vtscan(evt.key.keysym.scancode) = vt_internal.rep_scan Then
                    vt_internal.rep_scan = 0
                    vt_internal.rep_last = 0
                End If

            Case _VT_DRV_TEXTINPUT
                ' SDL2 delivers TEXTINPUT as UTF-8.
                ' ASCII (< 0x80) : use byte directly.
                ' 2-byte (0xC0..0xDF lead) : decode codepoint, map to CP437.
                ' 3-byte (0xE0..0xEF lead) : same.
                ' 4-byte or unmappable    : discard silently.
                ' Alt+letter already handled in _VT_DRV_KEYDOWN above.
                Dim ti_ptr As UByte Ptr = CPtr(UByte Ptr, @evt.text.text)
                Dim ti_b0  As UByte     = ti_ptr[0]
                Dim ti_cp  As Long      = 0
                Dim ch     As UByte     = 0

                If ti_b0 < &h80 Then
                    ch = ti_b0
                ElseIf (ti_b0 And &hE0) = &hC0 Then
                    ' 2-byte UTF-8
                    ti_cp = ((CLng(ti_b0) And &h1F) Shl 6) Or (CLng(ti_ptr[1]) And &h3F)
                    ch = vt_internal_unicode_to_cp437(ti_cp)
                ElseIf (ti_b0 And &hF0) = &hE0 Then
                    ' 3-byte UTF-8
                    ti_cp = ((CLng(ti_b0) And &h0F) Shl 12) _
                         Or ((CLng(ti_ptr[1]) And &h3F) Shl 6) _
                         Or  (CLng(ti_ptr[2]) And &h3F)
                    ch = vt_internal_unicode_to_cp437(ti_cp)
                End If

                If ch >= 32 AndAlso ch <> 127 Then
                    keyrec = CULng(ch) Or (CULng(vt_internal.rep_scan) Shl 16)
                    modstate = _VT_DRV_GetModState()
                    If (modstate And _VT_DRVKMOD_SHIFT) Then keyrec = keyrec Or (1UL Shl 29)
                    If (modstate And _VT_DRVKMOD_CTRL)  Then keyrec = keyrec Or (1UL Shl 30)
                    If (modstate And _VT_DRVKMOD_ALT)   Then keyrec = keyrec Or (1UL Shl 31)
                    If vt_internal.key_count > 0 Then
                        vt_internal.key_write = (vt_internal.key_write + VT_KEY_BUFFER_SIZE - 1) _
                                                Mod VT_KEY_BUFFER_SIZE
                        vt_internal.key_count -= 1
                    End If
                    vt_internal_key_push(keyrec)
                End If

            CASE _VT_DRV_WINDOWEVENT
                If evt.window.event = _VT_DRV_WINDOWEVENT_RESIZED Then
                    vt_present()
                End IF

            Case _VT_DRV_MOUSEMOTION
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
                If vt_internal.cp_flags <> 0 AndAlso vt_internal.sel_dragging Then
                    Dim eff_left  As Long = IIf(vt_internal.cp_view_left  <> -1, vt_internal.cp_view_left,  1)
                    Dim eff_right As Long = IIf(vt_internal.cp_view_right <> -1, vt_internal.cp_view_right, vt_internal.scr_cols)
                    Dim eff_top   As Long = IIf(vt_internal.cp_view_top   <> -1, vt_internal.cp_view_top,   1)
                    Dim eff_bot   As Long = IIf(vt_internal.cp_view_bot   <> -1, vt_internal.cp_view_bot,   vt_internal.scr_rows)

                    Dim drag_col As Long = new_col
                    Dim drag_row As Long = new_row
                    If drag_col < eff_left  Then drag_col = eff_left
                    If drag_col > eff_right Then drag_col = eff_right
                    If drag_row < eff_top   Then drag_row = eff_top
                    If drag_row > eff_bot   Then drag_row = eff_bot

                    ' activate selection on first movement away from anchor
                    If vt_internal.sel_active = 0 Then
                        If drag_col <> vt_internal.sel_anchor_col OrElse _
                           drag_row <> vt_internal.sel_anchor_row Then
                            vt_internal.sel_active = 1
                            vt_internal.dirty      = 1
                        End If
                    End If

                    If drag_col <> vt_internal.sel_end_col OrElse _
                       drag_row <> vt_internal.sel_end_row Then
                        vt_internal.sel_end_col = drag_col
                        vt_internal.sel_end_row = drag_row
                        vt_internal.dirty       = 1
                    End If

                    ' auto-scroll when dragging to viewport edge (throttled)
                    If drag_row <= eff_top Then
                        If tick - vt_internal.cp_scroll_tick >= VT_CP_SCROLL_MS Then
                            Dim sb_before As Long = vt_internal.sb_offset
                            vt_scroll(1)
                            vt_internal.cp_scroll_tick = tick
                            ' only compensate anchor if the scroll actually moved
                            If vt_internal.sb_offset <> sb_before Then
                                If vt_internal.sel_anchor_row < eff_bot Then
                                    vt_internal.sel_anchor_row += 1
                                End If
                            End If
                        End If
                    ElseIf drag_row >= eff_bot Then
                        If tick - vt_internal.cp_scroll_tick >= VT_CP_SCROLL_MS Then
                            Dim sb_before As Long = vt_internal.sb_offset
                            vt_scroll(-1)
                            vt_internal.cp_scroll_tick = tick
                            ' only compensate anchor if the scroll actually moved
                            If vt_internal.sb_offset <> sb_before Then
                                If vt_internal.sel_anchor_row > eff_top Then
                                    vt_internal.sel_anchor_row -= 1
                                End If
                            End If
                        End If
                    End If
                    
                End If

            Case _VT_DRV_MOUSEBUTTONDOWN
                If vt_internal.mouse_on Then
                    Select Case evt.button.button
                        Case _VT_DRV_BUTTON_LEFT   : vt_internal.mouse_btns Or= VT_MOUSE_BTN_LEFT
                        Case _VT_DRV_BUTTON_RIGHT  : vt_internal.mouse_btns Or= VT_MOUSE_BTN_RIGHT
                        Case _VT_DRV_BUTTON_MIDDLE : vt_internal.mouse_btns Or= VT_MOUSE_BTN_MIDDLE
                    End Select
                End If

                ' copy/paste mouse -- independent of mouse_on
                If vt_internal.cp_flags <> 0 Then
                    click_col = evt.button.x \ vt_internal.glyph_w + 1
                    click_row = evt.button.y \ vt_internal.glyph_h + 1
                    If click_col < 1 Then click_col = 1
                    If click_col > vt_internal.scr_cols Then click_col = vt_internal.scr_cols
                    If click_row < 1 Then click_row = 1
                    If click_row > vt_internal.scr_rows Then click_row = vt_internal.scr_rows
                    Select Case evt.button.button
                        Case _VT_DRV_BUTTON_LEFT
                            ' snapshot viewport; selection activates only on drag movement
                            If vt_internal.sel_active Then
                                vt_internal.sel_active = 0
                                vt_internal.dirty      = 1
                            End If
                            vt_internal.cp_view_left   = vt_internal.view_left
                            vt_internal.cp_view_right  = vt_internal.view_right
                            vt_internal.cp_view_top    = vt_internal.view_top
                            vt_internal.cp_view_bot    = vt_internal.view_bot
                            vt_internal.sel_anchor_col = click_col
                            vt_internal.sel_anchor_row = click_row
                            vt_internal.sel_end_col    = click_col
                            vt_internal.sel_end_row    = click_row
                            vt_internal.sel_dragging   = 1
                            ' sel_active intentionally NOT set -- activates on first drag movement
                        Case _VT_DRV_BUTTON_RIGHT
                            ' copy whatever is selected (no-op if sel_active = 0)
                            vt_internal_cp_build_text()
                            vt_internal.sel_active    = 0
                            vt_internal.cp_view_left  = -1
                            vt_internal.cp_view_right = -1
                            vt_internal.cp_view_top   = -1
                            vt_internal.cp_view_bot   = -1
                            vt_internal.dirty = 1
                        Case _VT_DRV_BUTTON_MIDDLE
                            ' request paste -- vt_input drains this
                            vt_internal.cp_paste_pend = 1
                    End Select
                End If

            Case _VT_DRV_MOUSEBUTTONUP
                If vt_internal.mouse_on Then
                    Select Case evt.button.button
                        Case _VT_DRV_BUTTON_LEFT   : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_LEFT
                        Case _VT_DRV_BUTTON_RIGHT  : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_RIGHT
                        Case _VT_DRV_BUTTON_MIDDLE : vt_internal.mouse_btns And= Not VT_MOUSE_BTN_MIDDLE
                    End Select
                End If
                ' finalize drag -- selection stays visible until overwritten or RMB copied
                If vt_internal.cp_flags <> 0 Then
                    If evt.button.button = _VT_DRV_BUTTON_LEFT Then
                        vt_internal.sel_dragging = 0
                        ' cp_view_* intentionally NOT cleared here:
                        ' highlight render and build_text still need the snapshot
                    End If
                End If

            Case _VT_DRV_MOUSEWHEEL
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
    Dim tick As ULong = vt_internal_ticks()
    If tick - vt_internal.blink_tick >= VT_BLINK_MS Then
        vt_internal.blink_visible = 1 - vt_internal.blink_visible
        vt_internal.blink_tick    = tick
        Return 1
    End If
    Return 0
End Function

' -----------------------------------------------------------------------------
' Internal: free all SDL and heap resources, reset state
' Called by vt_shutdown and at the top of vt_init_impl for re-init(mode change)
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
    
    if vt_internal.sdl_buffer   <> 0 then _VT_DRV_DestroyTexture( vt_internal.sdl_buffer ) : vt_internal.sdl_buffer   = 0
    If vt_internal.sdl_texture  <> 0 Then _VT_DRV_DestroyTexture(vt_internal.sdl_texture)  : vt_internal.sdl_texture  = 0
    If vt_internal.sdl_renderer <> 0 Then _VT_DRV_DestroyRenderer(vt_internal.sdl_renderer): vt_internal.sdl_renderer = 0
    If vt_internal.sdl_window   <> 0 Then _VT_DRV_DestroyWindow(vt_internal.sdl_window)    : vt_internal.sdl_window   = 0
    
    #Ifdef VT_USE_SOUND
        ' vt_sound extension -- shuts down cleanly if audio was ever opened
        vt_internal_sound_shutdown()
    #Endif
    
    _VT_DRV_Quit()
End Sub

' -----------------------------------------------------------------------------
' Internal: core init -- called by vt_screen
' -----------------------------------------------------------------------------
Function vt_init_impl(cols As Long, rows As Long, glyph_w As Long, glyph_h As Long, _
                      fptr As UByte Ptr, fsrc_h As Long, flags As Long, _
                      pages As Long) As Long

    ' --- raw TTY guard ---
    #Ifdef __FB_LINUX__
        If Environ("TERM") = "linux" Then
            Print "libvt requires a graphical desktop (X11/Wayland)"
            End
        End If
    #EndIf

    If vt_internal.ready Then vt_internal_shutdown()  ' re-init: clean up first

    If _VT_DRV_Init(_VT_DRV_INIT_VIDEO) <> 0 Then Return -1

    Dim wflags As ULong = _VT_DRV_WINDOW_SHOWN
    If (flags And VT_NO_RESIZE) = 0 Then wflags = wflags Or _VT_DRV_WINDOW_RESIZABLE

    Dim win_w As Long = cols * glyph_w
    Dim win_h As Long = rows * glyph_h

    Dim wtitle As String = vt_internal.win_title
    If wtitle = "" Then wtitle = "VT"

    vt_internal.sdl_window = _VT_DRV_CreateWindow( wtitle, _
        _VT_DRV_WINDOWPOS_CENTERED, _VT_DRV_WINDOWPOS_CENTERED, _
        win_w, win_h, wflags)

    If vt_internal.sdl_window = 0 Then
        _VT_DRV_Quit()
        Return -2
    End If

    If flags And VT_FULLSCREEN_ASPECT Then
        _VT_DRV_SetWindowFullscreen(vt_internal.sdl_window, _VT_DRV_WINDOW_FULLSCREEN_DESKTOP)
    ElseIf flags And VT_FULLSCREEN_STRETCH Then
        _VT_DRV_SetWindowFullscreen(vt_internal.sdl_window, _VT_DRV_WINDOW_FULLSCREEN)
    ElseIf flags And VT_WINDOWED_MAX Then
        _VT_DRV_MaximizeWindow(vt_internal.sdl_window)
    End If

    Dim rflags As ULong = _VT_DRV_RENDERER_ACCELERATED
    If flags And VT_VSYNC Then rflags = rflags Or _VT_DRV_RENDERER_PRESENTVSYNC
    vt_internal.sdl_renderer = _VT_DRV_CreateRenderer(vt_internal.sdl_window, -1, rflags)
    If vt_internal.sdl_renderer = 0 Then
        _VT_DRV_DestroyWindow(vt_internal.sdl_window)
        _VT_DRV_Quit()
        Return -3
    End If

    _VT_DRV_SetHint(_VT_DRV_HINT_RENDER_SCALE_QUALITY, "1")
    _VT_DRV_RenderSetLogicalSize(vt_internal.sdl_renderer, win_w, win_h)
    If flags And VT_FULLSCREEN_ASPECT Then
        _VT_DRV_RenderSetIntegerScale(vt_internal.sdl_renderer, _VT_DRV_TRUE)
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
    if vt_internal.sdl_buffer then _VT_DRV_DestroyTexture( vt_internal.sdl_buffer )
    vt_internal.sdl_buffer = _VT_DRV_CreateTexture( vt_internal.sdl_renderer , _
      _VT_DRV_PIXELFORMAT_RGBA8888, _VT_DRV_TEXTUREACCESS_TARGET, win_w, win_h )
    If vt_internal.sdl_texture = 0 Then
        _VT_DRV_DestroyRenderer(vt_internal.sdl_renderer)
        _VT_DRV_DestroyWindow(vt_internal.sdl_window)
        _VT_DRV_Quit()
        Return -4
    End If
    _VT_DRV_SetTextureBlendMode(vt_internal.sdl_texture, _VT_DRV_BLENDMODE_BLEND)

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
    vt_internal.scroll_on  = 1
    vt_internal.view_top   = 1
    vt_internal.view_bot   = rows
    vt_internal.view_left  = -1   ' -1 = full width (no column constraint)
    vt_internal.view_right = -1

    ' --- blink ---
    vt_internal.blink_visible = 1
    vt_internal.blink_tick    = vt_internal_ticks()

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
    vt_internal.cp_view_left   = -1
    vt_internal.cp_view_right  = -1
    vt_internal.cp_view_top    = -1
    vt_internal.cp_view_bot    = -1
    vt_internal.cp_scroll_tick = 0

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
        Case VT_SCREEN_100_40
            cols = 100 : rows = 40 : gw = 8  : gh = 16
            fptr = @vt_font_data_8x16(0) : fsrc_h = 16
        Case VT_SCREEN_100_50
            cols = 100 : rows = 50 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case VT_SCREEN_120_45
            cols = 120 : rows = 45 : gw = 8  : gh = 16
            fptr = @vt_font_data_8x16(0) : fsrc_h = 16
        Case VT_SCREEN_120_50
            cols = 120 : rows = 50 : gw = 8  : gh = 8
            fptr = @vt_font_data_8x8(0)  : fsrc_h = 8
        Case Else
            If mode >= &h400 Then
                Dim As vt_screenparam_t tmode = Any : tmode.n = mode
                cols = tmode.w : rows = tmode.h
                gw = tmode.fw: If gw = 0 Then gw =  8
                gh = tmode.fh: If gh = 0 Then gh = 16
            Else
                cols = 80 : rows = 25 : gw = 8  : gh = 16
            End If
            
            Select Case gh
                Case 8
                    fptr = @vt_font_data_8x8(0)  : fsrc_h =  8
                Case 14
                    fptr = @vt_font_data_8x14(0) : fsrc_h = 14
                Case Else
                    fptr = @vt_font_data_8x16(0) : fsrc_h = 16
            End Select
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
' Internal: column-range scroll helper
' Shifts only the cells inside view_left..view_right for each row in
' view_top..view_bot on the active work page.
'   amount > 0  scroll up   (blank row inserted at bottom of viewport)
'   amount < 0  scroll down (blank row inserted at top  of viewport)
' When view_left / view_right are -1: covers all columns (full-row path).
' Scrollback capture is handled by the caller (vt_scroll) -- not here.
' -----------------------------------------------------------------------------
Sub vt_internal_scroll_rect(amount As Long)
    If amount = 0 Then Exit Sub

    Dim cols    As Long = vt_internal.scr_cols
    Dim v_top   As Long = vt_internal.view_top - 1   ' 0-based
    Dim v_bot   As Long = vt_internal.view_bot - 1   ' 0-based
    Dim v_left  As Long
    Dim v_right As Long
    Dim buf     As vt_cell Ptr = vt_internal.cells
    Dim blank   As vt_cell
    Dim steps   As Long
    Dim rr      As Long
    Dim cc      As Long

    blank.ch = 32
    blank.fg = vt_internal.clr_fg
    blank.bg = vt_internal.clr_bg

    If vt_internal.view_left = -1 Then
        v_left  = 0
        v_right = cols - 1
    Else
        v_left  = vt_internal.view_left  - 1   ' 0-based
        v_right = vt_internal.view_right - 1   ' 0-based
    End If

    steps = Abs(amount)
    Dim span As Long = v_bot - v_top + 1
    If steps > span Then steps = span

    If amount > 0 Then
        ' scroll up: shift rows toward lower indices
        For rr = v_top To v_bot - steps
            For cc = v_left To v_right
                buf[rr * cols + cc] = buf[(rr + steps) * cols + cc]
            Next cc
        Next rr
        ' blank the bottom 'steps' rows
        For rr = v_bot - steps + 1 To v_bot
            For cc = v_left To v_right
                buf[rr * cols + cc] = blank
            Next cc
        Next rr
    Else
        ' scroll down: shift rows toward higher indices
        For rr = v_bot To v_top + steps Step -1
            For cc = v_left To v_right
                buf[rr * cols + cc] = buf[(rr - steps) * cols + cc]
            Next cc
        Next rr
        ' blank the top 'steps' rows
        For rr = v_top To v_top + steps - 1
            For cc = v_left To v_right
                buf[rr * cols + cc] = blank
            Next cc
        Next rr
    End If
End Sub

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
    Dim src_rect    As _VT_DRV_Rect
    Dim dst_rect    As _VT_DRV_Rect
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
    Dim cell_src    As vt_cell Ptr  ' per-column source switch for A6 scrollback+viewport

    vt_internal_blink_update()

    gw      = vt_internal.glyph_w
    gh      = vt_internal.glyph_h
    cols    = vt_internal.scr_cols
    rows    = vt_internal.scr_rows
    vis_buf = vt_internal.page_buf(vt_internal.vis_page)
    
    _VT_DRV_SetRenderTarget(vt_internal.sdl_renderer, vt_internal.sdl_buffer)

    _VT_DRV_SetRenderDrawColor(vt_internal.sdl_renderer, _
        vt_internal.border_r, vt_internal.border_g, vt_internal.border_b, 255)
    _VT_DRV_RenderClear(vt_internal.sdl_renderer)

    src_rect.w = gw
    src_rect.h = gh
    dst_rect.w = gw
    dst_rect.h = gh

    ' Reset texture colormod to white before cell loop each frame.
    ' Cursor render from previous frame would otherwise taint fg=white cells.
    _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, 255, 255, 255)
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
            ' when scrollback is showing AND a column viewport is active,
            ' columns outside view_left..view_right read from live vis_buf so
            ' sidepanels stay frozen; columns inside use the scrollback cellptr.
            If vt_internal.sb_offset > 0 AndAlso vt_internal.view_left <> -1 Then
                If col_idx < vt_internal.view_left - 1 OrElse _
                   col_idx > vt_internal.view_right - 1 Then
                    cell_src = vis_buf + (row_idx * cols + col_idx)
                Else
                    cell_src = cellptr + col_idx
                End If
            Else
                cell_src = cellptr + col_idx
            End If

            ch  = cell_src->ch
            fg  = cell_src->fg
            bg  = cell_src->bg

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

            _VT_DRV_SetRenderDrawColor(vt_internal.sdl_renderer, bg_r, bg_g, bg_b, 255)
            _VT_DRV_RenderFillRect(vt_internal.sdl_renderer, @dst_rect)

            If fg_r <> last_fg_r OrElse fg_g <> last_fg_g OrElse fg_b <> last_fg_b Then
                _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, fg_r, fg_g, fg_b)
                last_fg_r = fg_r
                last_fg_g = fg_g
                last_fg_b = fg_b
            End If
            src_rect.x = (ch Mod 16) * gw
            src_rect.y = (ch \ 16)   * gh
            _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)

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

            ' clip to cp_view_* snapshot -- skip cells outside the column/row viewport
            If vt_internal.cp_view_left <> -1 Then
                If sl_col + 1 < vt_internal.cp_view_left  Then Continue For
                If sl_col + 1 > vt_internal.cp_view_right Then Continue For
            End If
            If vt_internal.cp_view_top <> -1 Then
                If sl_row + 1 < vt_internal.cp_view_top Then Continue For
                If sl_row + 1 > vt_internal.cp_view_bot Then Continue For
            End If
            
            ' skip the mouse cursor cell so the cursor always renders distinctly on top
            If vt_internal.mouse_on AndAlso vt_internal.mouse_vis Then
                If sl_col = vt_internal.mouse_col - 1 AndAlso _
                   sl_row = vt_internal.mouse_row - 1 Then Continue For
            End If
            
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
            _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, si_bg_r, si_bg_g, si_bg_b)
            _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)

            ' pass 2: original glyph in inverted foreground colour
            src_rect.x = (sl_ch Mod 16) * gw
            src_rect.y = (sl_ch \ 16)   * gh
            _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, si_fg_r, si_fg_g, si_fg_b)
            _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
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
        _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, cfg_r, cfg_g, cfg_b)
        _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
    End If

    ' --- mouse cursor ---
    If vt_internal.mouse_on AndAlso vt_internal.mouse_vis Then
        Dim mc_col    As Long
        Dim mc_row    As Long
        Dim mc_cellptr As vt_cell Ptr
        Dim mc_ch     As UByte
        Dim mc_cfg    As UByte
        Dim mc_cbg    As UByte
        Dim mc_bg_r   As UByte
        Dim mc_bg_g   As UByte
        Dim mc_bg_b   As UByte
        Dim mc_fg_r   As UByte
        Dim mc_fg_g   As UByte
        Dim mc_fg_b   As UByte
        Dim mc_in_sel As Byte = 0
        mc_col    = vt_internal.mouse_col - 1
        mc_row    = vt_internal.mouse_row - 1
        mc_cellptr = vt_internal_display_cellptr(mc_col, mc_row, vis_buf)
        mc_ch  = mc_cellptr->ch
        mc_cfg = mc_cellptr->fg And 15
        mc_cbg = mc_cellptr->bg And 15
        ' check if cursor sits inside the active selection
        If vt_internal.sel_active Then
            Dim mc_flat As Long = mc_row * cols + mc_col
            Dim mc_sel1 As Long = (vt_internal.sel_anchor_row - 1) * cols + (vt_internal.sel_anchor_col - 1)
            Dim mc_sel2 As Long = (vt_internal.sel_end_row    - 1) * cols + (vt_internal.sel_end_col    - 1)
            If mc_sel1 > mc_sel2 Then Swap mc_sel1, mc_sel2
            If mc_flat >= mc_sel1 AndAlso mc_flat <= mc_sel2 Then mc_in_sel = 1
        End If
        ' inside selection: use original colors so cursor stands out against inverted field
        ' outside selection: use inverted colors so cursor stands out against normal cell
        If mc_in_sel Then
            mc_bg_r = vt_internal.palette(mc_cbg * 3)
            mc_bg_g = vt_internal.palette(mc_cbg * 3 + 1)
            mc_bg_b = vt_internal.palette(mc_cbg * 3 + 2)
            mc_fg_r = vt_internal.palette(mc_cfg * 3)
            mc_fg_g = vt_internal.palette(mc_cfg * 3 + 1)
            mc_fg_b = vt_internal.palette(mc_cfg * 3 + 2)
        Else
            mc_bg_r = 255 - vt_internal.palette(mc_cbg * 3)
            mc_bg_g = 255 - vt_internal.palette(mc_cbg * 3 + 1)
            mc_bg_b = 255 - vt_internal.palette(mc_cbg * 3 + 2)
            mc_fg_r = 255 - vt_internal.palette(mc_cfg * 3)
            mc_fg_g = 255 - vt_internal.palette(mc_cfg * 3 + 1)
            mc_fg_b = 255 - vt_internal.palette(mc_cfg * 3 + 2)
        End If
        dst_rect.x = mc_col * gw
        dst_rect.y = mc_row * gh
        src_rect.x = (219 Mod 16) * gw
        src_rect.y = (219 \ 16)   * gh
        _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, mc_bg_r, mc_bg_g, mc_bg_b)
        _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
        src_rect.x = (mc_ch Mod 16) * gw
        src_rect.y = (mc_ch \ 16)   * gh
        _VT_DRV_SetTextureColorMod(vt_internal.sdl_texture, mc_fg_r, mc_fg_g, mc_fg_b)
        _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_texture, @src_rect, @dst_rect)
    End If
    
    _VT_DRV_SetRenderTarget(vt_internal.sdl_renderer, NULL)
    _VT_DRV_RenderCopy(vt_internal.sdl_renderer, vt_internal.sdl_buffer, NULL, NULL)
    
    vt_internal.dirty = 0
    _VT_DRV_RenderPresent(vt_internal.sdl_renderer)
End Sub

' -----------------------------------------------------------------------------
' vt_on_close - register a callback for the window [X] button
'
' cb() As Byte:
'   Return 0  ->  library shuts down and calls End  (same as default)
'   Return 1  ->  close vetoed; user is responsible for handling it
'
' The pump guard is released before calling cb, so VT input functions
' (vt_inkey, vt_getkey, vt_sleep, etc.) are safe to call inside cb.
'
' Pass 0 to restore default auto-close behaviour.
' -----------------------------------------------------------------------------
Sub vt_on_close(cb As Function() As Byte)
    vt_internal.close_cb = cb
End Sub

' -----------------------------------------------------------------------------
' vt_shutdown - explicit teardown
' -----------------------------------------------------------------------------
Sub vt_shutdown()
    vt_internal_shutdown()
End Sub

' -----------------------------------------------------------------------------
' vt_title - set the window title
' -----------------------------------------------------------------------------
Sub vt_title(txt As String)
    vt_internal.win_title = txt
    If vt_internal.ready Then
        _VT_DRV_SetWindowTitle(vt_internal.sdl_window, txt)
    End If
End Sub

' -----------------------------------------------------------------------------
' Internal: auto-present for vt_inkey -- throttled, skips if not dirty
' -----------------------------------------------------------------------------
Sub vt_internal_present_if_dirty()
    If vt_internal.dirty = 0 Then Exit Sub
    Static last_auto_tick As ULong
    Dim now_tick As ULong
    now_tick = vt_internal_ticks()
    If now_tick - last_auto_tick < 2 Then Exit Sub
    vt_present()
    last_auto_tick = vt_internal_ticks()
End Sub

' -----------------------------------------------------------------------------
' vt_key_repeat - configure key repeat timing
' -----------------------------------------------------------------------------
Sub vt_key_repeat(initial_ms As Long, rate_ms As Long)
    vt_internal.rep_initial = initial_ms
    vt_internal.rep_rate    = rate_ms
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
' vt_key_held - real-time key state poll
' -----------------------------------------------------------------------------
Function vt_key_held(vtscan As Long) As Byte
    Dim sdl_scan As Long
    Dim numkeys  As Long
    Dim states   As Const UByte Ptr

    Select Case vtscan
        Case VT_KEY_F1     : sdl_scan = _VT_DRV_SCANCODE_F1
        Case VT_KEY_F2     : sdl_scan = _VT_DRV_SCANCODE_F2
        Case VT_KEY_F3     : sdl_scan = _VT_DRV_SCANCODE_F3
        Case VT_KEY_F4     : sdl_scan = _VT_DRV_SCANCODE_F4
        Case VT_KEY_F5     : sdl_scan = _VT_DRV_SCANCODE_F5
        Case VT_KEY_F6     : sdl_scan = _VT_DRV_SCANCODE_F6
        Case VT_KEY_F7     : sdl_scan = _VT_DRV_SCANCODE_F7
        Case VT_KEY_F8     : sdl_scan = _VT_DRV_SCANCODE_F8
        Case VT_KEY_F9     : sdl_scan = _VT_DRV_SCANCODE_F9
        Case VT_KEY_F10    : sdl_scan = _VT_DRV_SCANCODE_F10
        Case VT_KEY_F11    : sdl_scan = _VT_DRV_SCANCODE_F11
        Case VT_KEY_F12    : sdl_scan = _VT_DRV_SCANCODE_F12
        Case VT_KEY_ESC    : sdl_scan = _VT_DRV_SCANCODE_ESCAPE
        Case VT_KEY_ENTER  : sdl_scan = _VT_DRV_SCANCODE_RETURN
        Case VT_KEY_BKSP   : sdl_scan = _VT_DRV_SCANCODE_BACKSPACE
        Case VT_KEY_TAB    : sdl_scan = _VT_DRV_SCANCODE_TAB
        Case VT_KEY_SPACE  : sdl_scan = _VT_DRV_SCANCODE_SPACE
        Case VT_KEY_UP     : sdl_scan = _VT_DRV_SCANCODE_UP
        Case VT_KEY_DOWN   : sdl_scan = _VT_DRV_SCANCODE_DOWN
        Case VT_KEY_LEFT   : sdl_scan = _VT_DRV_SCANCODE_LEFT
        Case VT_KEY_RIGHT  : sdl_scan = _VT_DRV_SCANCODE_RIGHT
        Case VT_KEY_HOME   : sdl_scan = _VT_DRV_SCANCODE_HOME
        Case VT_KEY_END    : sdl_scan = _VT_DRV_SCANCODE_END
        Case VT_KEY_PGUP   : sdl_scan = _VT_DRV_SCANCODE_PAGEUP
        Case VT_KEY_PGDN   : sdl_scan = _VT_DRV_SCANCODE_PAGEDOWN
        Case VT_KEY_INS    : sdl_scan = _VT_DRV_SCANCODE_INSERT
        Case VT_KEY_DEL    : sdl_scan = _VT_DRV_SCANCODE_DELETE
        Case VT_KEY_LSHIFT : sdl_scan = _VT_DRV_SCANCODE_LSHIFT
        Case VT_KEY_RSHIFT : sdl_scan = _VT_DRV_SCANCODE_RSHIFT
        Case VT_KEY_LCTRL  : sdl_scan = _VT_DRV_SCANCODE_LCTRL
        Case VT_KEY_RCTRL  : sdl_scan = _VT_DRV_SCANCODE_RCTRL
        Case VT_KEY_LALT   : sdl_scan = _VT_DRV_SCANCODE_LALT
        Case VT_KEY_RALT   : sdl_scan = _VT_DRV_SCANCODE_RALT
        Case VT_KEY_LWIN   : sdl_scan = _VT_DRV_SCANCODE_LGUI
        Case VT_KEY_RWIN   : sdl_scan = _VT_DRV_SCANCODE_RGUI
        Case Else          : Return 0
    End Select

    states = _VT_DRV_GetKeyboardState(@numkeys)
    If states = 0 Then Return 0
    If sdl_scan >= numkeys Then Return 0
    Return states[sdl_scan]
End Function

' -----------------------------------------------------------------------------
' vt_sleep ms = 0 : wait for any key; ms > 0 : delay for ms milliseconds
' -----------------------------------------------------------------------------
Sub vt_sleep(ms As Long = 0)
    Dim t_start   As ULong
    Dim t_now     As ULong
    Dim remaining As Long
    Dim slp       As Long
    Dim k         As ULong

    t_start = vt_internal_ticks()

    Do
        If ms = 0 Then
            k = vt_inkey()
            If k <> 0 Then Exit Do
            Sleep 10, 1
        Else
            vt_pump()
            If vt_internal_blink_update() Then vt_internal.dirty = 1
            vt_internal_present_if_dirty()
            t_now = vt_internal_ticks()
            If t_now - t_start >= CULng(ms) Then Exit Do
            remaining = ms - CLng(t_now - t_start)
            slp = remaining \ 2         ' sleep half the remaining time
            If slp < 1  Then slp = 1    ' minimum 1ms
            If slp > 10 Then slp = 10   ' cap at 10ms (responsive enough)
            Sleep slp, 1
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
