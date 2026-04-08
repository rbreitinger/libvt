'===============================================================================
' vt_math.bas  --  VT Math Extension
' opt-in: #define VT_USE_MATH before #include "vt/vt.bi"
' no dependencies, no VT screen required -- pure math helpers
'===============================================================================

'-------------------------------------------------------------------------------
' Macros
'
' VT_MIN(a, b)          smaller of two values
' VT_MAX(a, b)          larger of two values
' VT_CLAMP(v, lo, hi)   clamp v to [lo..hi]
' VT_SIGN(x)            -1, 0, or 1
'
' Note: macros use iif() which evaluates both sides -- avoid passing expressions
' with side effects (function calls, increments) as arguments.
'-------------------------------------------------------------------------------

#define VT_MIN(a, b)          iif((a) < (b), (a), (b))
#define VT_MAX(a, b)          iif((a) > (b), (a), (b))
#define VT_CLAMP(v, lo, hi)   iif((v) < (lo), (lo), iif((v) > (hi), (hi), (v)))
#define VT_SIGN(x)            iif((x) > 0, 1, iif((x) < 0, -1, 0))

'-------------------------------------------------------------------------------
' vt_wrap(v, lo, hi) As Long
'
' Wraps v into [lo..hi] with roll-over (modular / toroidal).
' Unlike clamp, hitting the edge rolls to the other side.
'
' Examples:
'   vt_wrap(11, 0, 9)  = 1       (rolled past 9, back to start)
'   vt_wrap(-1, 0, 9)  = 9       (rolled before 0, back to end)
'   vt_wrap( 5, 0, 9)  = 5       (in range, unchanged)
'
' Use for: menu cursor wrap, toroidal map edges, cyclic animation frames.
'-------------------------------------------------------------------------------

Function vt_wrap(v As Long, lo As Long, hi As Long) As Long
    Dim rng As Long
    Dim rel As Long
    rng = hi - lo + 1
    If rng <= 0 Then Return lo
    rel = (v - lo) Mod rng
    If rel < 0 Then rel += rng
    Return rel + lo
End Function

'-------------------------------------------------------------------------------
' vt_lerp(a, b, t) As Double
'
' Linear interpolation between a (t=0) and b (t=1).
' t is not clamped -- extrapolation outside [0..1] is valid.
'
' Examples:
'   vt_lerp(0, 100, 0.25)  = 25.0
'   vt_lerp(0, 100, 1.5)   = 150.0    (extrapolation)
'
' Use for: smooth animated values, colour fades, eased movement.
'-------------------------------------------------------------------------------

Function vt_lerp(a As Double, b As Double, t As Double) As Double
    Return a + (b - a) * t
End Function

'-------------------------------------------------------------------------------
' vt_approach(cur, tgt, amt) As Long
'
' Moves cur toward tgt by amt without overshooting.
' amt must be positive. If cur = tgt, returns tgt unchanged.
'
' Examples:
'   vt_approach(3,  10, 4)  = 7     (3 + 4 = 7, not past 10)
'   vt_approach(9,  10, 4)  = 10    (would overshoot, clamped)
'   vt_approach(10, 10, 4)  = 10    (already there)
'   vt_approach(15, 10, 4)  = 11    (approaching from above)
'
' Use for: smooth enemy movement, camera scroll, animated score counters,
'          HP bars that fill/drain gradually.
'-------------------------------------------------------------------------------

Function vt_approach(cur As Long, tgt As Long, amt As Long) As Long
    If cur < tgt Then
        cur += amt
        If cur > tgt Then cur = tgt
    ElseIf cur > tgt Then
        cur -= amt
        If cur < tgt Then cur = tgt
    End If
    Return cur
End Function

'-------------------------------------------------------------------------------
' vt_manhattan(x1, y1, x2, y2) As Long
'
' Manhattan (taxicab) distance between two grid points.
' Counts only orthogonal steps -- no diagonals allowed.
'
' Examples:
'   vt_manhattan(0,0, 3,4)  = 7     (3 right + 4 down)
'   vt_manhattan(5,2, 2,6)  = 7     (3 left  + 4 down)
'
' Use for: range checks with 4-direction movement, flood-fill heuristics,
'          "how many turns away" in turn-based games without diagonal moves.
'-------------------------------------------------------------------------------

Function vt_manhattan(x1 As Long, y1 As Long, x2 As Long, y2 As Long) As Long
    Return Abs(x2 - x1) + Abs(y2 - y1)
End Function

'-------------------------------------------------------------------------------
' vt_chebyshev(x1, y1, x2, y2) As Long
'
' Chebyshev (king-moves) distance between two grid points.
' Diagonal steps cost 1, same as orthogonal -- 8-direction movement.
'
' Examples:
'   vt_chebyshev(0,0, 3,4)  = 4     (4 diagonal steps)
'   vt_chebyshev(0,0, 5,2)  = 5     (2 diag + 3 straight)
'
' Use for: roguelike melee range, FOV radius, 8-direction movement cost.
'-------------------------------------------------------------------------------

Function vt_chebyshev(x1 As Long, y1 As Long, x2 As Long, y2 As Long) As Long
    Dim dx As Long, dy As Long
    dx = Abs(x2 - x1)
    dy = Abs(y2 - y1)
    Return VT_MAX(dx, dy)
End Function

'-------------------------------------------------------------------------------
' vt_in_rect(px, py, rx, ry, rw, rh) As Byte
'
' Returns 1 if point (px, py) lies within the rectangle.
' Rect is half-open: [rx, rx+rw) x [ry, ry+rh) -- right/bottom edge excluded.
' Consistent with how cells are addressed: col in [1..cols), not cols itself.
'
' Examples:
'   vt_in_rect(3, 3,  1,1, 5,5)  = 1    (inside)
'   vt_in_rect(6, 3,  1,1, 5,5)  = 0    (on right edge, excluded)
'
' Use for: mouse hit-testing on UI panels, button regions, spawn zone checks.
'-------------------------------------------------------------------------------

Function vt_in_rect(px As Long, py As Long, rx As Long, ry As Long, rw As Long, rh As Long) As Byte
    If px >= rx AndAlso px < rx + rw AndAlso py >= ry AndAlso py < ry + rh Then
        Return 1
    End If
    Return 0
End Function

'-------------------------------------------------------------------------------
' vt_digits(n) As Long
'
' Returns the number of characters Str(n) or Print n would produce.
' Counts the minus sign for negative numbers. Zero returns 1.
' Uses LongInt internally to correctly handle Long min value (-2147483648).
'
' Examples:
'   vt_digits(0)        = 1
'   vt_digits(1234)     = 4
'   vt_digits(-99)      = 3    (minus + 2 digits)
'   vt_digits(-2147483648) = 11
'
' Use for: right-aligning scores, centering numbers, column layout math.
'-------------------------------------------------------------------------------

Function vt_digits(n As Long) As Long
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

'-------------------------------------------------------------------------------
' vt_bresenham_walk(x1, y1, x2, y2, cb)
'
' Walks every cell on the straight line from (x1,y1) to (x2,y2) using
' Bresenham's line algorithm and calls cb(x, y) for each cell in order.
' Both endpoints are included.
'
' cb is a Sub(x As Long, y As Long) -- pass its address with @.
' Because FreeBASIC has no closures, use module-level Shared variables to
' pass extra state into the callback (e.g. your map array).
'
' Example:
'   Sub mark_cell(x As Long, y As Long)
'       map(x, y) = MARKED
'   End Sub
'   vt_bresenham_walk(0, 0, 7, 3, @mark_cell)
'
' Use for: drawing lines on the text grid, recording projectile paths,
'          area-of-effect rays, blast trails.
'-------------------------------------------------------------------------------

Sub vt_bresenham_walk(x1 As Long, y1 As Long, x2 As Long, y2 As Long, cb As Sub(As Long, As Long))
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

'-------------------------------------------------------------------------------
' vt_los(x1, y1, x2, y2, blocker) As Byte
'
' Line-of-sight check from (x1,y1) to (x2,y2) using Bresenham's algorithm.
' blocker(x, y) must return 1 if that cell blocks sight, 0 if clear.
'
' The START cell is never tested -- the observer stands there.
' The END cell IS tested -- a wall tile blocks LOS to itself.
' Returns 1 if line of sight is clear, 0 if anything blocks it.
'
' Because FreeBASIC has no closures, use module-level Shared variables to
' give the callback access to your map data.
'
' Example:
'   Dim Shared g_map(79, 49) As Byte
'
'   Function is_wall(x As Long, y As Long) As Byte
'       Return g_map(x, y)
'   End Function
'
'   If vt_los(px, py, ex, ey, @is_wall) Then
'       ' enemy can see player
'   End If
'
' Use for: fog of war, enemy vision cones, projectile validity,
'          torch/lantern radius visibility in roguelikes.
'-------------------------------------------------------------------------------

Function vt_los(x1 As Long, y1 As Long, x2 As Long, y2 As Long, blocker As Function(As Long, As Long) As Byte) As Byte
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

'-------------------------------------------------------------------------------
' vt_mat_rotate_cw(m())
' vt_mat_rotate_ccw(m())
'
' Rotate a 2D Long array 90 degrees clockwise (CW) or counter-clockwise (CCW)
' in-place. The array must be square. LBound/UBound are used to detect the
' size automatically -- no size parameter needed.
'
' Non-square arrays are silently ignored (no-op).
' Works with any LBound (0-based or 1-based declarations).
'
' Algorithm: transpose, then reverse rows (CW) or reverse columns (CCW).
'
' Example (Tetris piece rotation):
'   Dim piece(0 To 3, 0 To 3) As Long
'   ' ... fill piece ...
'   vt_mat_rotate_cw(piece())   ' rotate one step clockwise
'
' Use for: Tetris/falling-block rotations, tile-map editors, sprite transforms,
'          any grid puzzle with rotation mechanics.
'-------------------------------------------------------------------------------

Sub vt_mat_rotate_cw(m() As Long)
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

Sub vt_mat_rotate_ccw(m() As Long)
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
