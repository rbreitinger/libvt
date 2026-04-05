' =============================================================================
' vt_font.bas - VT Virtual Text Screen Library
' Custom bitmap font loader. Call vt_screen() first.
' SDL2.dll core only -- no SDL_image, ever.
'
' Two sheet layouts are recognised automatically:
'   grid  -- 16 cols x 16 rows of glyphs  canvas = 16*gw  x  16*gh
'   strip -- 256 glyphs in one horizontal row  canvas = 256*gw x gh
' Detection is unambiguous once the glyph size is known from the screen mode.
'
' All non-mask pixels are normalised to white in the resulting texture so
' SDL colormod tinting in vt_present produces the correct fg colour for
' every cell, exactly as with the built-in embedded fonts.
'
' Return codes shared by vt_loadfont and vt_font_reset:
'   0 = success
'  -1 = vt_screen() not called yet
'  -2 = BMP load or surface/texture creation failed
'  -3 = image dimensions do not fit current screen mode glyph size  (loadfont only)
'  -4 = SDL_CreateTextureFromSurface failed
' =============================================================================

' -----------------------------------------------------------------------------
' Internal helper: build a white-on-transparent ARGB32 font texture from the
' built-in bitpacked font data stored in vt_internal.
' Used by vt_font_reset. Mirrors the texture-build block in vt_init_impl exactly.
' Returns a new SDL_Texture Ptr on success, 0 on failure.
' Caller owns the returned texture and must set blend mode before use.
' -----------------------------------------------------------------------------
Function vt_internal_build_embedded_tex() As SDL_Texture Ptr
    Dim font_surf  As SDL_Surface Ptr
    Dim new_tex    As SDL_Texture Ptr
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

    font_surf = SDL_CreateRGBSurface(0, 16 * gw, 16 * gh, 32, _
        &h00FF0000, &h0000FF00, &h000000FF, &hFF000000)
    If font_surf = 0 Then Return 0

    SDL_LockSurface(font_surf)
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

    SDL_UnlockSurface(font_surf)

    new_tex = SDL_CreateTextureFromSurface(vt_internal.sdl_renderer, font_surf)
    SDL_FreeSurface(font_surf)
    Return new_tex
End Function

' -----------------------------------------------------------------------------
' vt_font_reset - restore the built-in embedded font.
' Rebuilds the SDL texture from the bitpacked data that vt_screen() selected.
' Safe to call any time after vt_screen().
' -----------------------------------------------------------------------------
Function vt_font_reset() As Long
    Dim new_tex As SDL_Texture Ptr

    If vt_internal.ready = 0 Then Return -1

    new_tex = vt_internal_build_embedded_tex()
    If new_tex = 0 Then Return -4

    SDL_SetTextureBlendMode(new_tex, SDL_BLENDMODE_BLEND)
    SDL_DestroyTexture(vt_internal.sdl_texture)
    vt_internal.sdl_texture = new_tex
    vt_internal.dirty = 1
    Return 0
End Function

' -----------------------------------------------------------------------------
' vt_loadfont - load a BMP font sheet and replace the active font texture.
'
' fname    : path to a BMP file (any bit depth -- converted internally to RGB24)
' sheet_w  : expected pixel width  of the BMP (-1 = accept any)
' sheet_h  : expected pixel height of the BMP (-1 = accept any)
' mask_r   : red   component of the transparent background colour (default 0)
' mask_g   : green component of the transparent background colour (default 0)
' mask_b   : blue  component of the transparent background colour (default 0)
'
' Common mask colours:
'   black   mask_r=0,   mask_g=0,   mask_b=0
'   magenta mask_r=255, mask_g=0,   mask_b=255
'   white   mask_r=255, mask_g=255, mask_b=255
'
' Must be called after vt_screen(). The loaded font stays active until
' vt_loadfont is called again, vt_font_reset() restores the built-in font,
' or vt_screen() reinitialises the window.
' -----------------------------------------------------------------------------
Function vt_loadfont(fname As String, _
                     sheet_w As Long = -1, _
                     sheet_h As Long = -1, _
                     mask_r As UByte = 0, _
                     mask_g As UByte = 0, _
                     mask_b As UByte = 0) As Long

    Dim bmp_surf   As SDL_Surface Ptr
    Dim conv_surf  As SDL_Surface Ptr
    Dim font_surf  As SDL_Surface Ptr
    Dim new_tex    As SDL_Texture Ptr
    Dim sdl_fmt    As SDL_PixelFormat Ptr
    Dim gw         As Long
    Dim gh         As Long
    Dim img_w      As Long
    Dim img_h      As Long
    Dim layout     As Long   ' 1 = 16x16 grid,  2 = 256x1 strip
    Dim glyph_idx  As Long
    Dim src_gx     As Long
    Dim src_gy     As Long
    Dim dst_gx     As Long
    Dim dst_gy     As Long
    Dim grow       As Long
    Dim gcol       As Long
    Dim src_base   As UByte Ptr
    Dim dst_base   As ULong Ptr
    Dim src_pitch  As Long
    Dim dst_pitch  As Long
    Dim src_px     As UByte Ptr
    Dim is_mask    As Byte

    If vt_internal.ready = 0 Then Return -1

    gw = vt_internal.glyph_w
    gh = vt_internal.glyph_h

    ' --- load BMP (SDL accepts any bit depth here) ---
    bmp_surf = SDL_LoadBMP(fname)
    If bmp_surf = 0 Then Return -2

    img_w = bmp_surf->w
    img_h = bmp_surf->h

    ' --- optional dimension sanity check ---
    If sheet_w > 0 AndAlso sheet_w <> img_w Then
        SDL_FreeSurface(bmp_surf)
        Return -3
    End If
    If sheet_h > 0 AndAlso sheet_h <> img_h Then
        SDL_FreeSurface(bmp_surf)
        Return -3
    End If

    ' --- auto-detect layout from pixel dimensions ---
    ' grid  : exactly 16*gw wide and 16*gh tall  (e.g. 128x128 for 8x8 glyphs)
    ' strip : exactly 256*gw wide and gh tall     (e.g. 2048x8 for 8x8 glyphs)
    If img_w = 16 * gw AndAlso img_h = 16 * gh Then
        layout = 1
    ElseIf img_w = 256 * gw AndAlso img_h = gh Then
        layout = 2
    Else
        SDL_FreeSurface(bmp_surf)
        Return -3
    End If

    ' --- normalise to RGB24 for predictable 3-byte-per-pixel access ---
    ' Handles 24bpp, 32bpp, and indexed palettes uniformly.
    sdl_fmt   = SDL_AllocFormat(SDL_PIXELFORMAT_RGB24)
    conv_surf = SDL_ConvertSurface(bmp_surf, sdl_fmt, 0)
    SDL_FreeFormat(sdl_fmt)
    SDL_FreeSurface(bmp_surf)
    bmp_surf = 0

    If conv_surf = 0 Then Return -2

    ' --- create destination surface: 16x16 glyph grid, ARGB32, white on transparent ---
    ' Same format as the texture built from the embedded fonts in vt_init_impl.
    font_surf = SDL_CreateRGBSurface(0, 16 * gw, 16 * gh, 32, _
        &h00FF0000, &h0000FF00, &h000000FF, &hFF000000)

    If font_surf = 0 Then
        SDL_FreeSurface(conv_surf)
        Return -2
    End If

    SDL_LockSurface(conv_surf)
    SDL_LockSurface(font_surf)

    src_base  = CPtr(UByte Ptr, conv_surf->pixels)
    dst_base  = CPtr(ULong Ptr, font_surf->pixels)
    src_pitch = conv_surf->pitch     ' bytes per row  (RGB24: 3 * width, may be padded)
    dst_pitch = font_surf->pitch \ 4 ' ULong elements per row

    For glyph_idx = 0 To 255

        ' source top-left pixel coordinate inside the BMP
        If layout = 1 Then
            src_gx = (glyph_idx Mod 16) * gw
            src_gy = (glyph_idx \ 16)   * gh
        Else
            src_gx = glyph_idx * gw
            src_gy = 0
        End If

        ' destination top-left pixel in the 16x16 texture atlas
        dst_gx = (glyph_idx Mod 16) * gw
        dst_gy = (glyph_idx \ 16)   * gh

        For grow = 0 To gh - 1
            For gcol = 0 To gw - 1
                ' RGB24: 3 bytes per pixel, byte order is R, G, B
                src_px = src_base + (src_gy + grow) * src_pitch + (src_gx + gcol) * 3

                ' exact 3-channel match against the mask colour
                is_mask = (src_px[0] = mask_r) AndAlso _
                          (src_px[1] = mask_g) AndAlso _
                          (src_px[2] = mask_b)

                If is_mask Then
                    dst_base[(dst_gy + grow) * dst_pitch + (dst_gx + gcol)] = &h00000000
                Else
                    ' normalise to white so SDL colormod tints correctly in vt_present
                    dst_base[(dst_gy + grow) * dst_pitch + (dst_gx + gcol)] = &hFFFFFFFF
                End If
            Next gcol
        Next grow

    Next glyph_idx

    SDL_UnlockSurface(font_surf)
    SDL_UnlockSurface(conv_surf)
    SDL_FreeSurface(conv_surf)

    ' --- upload to GPU ---
    new_tex = SDL_CreateTextureFromSurface(vt_internal.sdl_renderer, font_surf)
    SDL_FreeSurface(font_surf)

    If new_tex = 0 Then Return -4

    SDL_SetTextureBlendMode(new_tex, SDL_BLENDMODE_BLEND)

    ' --- hot-swap: destroy old texture, install new one ---
    SDL_DestroyTexture(vt_internal.sdl_texture)
    vt_internal.sdl_texture = new_tex

    vt_internal.dirty = 1
    Return 0
End Function
