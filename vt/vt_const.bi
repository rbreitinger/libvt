' =============================================================================
' vt_const.bi - VT Virtual Text Screen Library
' All public constants, key codes, palette defaults, and internal tuning values.
' Include via vt.bi only - use: #include once "vt/vt.bi"
' =============================================================================


' -----------------------------------------------------------------------------
' Init flags  (combinable with Or)
' -----------------------------------------------------------------------------
Const VT_WINDOWED           = 1    ' start in a resizable window (default)
Const VT_FULLSCREEN_ASPECT  = 2    ' fullscreen, integer-scaled, black bars to keep ratio
Const VT_FULLSCREEN_STRETCH = 4    ' fullscreen, fills entire display (widescreen feel)
Const VT_NO_RESIZE          = 8    ' prevent manual window resize
Const VT_VSYNC              = 16   ' opt-in vsync (locks vt_present to monitor refresh).
                                   ' off by default - use in game loops, not text output.


' -----------------------------------------------------------------------------
' Screen mode constants  (shorthand for well-known DOS configurations)
' Passed as first argument to vt_init() instead of explicit cols/rows.
' -----------------------------------------------------------------------------
Const VT_MODE_80x25 = 1   ' 8x16 glyphs - classic DOS, the default
Const VT_MODE_80x43 = 2   ' 8x8  glyphs - EGA 43-line
Const VT_MODE_80x50 = 3   ' 8x8  glyphs - VGA 50-line
Const VT_MODE_40x25 = 4   ' 16x16 glyphs - wide / chunky


' -----------------------------------------------------------------------------
' Sentinel value
' -----------------------------------------------------------------------------
Const VT_CENTER = -1      ' pass to vt_locate row or col to center on that axis


' -----------------------------------------------------------------------------
' Colour constants  (fg 0-15, bg 0-15, add VT_BLINK to fg for blinking)
' Uses the original DOS / CGA palette - NOT modern CMD colours.
' -----------------------------------------------------------------------------
Const VT_BLACK          =  0
Const VT_BLUE           =  1
Const VT_GREEN          =  2
Const VT_CYAN           =  3
Const VT_RED            =  4
Const VT_MAGENTA        =  5
Const VT_BROWN          =  6
Const VT_LIGHT_GREY     =  7
Const VT_DARK_GREY      =  8
Const VT_BRIGHT_BLUE    =  9
Const VT_BRIGHT_GREEN   = 10
Const VT_BRIGHT_CYAN    = 11
Const VT_BRIGHT_RED     = 12
Const VT_BRIGHT_MAGENTA = 13
Const VT_YELLOW         = 14
Const VT_WHITE          = 15
Const VT_BLINK          = 16  ' Or with fg to enable blinking  eg. VT_WHITE Or VT_BLINK


' -----------------------------------------------------------------------------
' vt_inkey return value layout (ULong, 32 bits)
'
'   Bit  0 -  7 : ASCII character  (0 if non-printable or special key)
'   Bit  8 - 15 : reserved
'   Bit 16 - 27 : VT scancode
'   Bit 28      : repeat flag  (1 = key-held auto-repeat event)
'   Bit 29      : Shift held
'   Bit 30      : Ctrl held
'   Bit 31      : Alt held
'
' Extraction macros - use these instead of raw bit math:
' -----------------------------------------------------------------------------
#Define VT_CHAR(k)    ((k) And &hFF)           ' ASCII character, 0 if special
#Define VT_SCAN(k)    (((k) Shr 16) And &hFFF) ' VT scancode
#Define VT_REPEAT(k)  (((k) Shr 28) And 1)     ' 1 if auto-repeat event
#Define VT_SHIFT(k)   (((k) Shr 29) And 1)     ' 1 if Shift was held
#Define VT_CTRL(k)    (((k) Shr 30) And 1)     ' 1 if Ctrl was held
#Define VT_ALT(k)     (((k) Shr 31) And 1)     ' 1 if Alt was held


' -----------------------------------------------------------------------------
' VT key scancode constants  (VT_SCAN(k) values - our own namespace, no SDL exposed)
' -----------------------------------------------------------------------------

' Function keys
Const VT_KEY_F1  = 59
Const VT_KEY_F2  = 60
Const VT_KEY_F3  = 61
Const VT_KEY_F4  = 62
Const VT_KEY_F5  = 63
Const VT_KEY_F6  = 64
Const VT_KEY_F7  = 65
Const VT_KEY_F8  = 66
Const VT_KEY_F9  = 67
Const VT_KEY_F10 = 68
Const VT_KEY_F11 = 133
Const VT_KEY_F12 = 134

' Navigation cluster
Const VT_KEY_UP    = 72
Const VT_KEY_DOWN  = 80
Const VT_KEY_LEFT  = 75
Const VT_KEY_RIGHT = 77
Const VT_KEY_HOME  = 71
Const VT_KEY_END   = 79
Const VT_KEY_PGUP  = 73
Const VT_KEY_PGDN  = 81
Const VT_KEY_INS   = 82
Const VT_KEY_DEL   = 83

' Special keys
Const VT_KEY_ESC   = 1
Const VT_KEY_ENTER = 28
Const VT_KEY_BKSP  = 14
Const VT_KEY_TAB   = 15
Const VT_KEY_SPACE = 57

' Modifier keys (as standalone key events - held-state flags are in VT_SHIFT/CTRL/ALT)
Const VT_KEY_LSHIFT = 42
Const VT_KEY_RSHIFT = 54
Const VT_KEY_LCTRL  = 29
Const VT_KEY_RCTRL  = 157
Const VT_KEY_LALT   = 56
Const VT_KEY_RALT   = 184
Const VT_KEY_LWIN   = 219
Const VT_KEY_RWIN   = 220


' -----------------------------------------------------------------------------
' Default CGA / DOS palette  - 16 colours, 3 bytes each (R, G, B)
' -----------------------------------------------------------------------------
Dim Shared vt_default_palette(47) As UByte = { _
    0,   0,   0,  _ '  0 Black
    0,   0, 170,  _ '  1 Blue
    0, 170,   0,  _ '  2 Green
    0, 170, 170,  _ '  3 Cyan
  170,   0,   0,  _ '  4 Red
  170,   0, 170,  _ '  5 Magenta
  170,  85,   0,  _ '  6 Brown
  170, 170, 170,  _ '  7 Light Grey
   85,  85,  85,  _ '  8 Dark Grey
   85,  85, 255,  _ '  9 Bright Blue
   85, 255,  85,  _ ' 10 Bright Green
   85, 255, 255,  _ ' 11 Bright Cyan
  255,  85,  85,  _ ' 12 Bright Red
  255,  85, 255,  _ ' 13 Bright Magenta
  255, 255,  85,  _ ' 14 Yellow
  255, 255, 255   _ ' 15 White
}


' -----------------------------------------------------------------------------
' Internal tuning constants  (not part of the public API - subject to change)
' -----------------------------------------------------------------------------
Const VT_KEY_BUFFER_SIZE    = 64    ' circular key event buffer capacity (entries)
Const VT_BLINK_MS           = 533   ' blink half-period in ms (~1.875 Hz, matches DOS)
Const VT_PAGE_SLOTS         = 4     ' number of vt_page_save / vt_page_restore slots
Const VT_KEY_REPEAT_INITIAL = 400   ' default initial key-repeat delay in ms
Const VT_KEY_REPEAT_RATE    = 30    ' default repeat interval in ms after initial delay
