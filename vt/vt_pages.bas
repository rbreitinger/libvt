' =============================================================================
' vt_pages.bas - VT Page Management and Scrollback                             
' =============================================================================

' we use crt for memcpy since it is available on windows AND linux
#Include Once "crt/mem.bi"

'>>>
    ':topic vt_page
    ':short Set the active draw and display page
    ':group Pages
    'Set the active drawing page and the visible display page independently. All drawing commands
    'write to the work page; vt_present reads from the vis page. Multiple pages are allocated at
    'vt_screen time via the pages argument (up to 8 pages, indices 0-7). Page 0 (VT_VIDEO) is always
    'the startup visible page. Invalid indices are silently ignored.
':syntax
Sub vt_page(work As Long, vis As Long)
        ':params
        'work  Drawing page index (0 <= work < pages).
        '      All drawing commands go here.
        'vis   Display page index (0 <= vis < pages).
        '      This page is shown by vt_present.
        ':example
        '' Classic double-buffer: draw on page 1:
        'vt_page(1, VT_VIDEO)
        '' ... draw on page 1 freely ...
        'vt_pcopy(1, VT_VIDEO)
        'vt_present()
        '' Swap back:
        'vt_page(VT_VIDEO, VT_VIDEO)
        ':see
        'vt_pcopy
        'vt_present
        'vt_screen
    '<<<
    If vt_internal.ready  = 0 Then Exit Sub
    If work < 0 Or work  >= vt_internal.num_pages Then Exit Sub
    If vis  < 0 Or vis   >= vt_internal.num_pages Then Exit Sub
    vt_internal.work_page = work
    vt_internal.vis_page  = vis
    vt_internal.cells     = vt_internal.page_buf(work)
    vt_internal.dirty     = 1
End Sub

'>>>
    ':topic vt_pcopy
    ':short Copy one page buffer to another
    ':group Pages
    'Copy one page buffer to another (equivalent to QBasic PCOPY). Marks the display dirty but does
    'not call vt_present. src = dst is a no-op. Invalid indices are silently ignored.
':syntax
Sub vt_pcopy(src As Long, dst As Long)
        ':params
        'src  Source page index.
        'dst  Destination page index.
        ':see
        'vt_page
        'vt_present
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    If src < 0 Or src   >= vt_internal.num_pages Then Exit Sub
    If dst < 0 Or dst   >= vt_internal.num_pages Then Exit Sub
    If src               = dst Then Exit Sub
    
    Dim buf_sz As Long   = vt_internal.scr_cols * vt_internal.scr_rows * SizeOf(vt_cell)
    memcpy(vt_internal.page_buf(dst), vt_internal.page_buf(src), buf_sz)
    vt_internal.dirty = 1
End Sub

'>>>
    ':topic vt_scroll
    ':short Move the scrollback view by a number of lines
    ':group Scroll
    'Move the scrollback view offset. Positive values scroll toward older history; negative values
    'scroll toward the live view. Scrollback buffer size must be set with vt_scrollback and it must 
    'be enabled by vt_scroll_enable(1) first. Does not call vt_present. vt_scroll is called automatically
    'by the library for the built-in hotkeys -- you only need to call it directly for custom input such as a mouse wheel handler.
':syntax
Function vt_scroll(amount As Long) As Byte
        ':params
        'amount  Lines to scroll. Positive = back in
        '        history, negative = toward live view.
        '        Clamped to valid range automatically.
        ':notes
        'Return values:
        '  1  Offset changed.
        '  0  Already at limit, amount is zero, or
        '     scrollback is disabled.
        ':see
        'vt_scroll_enable
        'vt_scrollback
        'hk_scrollback
    '<<<
    If vt_internal.ready    = 0 Then Return 0
    If vt_internal.sb_lines = 0 Then Return 0
    If amount               = 0 Then Return 0

    Dim prev As Long = vt_internal.sb_offset

    vt_internal.sb_offset += amount
    If vt_internal.sb_offset > vt_internal.sb_used Then vt_internal.sb_offset = vt_internal.sb_used
    If vt_internal.sb_offset < 0                   Then vt_internal.sb_offset = 0
    If vt_internal.sb_offset = prev                Then Return 0

    vt_internal.dirty = 1
    Return 1
End Function

'>>>
    ':topic vt_scrollback
    ':short Allocate or resize the scrollback buffer
    ':group Initialization
    'Allocate, resize, or disable the scrollback history buffer. Must be called after vt_screen.
    'Calling it again clears any existing history. Scrollback captures lines scrolled off the top
    'of the scroll region. See the Hotkeys section for the key bindings that activate scrollback.
':syntax
Sub vt_scrollback(lines As Long)
        ':params
        'lines  History lines to keep. Pass 0 to
        '       disable scrollback and free the buffer.
        ':see
        'vt_screen
        'vt_scroll
        'hk_scrollback
        'vt_scroll_enable
    '<<<
    If vt_internal.ready = 0 Then Exit Sub
    If vt_internal.sb_cells <> 0 Then
        DeAllocate vt_internal.sb_cells
        vt_internal.sb_cells = 0
    End If
    vt_internal.sb_lines  = lines
    vt_internal.sb_used   = 0
    vt_internal.sb_offset = 0
    If lines >= 0 Then
        vt_internal.sb_cells = CAllocate(lines * vt_internal.scr_cols, SizeOf(vt_cell))
    End If
End Sub
