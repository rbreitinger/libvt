' =============================================================================
' VT-Solitaire - Klondike solitaire
' FreeBASIC 1.10.1 / libvt v1.7+ / #lang=fb
' (C) 2026 Rene Breitinger
' =============================================================================
#cmdline "-s gui -gen gcc -O 2"

#Define VT_USE_SORT
#Define VT_USE_MATH
#Define VT_USE_TUI
#Include once "../vt/vt.bi"

' =============================================================================
' Constants
' =============================================================================

Const VERSION       = "1.1.0"

' Card geometry
Const CARD_W        = 7          ' card width in cells
Const CARD_H        = 5          ' card height in cells
Const CARD_STEP     = 8          ' column stride between pile slots

' Layout (all 1-based)
Const LAYOUT_LEFT   = 13         ' leftmost pile column
Const TOP_ROW       = 3          ' row of stock / waste / foundations
Const TAB_ROW       = 9          ' row where tableau columns begin
Const COVER_STEP    = 2          ' rows a face-down card peeks above the next
Const UNCOVER_STEP  = 2          ' rows a face-up non-last card shows

' Suits (0-based)
Const SUIT_SPADE    = 0
Const SUIT_HEART    = 1
Const SUIT_DIAMOND  = 2
Const SUIT_CLUB     = 3

' Named ranks (0-based within suit)
Const RANK_ACE      = 0
Const RANK_TEN      = 9
Const RANK_JACK     = 10
Const RANK_QUEEN    = 11
Const RANK_KING     = 12

' Pile indices (0-based)
Const PILE_STOCK    = 0
Const PILE_WASTE    = 1
Const PILE_FOUND0   = 2          ' foundations: 2, 3, 4, 5
Const PILE_TAB0     = 6          ' tableau: 6 .. 12
Const PILE_COUNT    = 13

' Colors
Const COL_TABLE     = VT_GREEN
Const COL_CARD_BG   = VT_WHITE
Const COL_CARD_SEL  = VT_YELLOW
Const COL_CARD_BRD  = VT_DARK_GREY
Const COL_CARD_SELBRD = VT_BROWN  ' darker yellow for selected border
Const COL_RED_SUIT  = VT_BRIGHT_RED
Const COL_BLK_SUIT  = VT_BLACK
Const COL_BACK_FG   = VT_BRIGHT_BLUE
Const COL_BACK_BG   = VT_BLUE
Const COL_BAR_FG    = VT_WHITE
Const COL_BAR_BG    = VT_GREEN

' CP437 border glyphs
Const CH_TL         = 218        ' top-left corner
Const CH_TR         = 191        ' top-right corner
Const CH_BL         = 192        ' bottom-left corner
Const CH_BR         = 217        ' bottom-right corner
Const CH_HORIZ      = 196        ' horizontal line
Const CH_VERT       = 179        ' vertical line
Const CH_HATCH      = 177        ' dense hatch - card back fill

' Scoring
Const SCORE_START   = 5000
Const SCORE_FOUND   = 10         ' per card sent to foundation
Const SCORE_FLIP    = 5          ' per card turned face-up
Const SCORE_MIN     = 0

' Double-click window in seconds
Const DBL_CLICK_SEC = 0.35

' Undo ring buffer
Const UNDO_SLOTS    = 32         ' max undo depth
Const SCORE_UNDO    = 15         ' score penalty per undo

' Win animation
Const BALL_COUNT    = 20         ' simultaneous bouncing cards
Const ANIM_DUR_MS   = 5000       ' animation length in milliseconds
Const POS_SCALE     = 16         ' fixed-point sub-cell precision (1/16 cell)

' Config file (written next to the executable)
Const CFG_FILE      = "vtsolitaire.cfg"

' =============================================================================
' Types
' =============================================================================

Type CardPile
    cards(0 To 51)  As UByte     ' card values 0-51
    faceup(0 To 51) As Byte      ' 0=face-down  1=face-up
    cnt             As Long      ' number of cards currently in pile
End Type

' Full game snapshot for undo.  Fixed-size arrays inside a Type are copied
' on assignment in FreeBASIC, so one line handles the whole pile snapshot.
Type UndoState
    pile_data(0 To PILE_COUNT - 1) As CardPile
    sel_pile  As Long
    sel_card  As Long
    score_val As Long
    recycles  As Long
End Type

' One bouncing card for the win animation (positions in POS_SCALE units).
Type BallCard
    cx16  As Long    ' column position
    ry16  As Long    ' row position
    dx16  As Long    ' column velocity per frame
    dy16  As Long    ' row velocity per frame (positive = downward)
    card  As UByte   ' card value passed to DrawCard
End Type

' =============================================================================
' Globals
' =============================================================================

Dim Shared piles(0 To PILE_COUNT - 1) As CardPile

Dim Shared sel_pile           As Long    ' index of selected pile, -1 = nothing
Dim Shared sel_card           As Long    ' index within pile of the grabbed card
Dim Shared score_val          As Long
Dim Shared recycles           As Long
Dim Shared start_time         As Double
Dim Shared win_time           As Double  ' Timer snapshot when win is detected
Dim Shared is_won             As Byte
Dim Shared mb_prev            As Long    ' mouse button state previous frame
Dim Shared autocomplete_asked As Byte   ' 1 once the auto-complete dialog has fired

' draw mode (persists across games; set via Game > Options)
Dim Shared draw_mode  As Long    ' 0 = draw-1 (Klondike)  1 = draw-3 (Vegas)

' double-click tracking
Dim Shared dbl_pile   As Long    ' pile of last left-click  (-1 = none)
Dim Shared dbl_card   As Long    ' card index of last left-click
Dim Shared dbl_time   As Double  ' Timer timestamp of last left-click

' undo ring buffer
Dim Shared undo_buf(0 To UNDO_SLOTS - 1) As UndoState
Dim Shared undo_head  As Long    ' next write slot (wraps mod UNDO_SLOTS)
Dim Shared undo_cnt   As Long    ' number of valid snapshots currently stored

' Menu data  (Game: 3 items, Help: 2 items)
Dim Shared mgrp(0 To 1) As String
Dim Shared mitm(0 To 4) As String
Dim Shared mcnt(0 To 1) As Long

' =============================================================================
' Card helpers
' =============================================================================

Function CardSuit(card As UByte) As Long
    Return card \ 13
End Function

Function CardRank(card As UByte) As Long
    Return card Mod 13
End Function

Function IsRed(card As UByte) As Byte
    Dim s As Long = CardSuit(card)
    If s = SUIT_HEART Or s = SUIT_DIAMOND Then Return 1
    Return 0
End Function

Function SuitGlyph(suit As Long) As UByte
    Select Case suit
        Case SUIT_SPADE   : Return 6   ' CP437 spade
        Case SUIT_HEART   : Return 3   ' CP437 heart
        Case SUIT_DIAMOND : Return 4   ' CP437 diamond
        Case SUIT_CLUB    : Return 5   ' CP437 club
    End Select
    Return 63  ' ?
End Function

Function RankStr(rnk As Long) As String
    Select Case rnk
        Case RANK_ACE   : Return "A"
        Case 1 To 8     : Return Str(rnk + 1)
        Case RANK_TEN   : Return "10"
        Case RANK_JACK  : Return "J"
        Case RANK_QUEEN : Return "Q"
        Case RANK_KING  : Return "K"
    End Select
    Return "?"
End Function

' =============================================================================
' Layout helpers
' =============================================================================

Function PileCol(pidx As Long) As Long
    Select Case pidx
        Case PILE_STOCK                         : Return LAYOUT_LEFT
        Case PILE_WASTE                         : Return LAYOUT_LEFT + CARD_STEP
        ' foundations skip one slot (gap between waste and foundations)
        Case PILE_FOUND0 To PILE_FOUND0 + 3    : Return LAYOUT_LEFT + (pidx - PILE_FOUND0 + 3) * CARD_STEP
        ' tableau uses the full 7-slot grid
        Case PILE_TAB0 To PILE_TAB0 + 6        : Return LAYOUT_LEFT + (pidx - PILE_TAB0) * CARD_STEP
    End Select
    Return LAYOUT_LEFT
End Function

' Returns the peek-row stride for a tableau column,
' compressed when cnt is large enough to overflow the screen.
Function TabColStep(tidx As Long) As Long
    Dim cnt   As Long = piles(tidx).cnt
    If cnt <= 1 Then Return UNCOVER_STEP
    Dim avail As Long = vt_rows() - CARD_H + 1 - TAB_ROW   ' 17 on 80x30
    Dim stp   As Long = avail \ (cnt - 1)
    If stp < 1            Then stp = 1
    If stp > UNCOVER_STEP Then stp = UNCOVER_STEP
    Return stp
End Function

Function TabCardRow(tidx As Long, cidx As Long) As Long
    Return TAB_ROW + cidx * TabColStep(tidx)
End Function

' =============================================================================
' Drawing - all card drawing uses vt_set_cell exclusively
' =============================================================================

Sub DrawCard(col As Long, row As Long, card As UByte, face_up As Byte, selected As Byte)
    Dim c   As Long
    Dim r   As Long
    Dim cbg As UByte
    Dim fg  As UByte
    Dim brd As UByte

    ' -- face-down---------------------------------------------------------
    If face_up = 0 Then
        vt_set_cell col,           row,          CH_TL,    COL_CARD_BRD, COL_CARD_BG
        For c = col + 1 To col + CARD_W - 2
            vt_set_cell c,         row,          CH_HORIZ, COL_CARD_BRD, COL_CARD_BG
        Next c
        vt_set_cell col+CARD_W-1,  row,          CH_TR,    COL_CARD_BRD, COL_CARD_BG

        For r = row + 1 To row + CARD_H - 2
            vt_set_cell col,       r,            CH_VERT,  COL_CARD_BRD, COL_CARD_BG
            For c = col + 1 To col + CARD_W - 2
                vt_set_cell c,     r,            CH_HATCH, COL_BACK_FG,  COL_BACK_BG
            Next c
            vt_set_cell col+CARD_W-1, r,         CH_VERT,  COL_CARD_BRD, COL_CARD_BG
        Next r

        vt_set_cell col,           row+CARD_H-1, CH_BL,    COL_CARD_BRD, COL_CARD_BG
        For c = col + 1 To col + CARD_W - 2
            vt_set_cell c,         row+CARD_H-1, CH_HORIZ, COL_CARD_BRD, COL_CARD_BG
        Next c
        vt_set_cell col+CARD_W-1,  row+CARD_H-1, CH_BR,    COL_CARD_BRD, COL_CARD_BG
        Return
    End If

    ' -- face-up-----------------------------------------------------------
    Dim suit  As Long  = CardSuit(card)
    Dim rnk   As Long  = CardRank(card)
    Dim glyph As UByte = SuitGlyph(suit)

    cbg = IIf(selected, COL_CARD_SEL, COL_CARD_BG)
    fg  = IIf(IsRed(card), COL_RED_SUIT, COL_BLK_SUIT)
    brd = IIf(selected, COL_CARD_SELBRD, COL_CARD_BRD)

    ' row 1 - top border
    vt_set_cell col,          row,   CH_TL,    brd, cbg
    For c = col + 1 To col + CARD_W - 2
        vt_set_cell c,        row,   CH_HORIZ, brd, cbg
    Next c
    vt_set_cell col+CARD_W-1, row,   CH_TR,    brd, cbg

    ' row 2 - rank (left) and suit (right), inner width = 5 cells (col+1..col+5)
    vt_set_cell col,          row+1, CH_VERT,  brd, cbg
    If rnk = RANK_TEN Then
        vt_set_cell col+1,    row+1, Asc("1"), fg,  cbg
        vt_set_cell col+2,    row+1, Asc("0"), fg,  cbg
        vt_set_cell col+3,    row+1, 32,       fg,  cbg
        vt_set_cell col+4,    row+1, 32,       fg,  cbg
    Else
        vt_set_cell col+1,    row+1, Asc(Left(RankStr(rnk),1)), fg, cbg
        vt_set_cell col+2,    row+1, 32,       fg,  cbg
        vt_set_cell col+3,    row+1, 32,       fg,  cbg
        vt_set_cell col+4,    row+1, 32,       fg,  cbg
    End If
    vt_set_cell col+5,        row+1, glyph,    fg,  cbg
    vt_set_cell col+CARD_W-1, row+1, CH_VERT,  brd, cbg

    ' row 3 - empty interior
    vt_set_cell col,          row+2, CH_VERT,  brd, cbg
    For c = col + 1 To col + CARD_W - 2
        vt_set_cell c,        row+2, 32,       fg,  cbg
    Next c
    vt_set_cell col+CARD_W-1, row+2, CH_VERT,  brd, cbg

    ' row 4 - centered big suit glyph
    vt_set_cell col,          row+3, CH_VERT,  brd, cbg
    vt_set_cell col+1,        row+3, 32,       fg,  cbg
    vt_set_cell col+2,        row+3, 32,       fg,  cbg
    vt_set_cell col+3,        row+3, glyph,    fg,  cbg
    vt_set_cell col+4,        row+3, 32,       fg,  cbg
    vt_set_cell col+5,        row+3, 32,       fg,  cbg
    vt_set_cell col+CARD_W-1, row+3, CH_VERT,  brd, cbg

    ' row 5 - bottom border
    vt_set_cell col,          row+4, CH_BL,    brd, cbg
    For c = col + 1 To col + CARD_W - 2
        vt_set_cell c,        row+4, CH_HORIZ, brd, cbg
    Next c
    vt_set_cell col+CARD_W-1, row+4, CH_BR,    brd, cbg
End Sub

' Ghost outline drawn on empty pile slots, optional suit hint glyph
Sub DrawEmptyPile(col As Long, row As Long, suit_hint As Long)
    Dim c   As Long
    Dim r   As Long
    Dim fg  As UByte = VT_DARK_GREY
    Dim bg  As UByte = COL_TABLE

    vt_set_cell col,          row,          CH_TL,    fg, bg
    For c = col + 1 To col + CARD_W - 2
        vt_set_cell c,        row,          CH_HORIZ, fg, bg
    Next c
    vt_set_cell col+CARD_W-1, row,          CH_TR,    fg, bg

    For r = row + 1 To row + CARD_H - 2
        vt_set_cell col,      r,            CH_VERT,  fg, bg
        For c = col + 1 To col + CARD_W - 2
            vt_set_cell c,    r,            32,       fg, bg
        Next c
        vt_set_cell col+CARD_W-1, r,        CH_VERT,  fg, bg
    Next r

    vt_set_cell col,          row+CARD_H-1, CH_BL,    fg, bg
    For c = col + 1 To col + CARD_W - 2
        vt_set_cell c,        row+CARD_H-1, CH_HORIZ, fg, bg
    Next c
    vt_set_cell col+CARD_W-1, row+CARD_H-1, CH_BR,    fg, bg

    ' center glyph: suit hint for foundations, recycling arrow for empty stock
    If suit_hint >= 0 AndAlso suit_hint <= 3 Then
        vt_set_cell col + 3, row + 2, SuitGlyph(suit_hint), fg, bg
    ElseIf suit_hint = -2 Then
        ' -2 = recycle indicator (empty stock)
        vt_set_cell col + 3, row + 2, 21, fg, bg
    End If
End Sub

Sub DrawInfoBar()
    ' freeze the clock at win_time once the game is won
    Dim t_ref As Double
    If is_won Then
        t_ref = win_time
    Else
        t_ref = Timer
    End If
    Dim elapsed As Long   = CLng(t_ref - start_time)
    Dim mins    As Long   = elapsed \ 60
    Dim secs    As Long   = elapsed Mod 60
    Dim secstr  As String = IIf(secs < 10, "0", "") & Str(secs)

    Dim mode_lbl As String = IIf(draw_mode = 1, "Vegas", "Klondike")

    Dim txt As String = " Score: " & Str(score_val) & _
        "   Time: " & Str(mins) & ":" & secstr & _
        "   Recycles: " & Str(recycles) & _
        "   " & mode_lbl

    ' pad to full screen width
    Do While Len(txt) < vt_cols()
        txt += " "
    Loop

    vt_locate 2, 1
    vt_color COL_BAR_FG, COL_BAR_BG
    vt_print txt
End Sub

Sub RenderAll()
    ' -- clear table (rows 2-30, preserve row 1 for menubar)----------------
    vt_view_print 2, vt_rows(), 1, vt_cols()
    vt_cls COL_TABLE
    vt_view_print -1, -1, -1, -1

    DrawInfoBar

    ' -- stock---------------------------------------------------------------
    Dim scol As Long = PileCol(PILE_STOCK)
    If piles(PILE_STOCK).cnt > 0 Then
        DrawCard scol, TOP_ROW, piles(PILE_STOCK).cards(0), 0, 0
    Else
        DrawEmptyPile scol, TOP_ROW, -2   ' -2 = recycle hint
    End If

    ' -- waste---------------------------------------------------------------
    ' draw-1: show only the top card
    ' draw-3: show up to 3 cards overlapping at UNCOVER_STEP, oldest drawn first
    '         so each successive card overwrites and appears on top (no alpha needed)
    Dim wcol As Long = PileCol(PILE_WASTE)
    If piles(PILE_WASTE).cnt > 0 Then
        Dim wtop As Long = piles(PILE_WASTE).cnt - 1
        If draw_mode = 1 AndAlso piles(PILE_WASTE).cnt >= 2 Then
            Dim wshow As Long = VT_MIN(piles(PILE_WASTE).cnt, 3)
            Dim wbase As Long = wtop - wshow + 1
            Dim wi    As Long
            For wi = 0 To wshow - 1
                Dim wci  As Long = wbase + wi
                Dim wcx  As Long = wcol + wi * UNCOVER_STEP
                Dim wsel As Byte = IIf(wci = wtop AndAlso sel_pile = PILE_WASTE, CByte(1), CByte(0))
                DrawCard wcx, TOP_ROW, piles(PILE_WASTE).cards(wci), 1, wsel
            Next wi
        Else
            Dim wsel1 As Byte = IIf(sel_pile = PILE_WASTE, CByte(1), CByte(0))
            DrawCard wcol, TOP_ROW, piles(PILE_WASTE).cards(wtop), 1, wsel1
        End If
    Else
        DrawEmptyPile wcol, TOP_ROW, -1
    End If

    ' -- foundations---------------------------------------------------------
    Dim fi As Long
    For fi = 0 To 3
        Dim fidx As Long = PILE_FOUND0 + fi
        Dim fcol As Long = PileCol(fidx)
        If piles(fidx).cnt > 0 Then
            Dim ftop As Long = piles(fidx).cnt - 1
            DrawCard fcol, TOP_ROW, piles(fidx).cards(ftop), 1, 0
        Else
            DrawEmptyPile fcol, TOP_ROW, fi   ' fi=0..3 = suit hint
        End If
    Next fi

    ' -- tableau-------------------------------------------------------------
    Dim ti As Long
    For ti = 0 To 6
        Dim tidx As Long = PILE_TAB0 + ti
        Dim tcol As Long = PileCol(tidx)

        If piles(tidx).cnt = 0 Then
            DrawEmptyPile tcol, TAB_ROW, -1
            Continue For
        End If

        Dim ci As Long
        For ci = 0 To piles(tidx).cnt - 1
            Dim crow  As Long = TabCardRow(tidx, ci)
            If crow > vt_rows() Then Exit For   ' clip at screen bottom

            Dim is_sel As Byte = IIf(sel_pile = tidx AndAlso ci >= sel_card, CByte(1), CByte(0))
            DrawCard tcol, crow, piles(tidx).cards(ci), piles(tidx).faceup(ci), is_sel
        Next ci
    Next ti
End Sub

' =============================================================================
' Game logic
' =============================================================================

Sub NewGame()
    Dim i As Long
    For i = 0 To PILE_COUNT - 1
        piles(i).cnt = 0
    Next i

    ' build deck 0-51 and shuffle
    Dim deck(0 To 51) As UByte
    For i = 0 To 51
        deck(i) = CUByte(i)
    Next i
    vt_sort_shuffle deck()

    ' deal tableau: column t gets t+1 cards, last one face-up
    Dim di As Long = 0
    Dim t  As Long
    Dim ci As Long
    For t = 0 To 6
        Dim tidx As Long = PILE_TAB0 + t
        For ci = 0 To t
            piles(tidx).cards(piles(tidx).cnt) = deck(di)
            piles(tidx).faceup(piles(tidx).cnt) = IIf(ci = t, CByte(1), CByte(0))
            piles(tidx).cnt += 1
            di += 1
        Next ci
    Next t

    ' remaining cards to stock (all face-down)
    Do While di < 52
        piles(PILE_STOCK).cards(piles(PILE_STOCK).cnt) = deck(di)
        piles(PILE_STOCK).faceup(piles(PILE_STOCK).cnt) = 0
        piles(PILE_STOCK).cnt += 1
        di += 1
    Loop

    sel_pile           = -1
    sel_card           = 0
    score_val          = SCORE_START
    recycles           = 0
    start_time         = Timer
    win_time           = 0
    is_won             = 0
    mb_prev            = 0
    autocomplete_asked = 0
    dbl_pile           = -1
    undo_head          = 0
    undo_cnt           = 0
End Sub

Function CanMoveToFoundation(card As UByte, fi As Long) As Byte
    ' fi = foundation index 0..3 (not pile index)
    Dim fidx As Long = PILE_FOUND0 + fi
    Dim rnk  As Long = CardRank(card)
    Dim suit As Long = CardSuit(card)

    If piles(fidx).cnt = 0 Then
        If rnk = RANK_ACE AndAlso suit = fi Then Return 1
        Return 0
    End If

    Dim topc As UByte = piles(fidx).cards(piles(fidx).cnt - 1)
    If CardSuit(topc) = suit AndAlso CardRank(topc) = rnk - 1 Then Return 1
    Return 0
End Function

Function CanMoveToTableau(card As UByte, ti As Long) As Byte
    ' ti = tableau index 0..6 (not pile index)
    Dim tidx As Long = PILE_TAB0 + ti
    Dim rnk  As Long = CardRank(card)

    If piles(tidx).cnt = 0 Then
        If rnk = RANK_KING Then Return 1
        Return 0
    End If

    Dim topc  As UByte = piles(tidx).cards(piles(tidx).cnt - 1)
    Dim topup As Byte  = piles(tidx).faceup(piles(tidx).cnt - 1)
    If topup = 0 Then Return 0

    ' opposite color AND one rank higher (so card sits below top)
    If (IsRed(card) Xor IsRed(topc)) AndAlso CardRank(topc) = rnk + 1 Then Return 1
    Return 0
End Function

' flip newly exposed top card face-up and add flip score
Sub FlipNewTop(pidx As Long)
    If piles(pidx).cnt <= 0 Then Return
    If piles(pidx).faceup(piles(pidx).cnt - 1) = 0 Then
        piles(pidx).faceup(piles(pidx).cnt - 1) = 1
        score_val += SCORE_FLIP
    End If
End Sub


' =============================================================================
' Win animation
' =============================================================================

' 20 cards shot upward from the floor with random velocities, bouncing around
' the screen until the player clicks/presses a key or ~5 seconds elapse.
' Uses 1/POS_SCALE fixed-point positions so motion is smooth at cell resolution.
' Gravity accumulates one unit per frame; floor bounce dampens to 75% energy.
Sub ShowWinAnimation()
    Dim balls(0 To BALL_COUNT - 1) As BallCard

    Dim floor16   As Long = (vt_rows() - CARD_H + 1) * POS_SCALE
    Dim ceil16    As Long = 1 * POS_SCALE
    Dim wall_r16  As Long = (vt_cols() - CARD_W + 1) * POS_SCALE
    Dim wall_l16  As Long = 1 * POS_SCALE

    ' initialise all balls: random foundation card, random col, start at floor
    Dim i As Long
    For i = 0 To BALL_COUNT - 1
        Dim bfi  As Long  = vt_rnd(0, 3)
        Dim bci  As Long  = vt_rnd(0, piles(PILE_FOUND0 + bfi).cnt - 1)
        balls(i).card = piles(PILE_FOUND0 + bfi).cards(bci)
        balls(i).cx16 = vt_rnd(1, vt_cols() - CARD_W + 1) * POS_SCALE
        balls(i).ry16 = floor16
        ' random upward velocity; random left/right
        balls(i).dy16 = -vt_rnd(10, 20)
        balls(i).dx16 = vt_rnd(3, 7)
        If vt_rnd(0, 1) Then balls(i).dx16 = -balls(i).dx16
    Next i

    Dim t_start  As Double = Timer
    Dim mb_anim  As Long   = 0
    Dim mx_a     As Long, my_a As Long, mb_a As Long

    Do
        ' -- exit conditions -------------------------------------------------
        Dim ka As ULong = vt_inkey()
        If VT_SCAN(ka) <> 0 OrElse VT_CHAR(ka) <> 0 Then Exit Do
        vt_getmouse @mx_a, @my_a, @mb_a
        If mb_a And (Not mb_anim) Then Exit Do
        mb_anim = mb_a
        If (Timer - t_start) * 1000 >= ANIM_DUR_MS Then Exit Do

        ' -- draw background then balls on top --------------------------------
        RenderAll
        vt_tui_menubar_draw 1, mgrp()

        For i = 0 To BALL_COUNT - 1
            ' physics
            balls(i).cx16 += balls(i).dx16
            balls(i).ry16 += balls(i).dy16
            balls(i).dy16 += 1   ' gravity

            ' side walls
            If balls(i).cx16 < wall_l16 Then
                balls(i).cx16 = wall_l16
                balls(i).dx16 =  Abs(balls(i).dx16)
            ElseIf balls(i).cx16 > wall_r16 Then
                balls(i).cx16 = wall_r16
                balls(i).dx16 = -Abs(balls(i).dx16)
            End If

            ' ceiling
            If balls(i).ry16 < ceil16 Then
                balls(i).ry16 = ceil16
                balls(i).dy16 =  Abs(balls(i).dy16)
            End If

            ' floor: bounce with 75% damping; re-energise when nearly still
            If balls(i).ry16 > floor16 Then
                balls(i).ry16 = floor16
                balls(i).dy16 = -(Abs(balls(i).dy16) * 3 \ 4)
                If Abs(balls(i).dy16) < 4 Then
                    balls(i).dy16 = -vt_rnd(8, 16)
                End If
            End If

            DrawCard balls(i).cx16 \ POS_SCALE, balls(i).ry16 \ POS_SCALE, _
                     balls(i).card, 1, 0
        Next i

        vt_sleep 16
    Loop
End Sub


Sub CheckWin()
    Dim i As Long
    For i = 0 To 3
        If piles(PILE_FOUND0 + i).cnt <> 13 Then Return
    Next i

    is_won   = 1
    win_time = Timer   ' freeze display clock at this exact moment

    ShowWinAnimation   ' bouncing card cascade before the dialog

    Dim elapsed As Long  = CLng(win_time - start_time)
    Dim mins    As Long  = elapsed \ 60
    Dim secs    As Long  = elapsed Mod 60
    Dim secstr  As String = IIf(secs < 10, "0", "") & Str(secs)

    Dim msg As String = _
        "You solved it!" & VT_LF & VT_LF & _
        "Time:      " & Str(mins) & ":" & secstr & VT_LF & _
        "Score:     " & Str(score_val) & VT_LF & _
        "Recycles:  " & Str(recycles)
    vt_tui_dialog "You Win!", msg, VT_DLG_OK

    NewGame   ' start fresh automatically after dialog is dismissed
End Sub

' =============================================================================
' Auto-complete
' =============================================================================

' Returns 1 when the game can be finished automatically:
' stock empty, waste empty, and every tableau card is face-up.
' Aces cannot be buried in a valid Klondike tableau (nothing stacks on an ace),
' so all remaining aces are column tops and the greedy foundation-move loop
' is guaranteed to terminate without getting stuck.
Function IsAutoCompleteReady() As Byte
    If piles(PILE_STOCK).cnt > 0 Then Return 0
    If piles(PILE_WASTE).cnt  > 0 Then Return 0
    Dim ti As Long
    For ti = 0 To 6
        Dim tidx As Long = PILE_TAB0 + ti
        Dim ci   As Long
        For ci = 0 To piles(tidx).cnt - 1
            If piles(tidx).faceup(ci) = 0 Then Return 0
        Next ci
    Next ti
    Return 1
End Function

' Offer auto-complete once per game; if accepted, animate cards to foundations
' one per frame then hand off to CheckWin.  Called from the main loop after
' every left-click so the check is free (IsAutoCompleteReady exits immediately
' while the flag or any face-down card is present).
Sub CheckAutoComplete()
    If is_won             Then Return
    If autocomplete_asked Then Return   ' only offer once per game
    If IsAutoCompleteReady() = 0 Then Return

    autocomplete_asked = 1   ' set now; declining still prevents re-asking

    Dim ans As Long = vt_tui_dialog("Auto-complete?", _
        "All cards are face-up!" & VT_LF & _
        "Finish the game automatically?", VT_DLG_YESNO)
    If ans <> VT_RET_YES Then Return

    ' greedy loop: each pass moves the first tableau top that fits any foundation,
    ' renders the frame, sleeps, then restarts the column scan.
    Dim moved As Byte = 1
    Do While moved
        moved = 0
        Dim ti As Long
        For ti = 0 To 6
            Dim tidx  As Long  = PILE_TAB0 + ti
            If piles(tidx).cnt = 0 Then Continue For
            Dim tcard As UByte = piles(tidx).cards(piles(tidx).cnt - 1)
            Dim fi    As Long
            For fi = 0 To 3
                If CanMoveToFoundation(tcard, fi) Then
                    Dim fidx As Long = PILE_FOUND0 + fi
                    piles(fidx).cards(piles(fidx).cnt) = tcard
                    piles(fidx).faceup(piles(fidx).cnt) = 1
                    piles(fidx).cnt += 1
                    piles(tidx).cnt -= 1
                    score_val += SCORE_FOUND
                    moved = 1
                    RenderAll
                    vt_tui_menubar_draw 1, mgrp()
                    vt_sleep 80
                    Exit For   ' break inner loop; If moved exits outer loop
                End If
            Next fi
            If moved Then Exit For
        Next ti
    Loop

    CheckWin   ' all 52 cards on foundations -> win dialog -> NewGame
End Sub

' =============================================================================
' Undo
' =============================================================================

' Snapshot the full game state into the next ring-buffer slot.
' Call this immediately before any action that modifies piles/score/recycles.
Sub UndoPush()
    Dim i As Long
    For i = 0 To PILE_COUNT - 1
        undo_buf(undo_head).pile_data(i) = piles(i)
    Next i
    undo_buf(undo_head).sel_pile  = sel_pile
    undo_buf(undo_head).sel_card  = sel_card
    undo_buf(undo_head).score_val = score_val
    undo_buf(undo_head).recycles  = recycles
    undo_head = (undo_head + 1) Mod UNDO_SLOTS
    If undo_cnt < UNDO_SLOTS Then undo_cnt += 1
End Sub

' Remove the last pushed snapshot without restoring it.
' Used when an attempted move turns out to be illegal (no wasted slot left behind).
Sub UndoCancel()
    If undo_cnt = 0 Then Return
    undo_head = (undo_head - 1 + UNDO_SLOTS) Mod UNDO_SLOTS
    undo_cnt -= 1
End Sub

' Restore the previous state, apply a small score penalty, clear selection.
' Resets autocomplete_asked so the offer can re-fire if the player undoes
' back past the trigger point.
Sub UndoPop()
    If undo_cnt = 0 Then Return
    undo_head = (undo_head - 1 + UNDO_SLOTS) Mod UNDO_SLOTS
    undo_cnt -= 1
    Dim i As Long
    For i = 0 To PILE_COUNT - 1
        piles(i) = undo_buf(undo_head).pile_data(i)
    Next i
    score_val         = undo_buf(undo_head).score_val - SCORE_UNDO
    recycles          = undo_buf(undo_head).recycles
    sel_pile          = -1   ' always clear selection after undo
    autocomplete_asked = 0   ' allow offer to re-fire if conditions are met again
    If score_val < SCORE_MIN Then score_val = SCORE_MIN
End Sub

' =============================================================================
' Hit test
' =============================================================================

' Fill hit_pile / hit_card from a mouse coordinate.
' hit_pile = -1  means nothing was hit.
' hit_card = -1  means an empty pile slot was hit (valid drop target).
Sub HitTest(mx As Long, my As Long, ByRef hit_pile As Long, ByRef hit_card As Long)
    hit_pile = -1
    hit_card = -1

    ' -- stock---------------------------------------------------------------
    If vt_in_rect(mx, my, PileCol(PILE_STOCK), TOP_ROW, CARD_W, CARD_H) Then
        hit_pile = PILE_STOCK
        hit_card = piles(PILE_STOCK).cnt - 1
        Return
    End If

    ' -- waste---------------------------------------------------------------
    ' draw-3: hit area widens to cover all visible overlapping cards;
    '         only the top card is ever returned as the hit card
    Dim wcol2 As Long = PileCol(PILE_WASTE)
    If draw_mode = 1 AndAlso piles(PILE_WASTE).cnt >= 2 Then
        Dim wshow2 As Long = VT_MIN(piles(PILE_WASTE).cnt, 3)
        Dim whit_w As Long = (wshow2 - 1) * UNCOVER_STEP + CARD_W
        If vt_in_rect(mx, my, wcol2, TOP_ROW, whit_w, CARD_H) Then
            hit_pile = PILE_WASTE
            hit_card = piles(PILE_WASTE).cnt - 1
            Return
        End If
    Else
        If vt_in_rect(mx, my, wcol2, TOP_ROW, CARD_W, CARD_H) Then
            hit_pile = PILE_WASTE
            hit_card = piles(PILE_WASTE).cnt - 1
            Return
        End If
    End If

    ' -- foundations---------------------------------------------------------
    Dim fi As Long
    For fi = 0 To 3
        Dim fidx As Long = PILE_FOUND0 + fi
        If vt_in_rect(mx, my, PileCol(fidx), TOP_ROW, CARD_W, CARD_H) Then
            hit_pile = fidx
            hit_card = piles(fidx).cnt - 1
            Return
        End If
    Next fi

    ' -- tableau: check from top card down for each column-------------------
    Dim ti As Long
    For ti = 0 To 6
        Dim tidx As Long = PILE_TAB0 + ti
        Dim tcol As Long = PileCol(tidx)

        If piles(tidx).cnt = 0 Then
            If vt_in_rect(mx, my, tcol, TAB_ROW, CARD_W, CARD_H) Then
                hit_pile = tidx
                hit_card = -1   ' empty slot
                Return
            End If
            Continue For
        End If

        Dim top_ci As Long = piles(tidx).cnt - 1
        Dim topr   As Long = TabCardRow(tidx, top_ci)

        ' top card: test full card height
        If vt_in_rect(mx, my, tcol, topr, CARD_W, CARD_H) Then
            hit_pile = tidx
            hit_card = top_ci
            Return
        End If

        ' buried cards: test only their visible peek strip
        Dim stp As Long = TabColStep(tidx)
        Dim ci  As Long
        For ci = top_ci - 1 To 0 Step -1
            Dim crow  As Long = TabCardRow(tidx, ci)
            Dim strip As Long = stp
            If vt_in_rect(mx, my, tcol, crow, CARD_W, strip) Then
                hit_pile = tidx
                hit_card = ci
                Return
            End If
        Next ci
    Next ti
End Sub

' =============================================================================
' Click handler
' =============================================================================

Sub HandleClick(mx As Long, my As Long)
    Dim hit_pile As Long
    Dim hit_card As Long
    HitTest mx, my, hit_pile, hit_card

    ' -- double-click detection ---------------------------------------------
    ' Checked before all other logic.  The first click runs normal select /
    ' flip logic; the second click (if within DBL_CLICK_SEC and same target)
    ' cancels any pending selection and auto-moves to the first foundation
    ' that will accept the card.  Valid sources: waste top, tableau top face-up.
    ' Any other target or failed move is a silent no-op; click is consumed either way.
    Dim is_dbl As Byte = 0
    If hit_pile >= 0 AndAlso dbl_pile = hit_pile AndAlso dbl_card = hit_card Then
        If (Timer - dbl_time) < DBL_CLICK_SEC Then
            is_dbl = 1
        End If
    End If

    ' update tracker unconditionally, then reset on confirmed double
    If hit_pile >= 0 Then
        dbl_pile = hit_pile
        dbl_card = hit_card
        dbl_time = Timer
    Else
        dbl_pile = -1
    End If

    If is_dbl Then
        dbl_pile = -1   ' consume; next click starts a fresh window

        Dim can_dbl As Byte = 0
        If hit_pile = PILE_WASTE AndAlso hit_card >= 0 AndAlso _
           hit_card = piles(PILE_WASTE).cnt - 1 Then
            can_dbl = 1
        ElseIf hit_pile >= PILE_TAB0 AndAlso hit_card >= 0 AndAlso _
               hit_card = piles(hit_pile).cnt - 1 Then
            If piles(hit_pile).faceup(hit_card) Then can_dbl = 1
        End If

        If can_dbl Then
            UndoPush
            sel_pile = -1   ' cancel selection set by the first click
            Dim dbl_src As UByte = piles(hit_pile).cards(hit_card)
            Dim dbl_fi  As Long
            For dbl_fi = 0 To 3
                If CanMoveToFoundation(dbl_src, dbl_fi) Then
                    Dim dbl_fidx As Long = PILE_FOUND0 + dbl_fi
                    piles(dbl_fidx).cards(piles(dbl_fidx).cnt) = dbl_src
                    piles(dbl_fidx).faceup(piles(dbl_fidx).cnt) = 1
                    piles(dbl_fidx).cnt += 1
                    piles(hit_pile).cnt -= 1
                    score_val += SCORE_FOUND
                    FlipNewTop hit_pile
                    CheckWin
                    Return
                End If
            Next dbl_fi
            UndoCancel   ' no foundation accepted the card
        End If
        Return   ' double-click consumed (no-op if source invalid or no foundation accepted)
    End If

    ' -- clicked empty space-------------------------------------------------
    If hit_pile = -1 Then
        sel_pile = -1
        Return
    End If

    ' -- stock: flip card(s) or recycle waste--------------------------------
    If hit_pile = PILE_STOCK Then
        sel_pile = -1
        UndoPush
        If piles(PILE_STOCK).cnt > 0 Then
            ' draw-3: flip up to 3 cards at once; draw-1: flip exactly 1
            Dim flip_max As Long = IIf(draw_mode = 1, 3, 1)
            Dim flipped  As Long
            For flipped = 1 To flip_max
                If piles(PILE_STOCK).cnt = 0 Then Exit For
                Dim si As Long = piles(PILE_STOCK).cnt - 1
                piles(PILE_WASTE).cards(piles(PILE_WASTE).cnt) = piles(PILE_STOCK).cards(si)
                piles(PILE_WASTE).faceup(piles(PILE_WASTE).cnt) = 1
                piles(PILE_WASTE).cnt += 1
                piles(PILE_STOCK).cnt -= 1
            Next flipped
        Else
            ' recycle waste back to stock, penalize score
            recycles += 1
            score_val = CLng(score_val * 0.9)
            If score_val < SCORE_MIN Then score_val = SCORE_MIN
            Dim wi As Long
            For wi = piles(PILE_WASTE).cnt - 1 To 0 Step -1
                piles(PILE_STOCK).cards(piles(PILE_STOCK).cnt) = piles(PILE_WASTE).cards(wi)
                piles(PILE_STOCK).faceup(piles(PILE_STOCK).cnt) = 0
                piles(PILE_STOCK).cnt += 1
            Next wi
            piles(PILE_WASTE).cnt = 0
        End If
        Return
    End If

    ' -- card already selected: try to move it-------------------------------
    If sel_pile >= 0 Then
        ' clicking same pile = deselect
        If hit_pile = sel_pile Then
            sel_pile = -1
            Return
        End If

        Dim src_card As UByte = piles(sel_pile).cards(sel_card)
        Dim moved    As Byte  = 0
        UndoPush   ' snapshot before attempting the move

        ' try foundation
        If hit_pile >= PILE_FOUND0 AndAlso hit_pile < PILE_TAB0 Then
            ' only single top card goes to foundation
            If sel_card = piles(sel_pile).cnt - 1 Then
                Dim fii As Long = hit_pile - PILE_FOUND0
                If CanMoveToFoundation(src_card, fii) Then
                    piles(hit_pile).cards(piles(hit_pile).cnt) = src_card
                    piles(hit_pile).faceup(piles(hit_pile).cnt) = 1
                    piles(hit_pile).cnt += 1
                    piles(sel_pile).cnt -= 1
                    score_val += SCORE_FOUND
                    FlipNewTop sel_pile
                    moved = 1
                End If
            End If
        End If

        ' try tableau
        If moved = 0 AndAlso hit_pile >= PILE_TAB0 Then
            Dim tii As Long = hit_pile - PILE_TAB0
            If CanMoveToTableau(src_card, tii) Then
                Dim num_move As Long = piles(sel_pile).cnt - sel_card
                Dim j        As Long
                For j = 0 To num_move - 1
                    piles(hit_pile).cards(piles(hit_pile).cnt) = piles(sel_pile).cards(sel_card + j)
                    piles(hit_pile).faceup(piles(hit_pile).cnt) = 1
                    piles(hit_pile).cnt += 1
                Next j
                piles(sel_pile).cnt -= num_move
                FlipNewTop sel_pile
                moved = 1
            End If
        End If

        If moved Then
            sel_pile = -1
            CheckWin
            Return
        End If

        ' move failed - deselect, then try to select what was clicked
        UndoCancel   ' discard the snapshot; nothing changed
        sel_pile = -1
        If hit_card < 0 Then Return
    End If

    ' -- select a card-------------------------------------------------------
    If hit_card < 0 Then Return   ' empty pile with no card to grab

    ' foundations are not selectable as source
    If hit_pile >= PILE_FOUND0 AndAlso hit_pile < PILE_TAB0 Then Return

    If hit_pile >= PILE_TAB0 Then
        If piles(hit_pile).faceup(hit_card) = 0 Then
            ' face-down top card: flip it
            If hit_card = piles(hit_pile).cnt - 1 Then
                UndoPush
                piles(hit_pile).faceup(hit_card) = 1
                score_val += SCORE_FLIP
            End If
            Return
        End If
    ElseIf hit_pile = PILE_WASTE Then
        If hit_card < 0 Then Return   ' empty waste
    End If

    sel_pile = hit_pile
    sel_card = hit_card
End Sub

' =============================================================================
' Modal dialogs
' =============================================================================

Sub SaveConfig()
    Dim f As Long = FreeFile
    Open ExePath & "/" & CFG_FILE For Output As #f
    Print #f, "draw_mode=" & Str(draw_mode)
    Close #f
End Sub

Sub LoadConfig()
    Dim cfg_path As String = ExePath & "/" & CFG_FILE
    If vt_file_exists(cfg_path) = 0 Then Return
    Dim f    As Long = FreeFile
    Dim ln   As String
    Dim mode As Long = -1
    Open cfg_path For Input As #f
    Do While Not EOF(f)
        Line Input #f, ln
        If Left(ln, 10) = "draw_mode=" Then
            mode = Val(Mid(ln, 11))
        End If
    Loop
    Close #f
    If mode = 0 Or mode = 1 Then draw_mode = mode
End Sub

Sub ShowHelp()
    Dim txt As String = _
        "GOAL" & VT_LF & _
        "Move all 52 cards to the 4 foundations" & VT_LF & _
        "sorted by suit, Ace up to King." & VT_LF & VT_LF & _
        "TABLEAU" & VT_LF & _
        "Build columns down in alternating colors." & VT_LF & _
        "Only a King may start an empty column." & VT_LF & _
        "Grab a run of face-up cards at once." & VT_LF & VT_LF & _
        "STOCK / WASTE" & VT_LF & _
        "Click stock to flip card(s) to waste." & VT_LF & _
        "Click empty stock to recycle (score x0.9)." & VT_LF & VT_LF & _
        "MOUSE" & VT_LF & _
        "Left-click: select / move / flip / deal." & VT_LF & _
        "Double-click: auto-move top card to foundation." & VT_LF & _
        "Right-click: deselect." & VT_LF & _
        "CTRL+Z: undo move, up to 32, costs score"
    vt_tui_dialog "How to Play", txt, VT_DLG_OK
End Sub

Sub ShowInfo()
    Dim txt As String = _
        "VT-Solitaire  v" & VERSION & VT_LF & VT_LF & _
        "Written in FreeBASIC 1.10.1" & VT_LF & _
        "using libvt v1.7.0" & VT_LF & VT_LF & _
        "(C) 2026 Rene Breitinger"
    vt_tui_dialog "About VT-Solitaire", txt, VT_DLG_OK
End Sub

Sub ShowOptions()
    ' Non-blocking form in its own mini-loop.
    ' Radio group 1: draw mode.  Buttons: OK (ret=1) / Cancel (ret=0).
    ' Layout uses local coords (1,1 = inner top-left of bordered window).
    ' If the draw mode changes, a new game starts automatically because the
    ' flip-count difference makes the current game state meaningless.
    Const WIN_X = 27, WIN_Y = 11, WIN_W = 28, WIN_H = 9

    Dim prev_mode As Long = draw_mode   ' remember so we can detect a change
    Dim items(0 To 3) As vt_tui_form_item

    ' radio: Draw 1
    items(0).kind     = VT_FORM_RADIO
    items(0).x        = 3 : items(0).y = 2
    items(0).val      = "Draw 1 (Klondike)"
    items(0).group_id = 1
    items(0).checked  = IIf(draw_mode = 0, CByte(1), CByte(0))

    ' radio: Draw 3
    items(1).kind     = VT_FORM_RADIO
    items(1).x        = 3 : items(1).y = 3
    items(1).val      = "Draw 3 (Vegas)"
    items(1).group_id = 1
    items(1).checked  = IIf(draw_mode = 1, CByte(1), CByte(0))

    ' button: OK
    items(2).kind = VT_FORM_BUTTON
    items(2).x    = 6  : items(2).y = 6
    items(2).val  = "  OK  "
    items(2).ret  = 1

    ' button: Cancel
    items(3).kind = VT_FORM_BUTTON
    items(3).x    = 16 : items(3).y = 6
    items(3).val  = "Cancel"
    items(3).ret  = 0

    vt_tui_form_offset items(), WIN_X, WIN_Y

    Dim focused As Long = 0
    Dim fret    As Long = VT_FORM_PENDING
    Dim fk      As ULong

    Do
        fk   = vt_inkey()
        fret = vt_tui_form_handle(items(), focused, fk)

        vt_tui_window WIN_X, WIN_Y, WIN_W, WIN_H, " Options "
        vt_tui_form_draw items(), focused
        vt_sleep 16
    Loop While fret = VT_FORM_PENDING

    If fret = 1 Then   ' OK clicked
        draw_mode = IIf(items(1).checked, 1, 0)
        If draw_mode <> prev_mode Then
            SaveConfig
            NewGame
        End If
    End If
End Sub

' =============================================================================
' Main
' =============================================================================

vt_title "VT-Solitaire"
If vt_screen(VT_SCREEN_12, VT_WINDOWED) <> 0 Then End
vt_mouse 1
vt_locate , , 0   ' hide text cursor
Randomize

' menu setup  (Game: New Game / Options / Quit   Help: How to Play / Info)
mgrp(0) = " Game " : mgrp(1) = " Help "
mitm(0) = "New Game" : mitm(1) = "Options" : mitm(2) = "Quit"
mitm(3) = "How to Play" : mitm(4) = "Info"
mcnt(0) = 3 : mcnt(1) = 2

LoadConfig   ' restore draw_mode from previous session before first deal
NewGame

Dim k  As ULong
Dim mx As Long, my As Long, mb As Long

Do
    k = vt_inkey()

    ' -- keyboard shortcuts--------------------------------------------------
    If VT_CHAR(k) = 26 Then   ' Ctrl+Z = undo
        If is_won = 0 Then UndoPop
    End If

    ' -- menu bar------------------------------------------------------------
    Dim mret As Long = vt_tui_menubar_handle(1, mgrp(), mitm(), mcnt(), k)
    If mret > 0 Then
        Select Case VT_TUI_MENU_GROUP(mret)
            Case 1
                Select Case VT_TUI_MENU_ITEM(mret)
                    Case 1 : NewGame
                    Case 2 : ShowOptions
                    Case 3 : Exit Do
                End Select
            Case 2
                Select Case VT_TUI_MENU_ITEM(mret)
                    Case 1 : ShowHelp
                    Case 2 : ShowInfo
                End Select
        End Select
    End If

    ' -- mouse---------------------------------------------------------------
    vt_getmouse @mx, @my, @mb

    If (mb And VT_MOUSE_BTN_LEFT) And (Not (mb_prev And VT_MOUSE_BTN_LEFT)) Then
        If is_won = 0 Then
            HandleClick mx, my
            CheckAutoComplete
        End If
    End If

    If (mb And VT_MOUSE_BTN_RIGHT) And (Not (mb_prev And VT_MOUSE_BTN_RIGHT)) Then
        sel_pile = -1
    End If

    mb_prev = mb

    ' -- render--------------------------------------------------------------
    RenderAll
    vt_tui_menubar_draw 1, mgrp()
    vt_sleep 16
Loop

vt_shutdown
