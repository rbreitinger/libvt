' =============================================================================
' vt_misc.bas - VT Miscellaneous Utilities
' =============================================================================

'>>>
':topic vt_rnd
':short Random Long in an inclusive range
':group Utilities
'Return a random Long in the inclusive range
'[lo .. hi]. Negative bounds are fully supported.
'If lo > hi the two values are swapped silently.
'Seeding the RNG with Randomize is the caller's
'responsibility - vt_rnd does not call it.
':syntax
Function vt_rnd(lo As Long, hi As Long) As Long
        ':params
        'lo  Lower bound (inclusive).
        'hi  Upper bound (inclusive).
        ':example
        'Randomize
        '
        'Dim n As Long = vt_rnd(-15, 15)
        'Dim d As Long = vt_rnd(1, 6)
        'Dim x As Long = vt_rnd(1, vt_cols())
        ':see
        'vt_wrap
    '<<<
    If lo > hi Then Swap lo, hi
    Return Int(Rnd * (hi - lo + 1)) + lo
End Function

' ================================================================
'  vt_sort : opt-in generic array sort via overloading (shellsort)
' ================================================================
#Ifdef VT_USE_SORT
    '>>>
    ':topic c_sortconsts
    ':short Sort constants (opt-in: VT_USE_SORT)
    ':group Constants
    'Available when #define VT_USE_SORT is placed
    'before #include once "vt/vt.bi".
    '
    ':params
    Const VT_ASCENDING  = 0
    '    Sort direction: smallest value first.
    Const VT_DESCENDING = 1
    '    Sort direction: largest value first.
    ':see
    'vt_sort
    '<<<

    ' ----------------------------------------------------------------
    '  SHELLSORT_VAL - direct value comparison (ASC or DESC)
    '  variables suffixed _ to avoid shadowing caller-side names
    ' ----------------------------------------------------------------
    #Macro SHELLSORT_VAL(arr, order, T)
        dim as long lo_  = lbound(arr)
        dim as long hi_  = ubound(arr)
        dim as long gap_ = (hi_ - lo_ + 1) \ 2
        dim as long i_, j_
        dim as T    tmp_
    
        while gap_ > 0
            for i_ = lo_ + gap_ to hi_
                tmp_ = arr(i_)
                j_   = i_
                if order = VT_ASCENDING then
                    while j_ >= lo_ + gap_ andalso arr(j_ - gap_) > tmp_
                        arr(j_) = arr(j_ - gap_)
                        j_ -= gap_
                    wend
                else
                    while j_ >= lo_ + gap_ andalso arr(j_ - gap_) < tmp_
                        arr(j_) = arr(j_ - gap_)
                        j_ -= gap_
                    wend
                end if
                arr(j_) = tmp_
            next i_
            gap_ \= 2
        wend
    #Endmacro
    
    ' ----------------------------------------------------------------
    '  SHELLSORT_CMP - comparator callback variant
    '  cmp(a, b): return < 0  ?  a belongs before b
    '             return   0  ?  equal
    '             return > 0  ?  b belongs before a  (swap)
    ' ----------------------------------------------------------------
    #Macro SHELLSORT_CMP(arr, cmp, T)
        dim as long lo_  = lbound(arr)
        dim as long hi_  = ubound(arr)
        dim as long gap_ = (hi_ - lo_ + 1) \ 2
        dim as long i_, j_
        dim as T    tmp_
    
        while gap_ > 0
            for i_ = lo_ + gap_ to hi_
                tmp_ = arr(i_)
                j_   = i_
                while j_ >= lo_ + gap_ andalso cmp(arr(j_ - gap_), tmp_) > 0
                    arr(j_) = arr(j_ - gap_)
                    j_ -= gap_
                wend
                arr(j_) = tmp_
            next i_
            gap_ \= 2
        wend
    #Endmacro
    
    ' ================================================================
    '  vt_sort - VT_ASCENDING / VT_DESCENDING overloads
    ' ================================================================
    
    sub vt_sort overload (arr() as byte, order as long)
        SHELLSORT_VAL(arr, order, byte)
    end sub
    
    sub vt_sort overload (arr() as ubyte, order as long)
        SHELLSORT_VAL(arr, order, ubyte)
    end sub
    
    sub vt_sort overload (arr() as short, order as long)
        SHELLSORT_VAL(arr, order, short)
    end sub
    
    sub vt_sort overload (arr() as ushort, order as long)
        SHELLSORT_VAL(arr, order, ushort)
    end sub
    
    sub vt_sort overload (arr() as long, order as long)
        SHELLSORT_VAL(arr, order, long)
    end sub
    
    sub vt_sort overload (arr() as ulong, order as long)
        SHELLSORT_VAL(arr, order, ulong)
    end sub
    
    sub vt_sort overload (arr() as longint, order as long)
        SHELLSORT_VAL(arr, order, longint)
    end sub
    
    sub vt_sort overload (arr() as ulongint, order as long)
        SHELLSORT_VAL(arr, order, ulongint)
    end sub
    
    sub vt_sort overload (arr() as single, order as long)
        SHELLSORT_VAL(arr, order, single)
    end sub
    
    sub vt_sort overload (arr() as double, order as long)
        SHELLSORT_VAL(arr, order, double)
    end sub
    
    sub vt_sort overload (arr() as string, order as long)
        SHELLSORT_VAL(arr, order, string)
    end sub
    
    #Undef SHELLSORT_VAL
    
    ' ================================================================
    '  vt_sort - comparator callback overloads
    '  the comparator defines the order; no separate order parameter
    ' ================================================================
    
    sub vt_sort overload (arr() as byte, cmp as function(as byte, as byte) as long)
        SHELLSORT_CMP(arr, cmp, byte)
    end sub
    
    sub vt_sort overload (arr() as ubyte, cmp as function(as ubyte, as ubyte) as long)
        SHELLSORT_CMP(arr, cmp, ubyte)
    end sub
    
    sub vt_sort overload (arr() as short, cmp as function(as short, as short) as long)
        SHELLSORT_CMP(arr, cmp, short)
    end sub
    
    sub vt_sort overload (arr() as ushort, cmp as function(as ushort, as ushort) as long)
        SHELLSORT_CMP(arr, cmp, ushort)
    end sub
    
    sub vt_sort overload (arr() as long, cmp as function(as long, as long) as long)
        SHELLSORT_CMP(arr, cmp, long)
    end sub
    
    sub vt_sort overload (arr() as ulong, cmp as function(as ulong, as ulong) as long)
        SHELLSORT_CMP(arr, cmp, ulong)
    end sub
    
    sub vt_sort overload (arr() as longint, cmp as function(as longint, as longint) as long)
        SHELLSORT_CMP(arr, cmp, longint)
    end sub
    
    sub vt_sort overload (arr() as ulongint, cmp as function(as ulongint, as ulongint) as long)
        SHELLSORT_CMP(arr, cmp, ulongint)
    end sub
    
    sub vt_sort overload (arr() as single, cmp as function(as single, as single) as long)
        SHELLSORT_CMP(arr, cmp, single)
    end sub
    
    sub vt_sort overload (arr() as double, cmp as function(as double, as double) as long)
        SHELLSORT_CMP(arr, cmp, double)
    end sub
    
    sub vt_sort overload (arr() as string, cmp as function(as string, as string) as long)
        SHELLSORT_CMP(arr, cmp, string)
    end sub
    
    #Undef SHELLSORT_CMP
    
    ' ================================================================
    '  vt_sort_apply - apply a permutation index to a typed array
    '
    '  companion to the index-sort pattern: build a Long index array,
    '  sort it via vt_sort() with a comparator, then call vt_sort_apply
    '  on every parallel array to physically rearrange their elements.
    '
    '  pidx() values are 0-based offsets from lbound(arr).
    '  this matches the natural index array built as {0, 1, 2, ...}
    '  and sorted by vt_sort.
    ' ================================================================
    
    #Macro APPLY_PERM(arr, pidx, T)
        dim as long n_   = ubound(pidx) - lbound(pidx) + 1
        dim as long alo_ = lbound(arr)
        dim as long i_
        dim tmp_() as T
        redim tmp_(0 to n_ - 1)
        for i_ = 0 to n_ - 1
            tmp_(i_) = arr(alo_ + i_)
        next i_
        for i_ = 0 to n_ - 1
            arr(alo_ + i_) = tmp_(pidx(lbound(pidx) + i_))
        next i_
    #Endmacro
    
    sub vt_sort_apply overload (arr() as byte,     pidx() as long)
        APPLY_PERM(arr, pidx, byte)
    end sub
    
    sub vt_sort_apply overload (arr() as ubyte,    pidx() as long)
        APPLY_PERM(arr, pidx, ubyte)
    end sub
    
    sub vt_sort_apply overload (arr() as short,    pidx() as long)
        APPLY_PERM(arr, pidx, short)
    end sub
    
    sub vt_sort_apply overload (arr() as ushort,   pidx() as long)
        APPLY_PERM(arr, pidx, ushort)
    end sub
    
    sub vt_sort_apply overload (arr() as long,     pidx() as long)
        APPLY_PERM(arr, pidx, long)
    end sub
    
    sub vt_sort_apply overload (arr() as ulong,    pidx() as long)
        APPLY_PERM(arr, pidx, ulong)
    end sub
    
    sub vt_sort_apply overload (arr() as longint,  pidx() as long)
        APPLY_PERM(arr, pidx, longint)
    end sub
    
    sub vt_sort_apply overload (arr() as ulongint, pidx() as long)
        APPLY_PERM(arr, pidx, ulongint)
    end sub
    
    sub vt_sort_apply overload (arr() as single,   pidx() as long)
        APPLY_PERM(arr, pidx, single)
    end sub
    
    sub vt_sort_apply overload (arr() as double,   pidx() as long)
        APPLY_PERM(arr, pidx, double)
    end sub
    
    sub vt_sort_apply overload (arr() as string,   pidx() as long)
        APPLY_PERM(arr, pidx, string)
    end sub
    
    #Undef APPLY_PERM
    
    ' ================================================================
    '  vt_sort_shuffle - Fisher-Yates in-place shuffle
    '  seeding the RNG with Randomize is the caller's responsibility.
    '  swap is type-agnostic in FreeBASIC so T is not needed here.
    ' ================================================================
    
    #Macro FISHER_YATES(arr)
        dim as long i_, j_
        for i_ = ubound(arr) to lbound(arr) + 1 step -1
            j_ = lbound(arr) + int(rnd * (i_ - lbound(arr) + 1))
            swap arr(i_), arr(j_)
        next i_
    #Endmacro
    
    sub vt_sort_shuffle overload (arr() as byte)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as ubyte)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as short)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as ushort)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as long)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as ulong)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as longint)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as ulongint)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as single)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as double)
        FISHER_YATES(arr)
    end sub
    
    sub vt_sort_shuffle overload (arr() as string)
        FISHER_YATES(arr)
    end sub
    
    #Undef FISHER_YATES
#Endif 'VT_USE_SORT

'>>>
    ':topic vt_sort
    ':short Generic in-place array sort (opt-in)
    ':group Sort
    'Sort a 1D array in-place using Shellsort.
    'Overloaded for all numeric types and String.
    'The compiler selects the correct overload --
    'a single call form works for every supported
    'type. Arrays with any LBound are handled.
    '
    'NOTE: ZString * N is not supported. Store data
    'as String for sorting. See vt_sort_apply for
    'the index-sort pattern with ZString arrays.
    '
    'Two call forms:
    '  Form 1: direction constant (VT_ASCENDING or
    '  VT_DESCENDING). Form 2: comparator callback.
    '
    'The comparator returns negative if a comes
    'first, zero if equal, positive if b comes first.
    'To sort descending via a comparator, flip the
    'return sign.
    ':syntax
    'Sub vt_sort(arr() As <T>, order As Long)
    '
    'Sub vt_sort(arr() As <T>, _
    '            cmp As Function(As <T>, As <T>) _
    '                           As Long)
    ':params
    'arr()  1D array to sort in-place.
    'order  VT_ASCENDING (0) or VT_DESCENDING (1).
    'cmp    Comparator callback. Pass with @.
    ':example
    '#Define VT_USE_SORT
    'Dim nums(4) As Long = {5, 1, 4, 2, 3}
    'vt_sort(nums(), VT_ASCENDING)
    '
    'Dim words(2) As String = {"c", "a", "b"}
    'vt_sort(words(), VT_ASCENDING)
    '
    '' Custom comparator:
    'Function cmp_len(a As String, b As String) _
    '                 As Long
    '    Return Len(a) - Len(b)
    'End Function
    'Dim tags(2) As String = {"hi", "hello", "hey"}
    'vt_sort(tags(), @cmp_len)
    ':see
    'vt_sort_apply
    'vt_sort_shuffle
    'c_sortconsts
'<<<

'>>>
    ':topic vt_sort_apply
    ':short Apply a permutation index to an array
    ':group Sort
    'Apply a permutation index to a 1D array,
    'physically rearranging its elements in-place.
    'This is the companion to the index-sort pattern
    'for sorting tables stored as parallel arrays.
    '
    'pidx() values are 0-based offsets from
    'LBound(arr), matching the index arrays built
    'and sorted by vt_sort. The permutation index is
    'consumed by the apply step -- build a fresh
    'index array to apply the same order elsewhere.
    'Overloaded for the same types as vt_sort.
    '
    'Index-sort pattern (three steps):
    '  1. Build a Long index array {0, 1, 2, ...}
    '  2. Sort the index array with a comparator
    '     that reads real data via index values.
    '  3. Either read in index order (non-destructive)
    '     or call vt_sort_apply on each parallel array.
    ':syntax
    'Sub vt_sort_apply(arr()  As <T>, _
    '                  pidx() As Long)
    ':params
    'arr()   Array to rearrange in-place.
    'pidx()  Permutation index. Values are 0-based
    '        offsets into arr.
    ':example
    '#Define VT_USE_SORT
    'Dim Shared g_item(3) As String
    'Dim Shared g_qty (3) As Long
    'g_item(0) = "eggs"   : g_qty(0) = 5
    'g_item(1) = "butter" : g_qty(1) = 2
    'g_item(2) = "milk"   : g_qty(2) = 10
    'g_item(3) = "bread"  : g_qty(3) = 3
    '
    'Function cmp_qty(a As Long, b As Long) As Long
    '    Return g_qty(a) - g_qty(b)
    'End Function
    '
    'Dim idx(3) As Long
    'Dim i As Long
    'For i = 0 To 3 : idx(i) = i : Next i
    'vt_sort(idx(), @cmp_qty)
    '
    'vt_sort_apply(g_item(), idx())
    'vt_sort_apply(g_qty(),  idx())
    ':see
    'vt_sort
    'vt_sort_shuffle
'<<<

'>>>
    ':topic vt_sort_shuffle
    ':short Fisher-Yates in-place array shuffle
    ':group Sort
    'Shuffle a 1D array in-place using the
    'Fisher-Yates algorithm, producing an unbiased
    'uniform random permutation. Seeding the RNG
    'with Randomize is the caller's responsibility.
    'Overloaded for the same types as vt_sort.
    ':syntax
    'Sub vt_sort_shuffle(arr() As <T>)
    ':params
    'arr()  1D array to shuffle in-place.
    ':example
    '#Define VT_USE_SORT
    'Randomize
    'Dim deck(51) As Long
    'Dim i As Long
    'For i = 0 To 51 : deck(i) = i : Next i
    'vt_sort_shuffle(deck())
    '
    'Dim names(3) As String = _
    '    {"Alice", "Bob", "Carol", "Dave"}
    'vt_sort_shuffle(names())
    ':see
    'vt_sort
    'vt_rnd
'<<<
