# VT -- Virtual Text Screen Library for FreeBASIC

A self-contained FreeBASIC library that gives you a proper DOS-style text screen
in a real SDL2 window. Drop-in replacement for `Screen 0` and the Windows CMD console --
with the things that always should have worked: real blinking text, correct CP437
characters, scrollback history, fullscreen with integer scaling, and reliable key input.

Zero SDL2 knowledge required. One include, and you write code that feels like QBasic.

```freebasic
#include once "vt/vt.bi"

vt_title "My Program"
vt_screen VT_SCREEN_0
vt_color VT_YELLOW, VT_BLUE
vt_print_center 12, "Hello, World!"
vt_sleep
vt_shutdown
```

window closing handles shutdown. 

---

## Requirements

- **FreeBASIC 1.10.1** (Windows)
- **SDL2.dll** -- ships with FreeBASIC, or get it from the
  [FreeBASIC library archive](https://github.com/rbreitinger/fb-lib-archive/tree/main/libraries/SDL2/SDL2-2.0.14)

No other dependencies. All three CP437 fonts are embedded -- no external files needed.

---

## Screen Modes

| Constant            | Cols x Rows | Font  | Canvas   | Original                  |
|---------------------|-------------|-------|----------|---------------------------|
| `VT_SCREEN_0`       | 80 x 25     | 8x16  | 640x400  | VGA text mode (default)   |
| `VT_SCREEN_2`       | 80 x 25     | 8x8   | 640x200  | CGA hi-res text grid      |
| `VT_SCREEN_9`       | 80 x 25     | 8x14  | 640x350  | EGA text grid             |
| `VT_SCREEN_12`      | 80 x 30     | 8x16  | 640x480  | VGA hi-res text grid      |
| `VT_SCREEN_13`      | 40 x 25     | 8x8   | 320x200  | VGA Mode 13h text grid    |
| `VT_SCREEN_EGA43`   | 80 x 43     | 8x8   | 640x344  | EGA 43-line               |
| `VT_SCREEN_VGA50`   | 80 x 50     | 8x8   | 640x400  | VGA 50-line               |
| `VT_SCREEN_TILES`   | 40 x 25     | 16x16 | 640x400  | Square tiles, game use    |

Mode constants match the original QBasic `SCREEN` numbers where applicable.
`VT_SCREEN_0` is the default when no mode is passed.

---

## Features

- Authentic IBM VGA CP437 fonts -- 8x8, 8x14 and 8x16, all embedded
- Authentic CGA/DOS palette -- not the washed-out modern CMD colours
- Palette manipulation in all screen modes
- Custom Bitmapped Font loading
- All 256 CP437 glyphs -- box drawing, shade blocks, symbols
- Blinking text via `VT_BLINK` attribute
- Scrollback buffer with Shift+PgUp / Shift+PgDn (call `vt_scrollback(n)` after `vt_screen`)
- Windowed or fullscreen with integer scaling and nearest-neighbor rendering
- Buffered key input via `vt_inkey` -- nothing missed, nothing floods
- Real-time key state via `vt_key_held` -- for game loops
- `vt_view_print` scroll regions -- fixed status bars, split screen layouts
- `VT_NEWLINE` constant for readable line breaks in print chains
- `vt_input` blocking line editor
- Mouse support
- BLOAD / BSAVE equivalents (*.vts)
- Up to 7 working pages and visible Screen Page -- PCOPY equivalent
- copy/paste enabled/disabled/ by mouse and/or keyboard

---

## Init

```freebasic
vt_title("Window Title")   ' optional, call before vt_screen
vt_screen(VT_SCREEN_0)     ' open the screen, VT_WINDOWED is default flag
vt_scrollback(200)         ' optional, call after vt_screen
```

To change mode mid-program, call `vt_screen` again -- it closes and reopens cleanly.

---

## Status

Core rendering, input, scrollback and scroll regions are complete and tested.
The API is still evolving -- breaking changes are possible until a 1.0 tag is made.

---

## License

MIT License
Copyright (c) 2026 Rene Breitinger (yorokobi)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
