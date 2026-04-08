' =============================================================================
' vt_misc.bas - VT Miscellaneous Utilities
' =============================================================================

' -----------------------------------------------------------------------------
' vt_rnd - return a random Long in the range [lo .. hi] (inclusive)
' Supports negative bounds. If lo > hi they are swapped silently.
' -----------------------------------------------------------------------------
Function vt_rnd(lo As Long, hi As Long) As Long
    If lo > hi Then Swap lo, hi
    Return Int(Rnd * (hi - lo + 1)) + lo
End Function
