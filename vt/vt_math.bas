'===============================================================================
' vt_math.bas : opt-in Math Helpers Extension
'===============================================================================

'>>>
':topic c_mathconsts
':short Math macros (opt-in: VT_USE_MATH)
':group Constants
'Available when #define VT_USE_MATH is placed
'before #include once "vt/vt.bi".
'
':params
#define VT_MIN(a, b)          iif((a) < (b), (a), (b))
'  Returns the smaller of two values.
#define VT_MAX(a, b)          iif((a) > (b), (a), (b))
'  Returns the larger of two values.
#define VT_CLAMP(v, lo, hi)   iif((v) < (lo), (lo), iif((v) > (hi), (hi), (v)))
'  Clamps v to the range [lo .. hi]
#define VT_SIGN(x)            iif((x) > 0, 1, iif((x) < 0, -1, 0))
'  Returns -1, 0, or 1 depending on the sign of x.
'
':notes 
'Macros use IIf() which evaluates both
'sides -- avoid expressions with side effects
'(function calls, increments) as arguments.
'
':see
'vt_wrap
'vt_lerp
'vt_approach
'<<<

'>>>
':topic vt_wrap
':short Modular roll-over wrap into a range
':group Math
'Wrap v into the inclusive range [lo .. hi]
'with roll-over. Unlike VT_CLAMP, hitting an
'edge rolls around to the opposite side.
'If hi - lo + 1 <= 0, returns lo.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_wrap(v  As Long, _
                 lo As Long, _
                 hi As Long) As Long
        ':params
        'v   The value to wrap.
        'lo  Lower bound (inclusive).
        'hi  Upper bound (inclusive).
        ':example
        '' Menu cursor that wraps at the edges:
        'cursor_row = vt_wrap(cursor_row + delta, _
        '                     1, num_items)
        '
        '' Toroidal map: walk off right, appear left:
        'px = vt_wrap(px + 1, 0, map_width - 1)
        ':see
        'vt_approach
        'c_mathconsts
    '<<<
    Dim rng As Long
    Dim rel As Long
    rng = hi - lo + 1
    If rng <= 0 Then Return lo
    rel = (v - lo) Mod rng
    If rel < 0 Then rel += rng
    Return rel + lo
End Function

'>>>
':topic vt_lerp
':short Linear interpolation between two values
':group Math
'Linear interpolation between a and b. At t = 0
'the result is a; at t = 1 the result is b. t is
'not clamped - values outside [0..1] extrapolate
'beyond the endpoints.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_lerp(a As Double, _
                 b As Double, _
                 t As Double) As Double
        ':params
        'a  Start value (returned when t = 0).
        'b  End value (returned when t = 1).
        't  Interpolation factor. Not clamped.
        ':example
        'Dim brightness As Double = _
        '    vt_lerp(0, 100, elapsed / total)
        ':see
        'vt_approach
        'c_mathconsts
    '<<<
    Return a + (b - a) * t
End Function

'>>>
':topic vt_approach
':short Step a value toward a target without overshoot
':group Math
'Move cur toward tgt by amt without overshooting.
'If cur = tgt it returns unchanged. amt should
'be positive.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_approach(cur As Long, _
                     tgt As Long, _
                     amt As Long) As Long
        ':params
        'cur  Current value.
        'tgt  Target value to approach.
        'amt  Step size per call. Should be positive.
        ':example
        'enemy_x = vt_approach(enemy_x, player_x, 1)
        'enemy_y = vt_approach(enemy_y, player_y, 1)
        '
        '' Score counter catching up 10 per frame:
        'display_score = vt_approach(display_score, _
        '                             real_score, 10)
        ':see
        'vt_lerp
        'vt_wrap
    '<<<
    If cur < tgt Then
        cur += amt
        If cur > tgt Then cur = tgt
    ElseIf cur > tgt Then
        cur -= amt
        If cur < tgt Then cur = tgt
    End If
    Return cur
End Function

'>>>
':topic vt_manhattan
':short Manhattan (taxicab) distance between two points
':group Math
'Manhattan distance between two grid points.
'Counts only orthogonal steps -- no diagonals.
'Equivalent to Abs(x2-x1) + Abs(y2-y1).
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_manhattan(x1 As Long, y1 As Long, _
                      x2 As Long, y2 As Long) _
                      As Long
        ':example
        'If vt_manhattan(ex, ey, px, py) <= 4 Then
        '    attack()
        'End If
        ':see
        'vt_chebyshev
        'vt_los
    '<<<
    Return Abs(x2 - x1) + Abs(y2 - y1)
End Function

'>>>
':topic vt_chebyshev
':short Chebyshev (king-moves) distance
':group Math
'Chebyshev distance between two grid points.
'Diagonal steps cost 1, the same as orthogonal
'- matches 8-direction movement. Equivalent to
'VT_MAX(Abs(x2-x1), Abs(y2-y1)).
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_chebyshev(x1 As Long, y1 As Long, _
                      x2 As Long, y2 As Long) _
                      As Long
        ':example
        'If vt_chebyshev(ax, ay, bx, by) = 1 Then
        '    melee_attack()
        'End If
        ':see
        'vt_manhattan
    '<<<
    Dim dx As Long, dy As Long
    dx = Abs(x2 - x1)
    dy = Abs(y2 - y1)
    Return VT_MAX(dx, dy)
End Function

'>>>
':topic vt_in_rect
':short Point-in-rectangle test
':group Math
'Returns 1 if point (px, py) lies within the
'rectangle. The rect is half-open:
'[rx, rx+rw) x [ry, ry+rh) - the right and
'bottom edges are excluded. Returns 0 otherwise.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_in_rect(px As Long, py As Long, _
                    rx As Long, ry As Long, _
                    rw As Long, rh As Long) _
                    As Byte
        ':params
        'px, py  Point coordinates.
        'rx, ry  Rectangle top-left corner.
        'rw      Rectangle width in cells.
        'rh      Rectangle height in cells.
        ':example
        'Dim mcol As Long, mrow As Long, mbtns As Long
        'vt_getmouse(@mcol, @mrow, @mbtns, 0)
        'If (mbtns And VT_MOUSE_BTN_LEFT) AndAlso _
        '   vt_in_rect(mcol, mrow, 10, 5, 20, 3) Then
        '    button_clicked()
        'End If
        ':see
        'vt_tui_mouse_in_rect
    '<<<
    If px >= rx AndAlso px < rx + rw AndAlso py >= ry AndAlso py < ry + rh Then
        Return 1
    End If
    Return 0
End Function

'>>>
':topic vt_digits
':short Count printed characters of a Long
':group Math
'Returns the number of characters that Str(n) or
'Print n would produce, including the minus sign
'for negative numbers. Zero returns 1. Uses
'LongInt internally to handle the full Long range
'without overflow.
':syntax
Function vt_digits(n As Long) As Long
        ':notes
        'Opt-in: define VT_USE_MATH before the include.
        '  n = 0           -> 1
        '  n = 1234        -> 4
        '  n = -99         -> 3  (minus + 2 digits)
        '  n = -2147483648 -> 11
        '
        ':example
        '' Right-align a score in a fixed-width column:
        'Dim score As Long = 9870
        'Dim col_start As Long = 75 - vt_digits(score)
        'vt_locate(1, col_start)
        'vt_print(Str(score))
        ':see
        'vt_cols
    '<<<
    Dim cnt As Long
    Dim v As LongInt
    v = CLngInt(n)
    If v = 0 Then Return 1
    cnt = 0
    If v < 0 Then
        cnt = 1
        v = -v
    End If
    Do While v > 0
        cnt += 1
        v \= 10
    Loop
    Return cnt
End Function

'>>>
':topic vt_bresenham_walk
':short Walk all cells on a straight line
':group Math
'Walk every cell on the straight line from
'(x1, y1) to (x2, y2) using Bresenham's line
'algorithm and calls cb(x, y) for each cell in
'order. Both endpoints are included. The callback
'is a Sub(x As Long, y As Long) - pass its
'address with @. Because FreeBASIC has no
'closures, use module-level Shared variables to
'give the callback access to map data.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Sub vt_bresenham_walk(x1 As Long, y1 As Long, _
                      x2 As Long, y2 As Long, _
                      cb As Sub(As Long, _
                                As Long))
        ':params
        'x1, y1  Start cell (included in walk).
        'x2, y2  End cell (included in walk).
        'cb      Called once per cell. Pass with @.
        ':example
        'Sub draw_dash(x As Long, y As Long)
        '    vt_set_cell(x, y, Asc("-"), VT_WHITE, VT_BLACK)
        'End Sub
        '
        'vt_bresenham_walk(1, 1, 40, 15, @draw_dash)
        'vt_present()
        ':see
        'vt_los
    '<<<
    Dim dx As Long, dy As Long
    Dim sx As Long, sy As Long
    Dim er As Long, e2 As Long
    Dim cx As Long, cy As Long
    dx = Abs(x2 - x1)
    dy = Abs(y2 - y1)
    sx = IIf(x1 < x2, 1, -1)
    sy = IIf(y1 < y2, 1, -1)
    er = dx - dy
    cx = x1
    cy = y1
    Do
        cb(cx, cy)
        If cx = x2 AndAlso cy = y2 Then Exit Do
        e2 = er * 2
        If e2 > -dy Then
            er -= dy
            cx += sx
        End If
        If e2 < dx Then
            er += dx
            cy += sy
        End If
    Loop
End Sub

'>>>
':topic vt_los
':short Line-of-sight check using Bresenham
':group Math
'Line-of-sight check from (x1, y1) to (x2, y2)
'using Bresenham's algorithm. The blocker function
'is called for each cell and must return 1 if
'that cell blocks sight, 0 if clear. The start
'cell is NEVER tested - the observer stands
'there. The end cell IS tested - a wall blocks
'LOS to itself. Returns 1 if the path is clear,
'0 if blocked. Use module-level Shared variables
'to give the blocker function access to map data.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Function vt_los(x1 As Long, y1 As Long, _
                x2 As Long, y2 As Long, _
                blocker As Function(As Long, _
                          As Long) As Byte) _
                As Byte
        ':params
        'x1, y1   Observer position. Not passed to blocker.
        'x2, y2   Target position. Passed to blocker.
        'blocker  Returns 1 if cell blocks sight. Pass @.
        ':notes
        'Return values:
        '  1  Line of sight is clear.
        '  0  Blocked by at least one cell on the path.
        ':example
        'Dim Shared g_map(79, 49) As Byte
        '
        'Function is_wall(x As Long, y As Long) As Byte
        '    Return g_map(x, y)
        'End Function
        '
        'If vt_los(ex, ey, px, py, @is_wall) Then
        '    alert_enemy()
        'End If
        ':see
        'vt_bresenham_walk
    '<<<
    Dim dx As Long, dy As Long
    Dim sx As Long, sy As Long
    Dim er As Long, e2 As Long
    Dim cx As Long, cy As Long
    Dim first As Byte
    dx = Abs(x2 - x1)
    dy = Abs(y2 - y1)
    sx = IIf(x1 < x2, 1, -1)
    sy = IIf(y1 < y2, 1, -1)
    er = dx - dy
    cx = x1
    cy = y1
    first = 1
    Do
        If first Then
            first = 0   ' skip start cell -- observer is standing here
        Else
            If blocker(cx, cy) Then Return 0
        End If
        If cx = x2 AndAlso cy = y2 Then Exit Do
        e2 = er * 2
        If e2 > -dy Then
            er -= dy
            cx += sx
        End If
        If e2 < dx Then
            er += dx
            cy += sy
        End If
    Loop
    Return 1
End Function

'>>>
':topic vt_mat_rotate_cw
':short Rotate a 2D Long array 90 degrees clockwise
':group Math
'Rotate a 2D Long array 90 degrees clockwise
'in-place. The array must be square. LBound and
'UBound are used internally to detect the size,
'no size argument is needed. Non-square arrays
'are silently ignored. Works with any LBound
'(0-based or 1-based).
'Opt-in: define VT_USE_MATH before the include.
':syntax
Sub vt_mat_rotate_cw(m() As Long)
        ':params
        'm()  Square 2D array to rotate in-place.
        ':example
        'Dim piece(0 To 3, 0 To 3) As Long
        '' ... fill piece with 0/1 values ...
        'vt_mat_rotate_cw(piece())
        ':see
        'vt_mat_rotate_ccw
    '<<<
    Dim lo As Long, hi As Long
    Dim r As Long, c As Long
    Dim tmp As Long, half As Long
    lo = LBound(m, 1)
    hi = UBound(m, 1)
    ' bail if not square
    If (hi - lo) <> (UBound(m, 2) - LBound(m, 2)) Then Exit Sub
    ' step 1: transpose (swap across main diagonal)
    For r = lo To hi
        For c = r + 1 To hi
            tmp    = m(r, c)
            m(r, c) = m(c, r)
            m(c, r) = tmp
        Next c
    Next r
    ' step 2: reverse each row (completes 90-degree CW rotation)
    half = (hi - lo + 1) \ 2
    For r = lo To hi
        For c = 0 To half - 1
            tmp          = m(r, lo + c)
            m(r, lo + c) = m(r, hi - c)
            m(r, hi - c) = tmp
        Next c
    Next r
End Sub

'>>>
':topic vt_mat_rotate_ccw
':short Rotate a 2D Long array 90 degrees CCW
':group Math
'Rotate a 2D Long array 90 degrees counter-
'clockwise in-place. Identical behaviour to
'vt_mat_rotate_cw but in the opposite direction.
'Non-square arrays are silently ignored.
'Opt-in: define VT_USE_MATH before the include.
':syntax
Sub vt_mat_rotate_ccw(m() As Long)
        ':params
        'm()  Square 2D array to rotate in-place.
        ':example
        '' Four CCW rotations return to original:
        'vt_mat_rotate_ccw( piece() )
        'vt_mat_rotate_ccw( piece() )
        'vt_mat_rotate_ccw( piece() )
        'vt_mat_rotate_ccw( piece() )
        ':see
        'vt_mat_rotate_cw
    '<<<
    Dim lo As Long, hi As Long
    Dim r As Long, c As Long
    Dim tmp As Long, half As Long
    lo = LBound(m, 1)
    hi = UBound(m, 1)
    ' bail if not square
    If (hi - lo) <> (UBound(m, 2) - LBound(m, 2)) Then Exit Sub
    ' step 1: transpose (swap across main diagonal)
    For r = lo To hi
        For c = r + 1 To hi
            tmp    = m(r, c)
            m(r, c) = m(c, r)
            m(c, r) = tmp
        Next c
    Next r
    ' step 2: reverse each column (completes 90-degree CCW rotation)
    half = (hi - lo + 1) \ 2
    For c = lo To hi
        For r = 0 To half - 1
            tmp          = m(lo + r, c)
            m(lo + r, c) = m(hi - r, c)
            m(hi - r, c) = tmp
        Next r
    Next c
End Sub
