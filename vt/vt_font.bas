' =============================================================================
' vt_font.bas - Custom bitmap font loader.
' =============================================================================

' -----------------------------------------------------------------------------
' Internal helper: build a white-on-transparent ARGB32 font texture from the
' built-in bitpacked font data stored in vt_internal.
' Used by vt_font_reset. Mirrors the texture-build block in vt_internal_init exactly.
' Returns a new _VT_DRV_Texture Ptr on success, 0 on failure.
' Caller owns the returned texture and must set blend mode before use.
' -----------------------------------------------------------------------------
Private Function vt_internal_build_embedded_tex() As _VT_DRV_Texture Ptr
    Dim font_surf  As _VT_DRV_Surface Ptr
    Dim new_tex    As _VT_DRV_Texture Ptr
    Dim surf_px    As ULong Ptr
    Dim surf_pitch As Long
    Dim gw         As Long
    Dim gh         As Long
    Dim fsrc_h     As Long
    Dim fptr       As UByte Ptr
    Dim glyph_idx  As Long
    Dim gx         As Long
    Dim gy         As Long
    Dim glyph_row  As Long
    Dim font_row   As Long
    Dim font_byte  As UByte
    Dim bit_idx    As Long
    Dim font_bit   As Long
    Dim on_px      As Byte

    gw     = vt_internal.glyph_w
    gh     = vt_internal.glyph_h
    fsrc_h = vt_internal.font_src_h
    fptr   = vt_internal.font_ptr

    font_surf = _VT_DRV_CreateRGBSurface(0, 16 * gw, 16 * gh, 32, _
        &h00FF0000, &h0000FF00, &h000000FF, &hFF000000)
    If font_surf = 0 Then Return 0

    _VT_DRV_LockSurface(font_surf)
    surf_px    = CPtr(ULong Ptr, font_surf->pixels)
    surf_pitch = font_surf->pitch \ 4

    For glyph_idx = 0 To 255
        gx = (glyph_idx Mod 16) * gw
        gy = (glyph_idx \ 16)   * gh

        For glyph_row = 0 To gh - 1
            ' scale glyph_row into source font row (handles height upscaling for TILES)
            font_row  = (glyph_row * fsrc_h) \ gh
            font_byte = fptr[glyph_idx * fsrc_h + font_row]

            For bit_idx = 0 To gw - 1
                ' scale bit_idx into source bit (handles width-doubling for 40-col)
                font_bit = (bit_idx * 8) \ gw
                on_px    = (font_byte Shr (7 - font_bit)) And 1
                surf_px[(gy + glyph_row) * surf_pitch + gx + bit_idx] = _
                    IIf(on_px, &hFFFFFFFF, &h00000000)
            Next bit_idx
        Next glyph_row
    Next glyph_idx

    _VT_DRV_UnlockSurface(font_surf)

    new_tex = _VT_DRV_CreateTextureFromSurface(vt_internal.sdl_renderer, font_surf)
    _VT_DRV_FreeSurface(font_surf)
    Return new_tex
End Function

' -----------------------------------------------------------------------------
' vt_font_reset - restore the built-in embedded font.
' Rebuilds the (SDL) texture from the bitpacked data that vt_screen() selected.
' -----------------------------------------------------------------------------
'>>>
':topic vt_font_reset
':short Restore the built-in embedded font
':group Font
'Restore the built-in embedded CP437 font
'selected by the current screen mode. Destroys
'any custom font loaded with vt_loadfont. Must
'be called after vt_screen.
':syntax
Function vt_font_reset() As Long
        ':notes
        'Return values:
        '   0  success
        '  -1  library not ready
        '  -2  surface or texture creation failed
        ':see
        'vt_loadfont
        'vt_screen
    '<<<
    Dim new_tex As _VT_DRV_Texture Ptr

    If vt_internal.ready = 0 Then Return -1

    new_tex = vt_internal_build_embedded_tex()
    If new_tex = 0 Then Return -2

    _VT_DRV_SetTextureBlendMode(new_tex, _VT_DRV_BLENDMODE_BLEND)
    _VT_DRV_DestroyTexture(vt_internal.sdl_texture)
    vt_internal.sdl_texture = new_tex
    vt_internal.dirty = 1
    Return 0
End Function

'>>>
':topic vt_loadfont
':short Load a custom BMP font sheet
':group Font
'Load a BMP font sheet and replace the active
'font texture at runtime. The loaded font stays
'active until vt_loadfont is called again,
'vt_font_reset is called, or vt_screen
'reinitializes the window.
':syntax
Function vt_loadfont(fname   As String, _
                     sheet_w As Long  = -1, _
                     sheet_h As Long  = -1, _
                     mask_r  As UByte = 0,  _
                     mask_g  As UByte = 0,  _
                     mask_b  As UByte = 0) As Long
        ':params
        'fname    Path to a BMP file. Any bit depth.
        'sheet_w  Expected BMP pixel width (-1 = any).
        'sheet_h  Expected BMP pixel height (-1 = any).
        'mask_r   Red component of the transparent colour.
        'mask_g   Green component of the transparent colour.
        'mask_b   Blue component of the transparent colour.
        ':notes
        'Return values:
        '   0  success
        '  -1  library not ready
        '  -2  BMP load or surface creation failed
        '  -3  image dimensions mismatch
        '  -4  SDL texture upload failed
        '
        'Layout is detected automatically from the BMP
        'pixel dimensions relative to the current glyph
        'size (gw x gh):
        '  16x16 grid:  16*gw x 16*gh  (e.g. 128x128)
        '  256x1 strip: 256*gw x gh    (e.g. 2048x8)
        '
        'Common mask colours:
        '  Black (default): mask_r=0   mask_g=0   mask_b=0
        '  Magenta:         mask_r=255 mask_g=0   mask_b=255
        '  White:           mask_r=255 mask_g=255 mask_b=255
        '
        'Non-mask pixels are normalized to white
        'internally so colour-mod tinting applies
        'the correct foreground colour.
        ':example
        'Dim r As Long = _
        '    vt_loadfont("myfont.bmp", -1, -1, 255, 0, 255)
        'If r <> 0 Then
        '    vt_print("Font load failed: " & r & VT_LF)
        'End If
        ':see
        'vt_font_reset
        'vt_screen
    '<<<

    Dim bmp_surf   As _VT_DRV_Surface Ptr
    Dim conv_surf  As _VT_DRV_Surface Ptr
    Dim font_surf  As _VT_DRV_Surface Ptr
    Dim new_tex    As _VT_DRV_Texture Ptr
    Dim sdl_fmt    As _VT_DRV_PixelFormat Ptr
    Dim gw         As Long
    Dim gh         As Long
    Dim img_w      As Long
    Dim img_h      As Long
    Dim src_gw     As Long
    Dim src_gh     As Long
    Dim layout     As Long
    Dim glyph_idx  As Long
    Dim src_gx     As Long
    Dim src_gy     As Long
    Dim dst_gx     As Long
    Dim dst_gy     As Long
    Dim grow       As Long
    Dim gcol       As Long
    Dim src_row    As Long
    Dim src_col    As Long
    Dim src_base   As UByte Ptr
    Dim dst_base   As ULong Ptr
    Dim src_pitch  As Long
    Dim dst_pitch  As Long
    Dim src_px     As UByte Ptr
    Dim is_mask    As Byte

    If vt_internal.ready = 0 Then Return -1

    gw = vt_internal.glyph_w
    gh = vt_internal.glyph_h

    ' --- load BMP ---
    bmp_surf = _VT_DRV_LoadBMP(fname)
    If bmp_surf = 0 Then Return -2

    img_w = bmp_surf->w
    img_h = bmp_surf->h

    ' --- optional caller-supplied dimension check ---
    If sheet_w > 0 AndAlso sheet_w <> img_w Then
        _VT_DRV_FreeSurface(bmp_surf)
        Return -3
    End If
    If sheet_h > 0 AndAlso sheet_h <> img_h Then
        _VT_DRV_FreeSurface(bmp_surf)
        Return -3
    End If

    ' --- auto-detect layout and derive source glyph size ---
    ' grid  : 16x16 glyph grid  -- img dimensions must be exact multiples of 16
    ' strip : 256x1 glyph strip -- img width must be exact multiple of 256
    If (img_w Mod 16 = 0) AndAlso (img_h Mod 16 = 0) Then
        layout = 1
        src_gw = img_w \ 16
        src_gh = img_h \ 16
    ElseIf (img_w Mod 256 = 0) Then
        layout = 2
        src_gw = img_w \ 256
        src_gh = img_h
    Else
        _VT_DRV_FreeSurface(bmp_surf)
        Return -3
    End If

    ' --- normalise to RGB24 for predictable 3-byte-per-pixel access ---
    sdl_fmt   = _VT_DRV_AllocFormat(_VT_DRV_PIXELFORMAT_RGB24)
    conv_surf = _VT_DRV_ConvertSurface(bmp_surf, sdl_fmt, 0)
    _VT_DRV_FreeFormat(sdl_fmt)
    _VT_DRV_FreeSurface(bmp_surf)
    bmp_surf = 0

    If conv_surf = 0 Then Return -2

    ' --- create destination surface: 16x16 glyph grid, ARGB32 ---
    font_surf = _VT_DRV_CreateRGBSurface(0, 16 * gw, 16 * gh, 32, _
        &h00FF0000, &h0000FF00, &h000000FF, &hFF000000)

    If font_surf = 0 Then
        _VT_DRV_FreeSurface(conv_surf)
        Return -2
    End If

    _VT_DRV_LockSurface(conv_surf)
    _VT_DRV_LockSurface(font_surf)

    src_base  = CPtr(UByte Ptr, conv_surf->pixels)
    dst_base  = CPtr(ULong Ptr, font_surf->pixels)
    src_pitch = conv_surf->pitch
    dst_pitch = font_surf->pitch \ 4

    For glyph_idx = 0 To 255
        ' source top-left in BMP -- uses derived src_gw/src_gh
        If layout = 1 Then
            src_gx = (glyph_idx Mod 16) * src_gw
            src_gy = (glyph_idx \ 16)   * src_gh
        Else
            src_gx = glyph_idx * src_gw
            src_gy = 0
        End If

        ' destination top-left in the output atlas -- always gw/gh
        dst_gx = (glyph_idx Mod 16) * gw
        dst_gy = (glyph_idx \ 16)   * gh

        For grow = 0 To gh - 1
            For gcol = 0 To gw - 1
                ' ratio-map destination pixel back to source glyph pixel
                src_row = (grow * src_gh) \ gh
                src_col = (gcol * src_gw) \ gw
                src_px  = src_base + (src_gy + src_row) * src_pitch + (src_gx + src_col) * 3

                is_mask = (src_px[0] = mask_r) AndAlso _
                          (src_px[1] = mask_g) AndAlso _
                          (src_px[2] = mask_b)

                If is_mask Then
                    dst_base[(dst_gy + grow) * dst_pitch + (dst_gx + gcol)] = &h00000000
                Else
                    dst_base[(dst_gy + grow) * dst_pitch + (dst_gx + gcol)] = &hFFFFFFFF
                End If
            Next gcol
        Next grow
    Next glyph_idx

    _VT_DRV_UnlockSurface(font_surf)
    _VT_DRV_UnlockSurface(conv_surf)
    _VT_DRV_FreeSurface(conv_surf)

    ' --- upload to GPU ---
    new_tex = _VT_DRV_CreateTextureFromSurface(vt_internal.sdl_renderer, font_surf)
    _VT_DRV_FreeSurface(font_surf)

    If new_tex = 0 Then Return -4

    _VT_DRV_SetTextureBlendMode(new_tex, _VT_DRV_BLENDMODE_BLEND)

    ' --- hot-swap ---
    _VT_DRV_DestroyTexture(vt_internal.sdl_texture)
    vt_internal.sdl_texture = new_tex

    vt_internal.dirty = 1
    Return 0
End Function

#Undef vt_internal_build_embedded_tex
