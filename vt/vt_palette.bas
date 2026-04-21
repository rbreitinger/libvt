' =============================================================================
' vt_palette.bas - VT Palette and Border Colour API
' =============================================================================

' -----------------------------------------------------------------------------
' vt_palette_set / vt_palette_get - bulk palette copy
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
' vt_palette - set a single palette entry, or reset all to CGA defaults
' idx = -1  : reset all 16 entries to vt_default_palette
' idx 0..15 : set that entry; always pass r, g, b explicitly --
'             omitting them produces 255 (white) because -1 And 255 = 255
' -----------------------------------------------------------------------------
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
