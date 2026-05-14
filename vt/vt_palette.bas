' =============================================================================
' vt_palette.bas - VT Palette and Border Colour API
' =============================================================================

Const VT_PALETTE_SZ = 47

'>>>
':topic vt_palette_set
':short Bulk-write all 16 palette entries
':group Palette
'Bulk-write all 16 palette entries from a
'caller-supplied UByte array of 48 elements.
'Format: 16 colours x R, G, B bytes.
':syntax
Sub vt_palette_set(pal() As UByte)
        ':params
        'pal()  Array containing 48 bytes of palette
        '       data (16 colours x R, G, B).
        ':see
        'vt_palette_get
        'vt_palette
    '<<<
    Dim pi As Long
    For pi = 0 To VT_PALETTE_SZ
        vt_internal.palette(pi) = pal(pi)
    Next pi
End Sub

'>>>
':topic vt_palette_get
':short Bulk-read all 16 palette entries
':group Palette
'Bulk-read all 16 palette entries into a
'caller-supplied UByte array of at least 48
'elements. Format: 16 colours x R, G, B bytes.
':syntax
Sub vt_palette_get(pal() As UByte)
        ':params
        'pal()  Array to receive 48 bytes of palette
        '       data (16 colours x R, G, B).
        ':example
        'Dim pal(VT_PALETTE_SZ) As UByte
        'vt_palette_get pal()
        '' Restore later:
        'vt_palette_set pal()
        ':see
        'vt_palette_set
        'vt_palette
    '<<<
    Dim pi As Long
    For pi = 0 To VT_PALETTE_SZ
        pal(pi) = vt_internal.palette(pi)
    Next pi
End Sub

'>>>
':topic vt_palette
':short Set one palette entry or reset all to EGA
':group Palette
'Set a single palette entry, or reset all 16
'colours to EGA defaults. The palette is a flat
'array of 48 bytes: 16 colours x 3 channels
'(R, G, B). Entry idx starts at byte idx*3.
'When idx >= 0, always supply all three channels
'-- the defaults (-1) only apply for the reset
'case (idx = -1). Omitting channels when setting
'a specific entry produces 255 (white) because
'-1 And 255 = 255.
':syntax
Sub vt_palette(idx As Long = -1, _
               r   As Long = -1, _
               g   As Long = -1, _
               b   As Long = -1)

        ':params
        'idx  Colour index (0-15). Pass -1 to reset all
        '     16 entries to EGA defaults.
        'r    Red channel   (0-255).
        'g    Green channel (0-255).
        'b    Blue channel  (0-255).
        ':example
        '' Replace colour 4 (Red) with orange:
        'vt_palette(4, 220, 120, 0)
        '
        '' Reset all 16 to EGA defaults:
        'vt_palette()
        ':see
        'vt_palette_get
        'vt_palette_set
        'c_colors
    '<<<
    If idx < 0 Or idx > 15 Then
        vt_palette_set(vt_default_palette())
        Exit Sub
    End If
    vt_internal.palette(idx * 3)     = r And 255
    vt_internal.palette(idx * 3 + 1) = g And 255
    vt_internal.palette(idx * 3 + 2) = b And 255
End Sub

'>>>
':topic vt_border_color
':short Set the letterbox border colour
':group Display
'Set the colour of the letterbox bars that
'appear outside the logical viewport in windowed
'or fullscreen-aspect modes. Default is black
'(0, 0, 0). Each channel is in the range 0-255.
':syntax
Sub vt_border_color(r As Long, g As Long, b As Long)
        ':params
        'r  Red channel   (0-255)
        'g  Green channel (0-255)
        'b  Blue channel  (0-255)
        ':example
        '' Dark navy letterbox:
        'vt_border_color(0, 0, 64)
        ':see
        'vt_screen
    '<<<
    vt_internal.border_r = r And 255
    vt_internal.border_g = g And 255
    vt_internal.border_b = b And 255
End Sub
