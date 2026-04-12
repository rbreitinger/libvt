' ================================================================
'  ex_sort.bas  --  vt_sort family demonstration
'  shows: direction sort, comparator sort, shuffle, apply_perm,
'         and the index-sort trick for sorting parallel arrays
'         ("2D table" pattern)
' ================================================================
#Define VT_USE_SORT
#Include Once "../vt/vt.bi"

' ----------------------------------------------------------------
'  shared table data for the index-sort demo (4 items, idx 0..3)
'  stored as parallel arrays -- the most common real-world layout.
'  note: shared var-len string arrays cannot use inline initializers
'  in FreeBASIC; assign elements individually after declaration.
' ----------------------------------------------------------------
const TROWS = 3   ' ubound -- 4 rows total (0..TROWS)

dim shared g_item(TROWS) as string
dim shared g_qty (TROWS) as long

g_item(0) = "eggs"   : g_qty(0) = 5
g_item(1) = "butter" : g_qty(1) = 2
g_item(2) = "milk"   : g_qty(2) = 10
g_item(3) = "bread"  : g_qty(3) = 3

' ----------------------------------------------------------------
'  custom comparators -- plain sort
' ----------------------------------------------------------------

' sort strings by character count (shortest first)
function cmp_by_length(a as string, b as string) as long
    return len(a) - len(b)
end function

' sort longs by absolute value (smallest first)
function cmp_abs(a as long, b as long) as long
    if abs(a) < abs(b) then return -1
    if abs(a) > abs(b) then return  1
    return 0
end function

' ----------------------------------------------------------------
'  index comparators -- peek into shared table via index value
' ----------------------------------------------------------------

function cmp_idx_qty(a as long, b as long) as long
    return g_qty(a) - g_qty(b)
end function

function cmp_idx_name(a as long, b as long) as long
    if g_item(a) < g_item(b) then return -1
    if g_item(a) > g_item(b) then return  1
    return 0
end function

' ----------------------------------------------------------------
'  display helpers
' ----------------------------------------------------------------

sub show_longs(arr() as long)
    dim as long i
    for i = lbound(arr) to ubound(arr)
        vt_print str(arr(i))
        if i < ubound(arr) then vt_print ",  "
    next i
end sub

sub show_strings(arr() as string)
    dim as long i
    for i = lbound(arr) to ubound(arr)
        vt_print arr(i)
        if i < ubound(arr) then vt_print ",  "
    next i
end sub

' print one table row: item at col, qty at col+10
sub show_row(nm as string, qty as long, col as long, row_ as long)
    vt_locate row_, col
    vt_color VT_WHITE, VT_BLACK  : vt_print nm
    vt_locate row_, col + 10
    vt_color VT_YELLOW, VT_BLACK : vt_print str(qty)
end sub

' ================================================================
'  screen 1 -- basic sorts + shuffle
' ================================================================

Randomize

vt_title "vt_sort -- example"
vt_screen VT_SCREEN_0   ' 80x25, 8x16

vt_color VT_WHITE, VT_BLUE
vt_print_center 1, " vt_sort / vt_sort_apply / vt_sort_shuffle "
vt_color VT_LIGHT_GREY, VT_BLACK

' ---- direction sort: Long ------------------------------------
dim as long nums(7) = {42, -7, 100, 3, -50, 18, 0, 77}

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 3, 2 : vt_print "-- direction sort (Long) --"
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 4, 4 : vt_print "ASC  : "
vt_sort(nums(), VT_ASCENDING)
vt_color VT_WHITE, VT_BLACK : show_longs(nums())
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 5, 4 : vt_print "DESC : "
vt_sort(nums(), VT_DESCENDING)
vt_color VT_WHITE, VT_BLACK : show_longs(nums())

' ---- direction sort: String ----------------------------------
dim as string words(5) = {"banana", "apple", "cherry", "date", "elderberry", "fig"}

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 7, 2 : vt_print "-- direction sort (String) --"
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 8, 4 : vt_print "ASC  : "
vt_sort(words(), VT_ASCENDING)
vt_color VT_WHITE, VT_BLACK : show_strings(words())
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 9, 4 : vt_print "DESC : "
vt_sort(words(), VT_DESCENDING)
vt_color VT_WHITE, VT_BLACK : show_strings(words())

' ---- comparator sort -----------------------------------------
dim as string tagwords(5) = {"banana", "apple", "cherry", "date", "elderberry", "fig"}
dim as long   absnums(5)  = {-30, 4, -100, 7, 50, -1}

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 11, 2 : vt_print "-- comparator sort --"
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 12, 4 : vt_print "String by char count : "
vt_sort(tagwords(), @cmp_by_length)
vt_color VT_WHITE, VT_BLACK : show_strings(tagwords())
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 13, 4 : vt_print "Long by abs value    : "
vt_sort(absnums(), @cmp_abs)
vt_color VT_WHITE, VT_BLACK : show_longs(absnums())

' ---- shuffle -------------------------------------------------
dim as long deck(7) = {1, 2, 3, 4, 5, 6, 7, 8}

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 15, 2 : vt_print "-- shuffle (Fisher-Yates) --"
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 16, 4 : vt_print "before : "
vt_color VT_WHITE, VT_BLACK : show_longs(deck())
vt_sort_shuffle(deck())
vt_color VT_BRIGHT_CYAN, VT_BLACK
vt_locate 17, 4 : vt_print "after  : "
vt_color VT_WHITE, VT_BLACK : show_longs(deck())

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 23, 2 : vt_print "Next: sorting a table (parallel arrays + index trick)"
vt_color VT_LIGHT_GREY, VT_BLACK
vt_locate 25, 2 : vt_print "Press any key..."
vt_sleep 0

' ================================================================
'  screen 2 -- index-sort pattern (80x25)
'
'  2-column layout, left col 2..40, right col 42..79
'
'  row  1  header
'  row  3  "original table:"         | "sorted by qty (asc):"
'  rows 4-7  original data           | sorted-by-qty data
'  row  9  "the index-sort pattern:" | "sorted by name (asc):"
'  rows 10-13  step explanations     | sorted-by-name data
'  row 16  "after vt_sort_apply..."
'  rows 17-20  physically sorted data
'  row 25  press any key
' ================================================================

vt_cls
vt_color VT_WHITE, VT_BLUE
vt_print_center 1, " index-sort trick -- sorting parallel arrays "
vt_color VT_LIGHT_GREY, VT_BLACK

dim as long i

' ---- original table (left col 4, rows 3-7) -------------------
vt_color VT_DARK_GREY, VT_BLACK
vt_locate 3, 2 : vt_print "original table:"
for i = 0 to TROWS
    show_row(g_item(i), g_qty(i), 4, 4 + i)
next i

' ---- sorted by qty (right col 42, rows 3-7) ------------------
vt_color VT_DARK_GREY, VT_BLACK
vt_locate 3, 42 : vt_print "sorted by qty (asc):"

dim idx_qty(TROWS) as long
for i = 0 to TROWS : idx_qty(i) = i : next i
vt_sort(idx_qty(), @cmp_idx_qty)

for i = 0 to TROWS
    show_row(g_item(idx_qty(i)), g_qty(idx_qty(i)), 42, 4 + i)
next i

' ---- step explanation ----------------
vt_color VT_DARK_GREY, VT_BLACK
vt_locate 9, 2 : vt_print "the index-sort pattern:"

vt_color VT_BRIGHT_CYAN, VT_BLACK : vt_locate 10, 2 : vt_print "1."
vt_color VT_LIGHT_GREY, VT_BLACK  : vt_locate 10, 5 : vt_print "build idx() = {0, 1, 2, ...}"

vt_color VT_BRIGHT_CYAN, VT_BLACK : vt_locate 11, 2 : vt_print "2."
vt_color VT_LIGHT_GREY, VT_BLACK  : vt_locate 11, 5 : vt_print "vt_sort(idx(), @cmp)"

vt_color VT_LIGHT_GREY, VT_BLACK
vt_locate 12, 5 : vt_print "cmp reads shared data via idx"

vt_color VT_BRIGHT_CYAN, VT_BLACK : vt_locate 13, 2 : vt_print "3a."
vt_color VT_LIGHT_GREY, VT_BLACK  : vt_locate 13, 6 : vt_print "read arr(idx(i)) -- view only"

vt_color VT_BRIGHT_CYAN, VT_BLACK : vt_locate 14, 2 : vt_print "3b."
vt_color VT_LIGHT_GREY, VT_BLACK  : vt_locate 14, 6 : vt_print "vt_sort_apply(arr(), idx())"

' ---- sorted by name ----------------
vt_color VT_DARK_GREY, VT_BLACK
vt_locate 9, 42 : vt_print "sorted by name (asc):"

dim idx_name(TROWS) as long
for i = 0 to TROWS : idx_name(i) = i : next i
vt_sort(idx_name(), @cmp_idx_name)

for i = 0 to TROWS
    show_row(g_item(idx_name(i)), g_qty(idx_name(i)), 42, 10 + i)
next i

' ---- after vt_sort_apply ------------
' physically rearranges both parallel arrays using the qty index.
' idx_qty is consumed by apply -- rebuild if further use is needed.
vt_sort_apply(g_item(), idx_qty())
vt_sort_apply(g_qty(),  idx_qty())

vt_color VT_DARK_GREY, VT_BLACK
vt_locate 16, 2 : vt_print "after vt_sort_apply -- physically sorted by qty:"
for i = 0 to TROWS
    show_row(g_item(i), g_qty(i), 4, 17 + i)
next i

' ---- footer --------------------------------------------------
vt_color VT_LIGHT_GREY, VT_BLACK
vt_locate 25, 2 : vt_print "Press any key to exit..."
vt_sleep 0
vt_shutdown()
