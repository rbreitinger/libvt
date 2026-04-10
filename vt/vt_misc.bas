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

' ================================================================
'  vt_sort  –  generic array sort via overloading (shellsort)
' ================================================================

' ----------------------------------------------------------------
'  SHELLSORT_VAL  –  direct value comparison (ASC or DESC)
'  variables suffixed _ to avoid shadowing caller-side names
' ----------------------------------------------------------------
#macro SHELLSORT_VAL(arr, order, T)
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
#endmacro

' ----------------------------------------------------------------
'  SHELLSORT_CMP  –  comparator callback variant
'  cmp(a, b): return < 0  ?  a belongs before b
'             return   0  ?  equal
'             return > 0  ?  b belongs before a  (swap)
' ----------------------------------------------------------------
#macro SHELLSORT_CMP(arr, cmp, T)
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
#endmacro

' ================================================================
'  vt_sort  –  VT_ASCENDING / VT_DESCENDING overloads
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
'  vt_sort  –  comparator callback overloads
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
'  vt_sort_apply  --  apply a permutation index to a typed array
'
'  companion to the index-sort pattern: build a Long index array,
'  sort it via vt_sort() with a comparator, then call vt_sort_apply
'  on every parallel array to physically rearrange their elements.
'
'  pidx() values are 0-based offsets from lbound(arr).
'  this matches the natural index array built as {0, 1, 2, ...}
'  and sorted by vt_sort.
' ================================================================

#macro APPLY_PERM(arr, pidx, T)
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
#endmacro

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

#undef APPLY_PERM

' ================================================================
'  vt_sort_shuffle  --  Fisher-Yates in-place shuffle
'  seeding the RNG with Randomize is the caller's responsibility.
'  swap is type-agnostic in FreeBASIC so T is not needed here.
' ================================================================

#macro FISHER_YATES(arr)
    dim as long i_, j_
    for i_ = ubound(arr) to lbound(arr) + 1 step -1
        j_ = lbound(arr) + int(rnd * (i_ - lbound(arr) + 1))
        swap arr(i_), arr(j_)
    next i_
#endmacro

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

#undef FISHER_YATES
