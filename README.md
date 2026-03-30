# VT — Virtual Text Screen Library for FreeBASIC

A self-contained FreeBASIC library that gives you a proper DOS-style text screen
in a real SDL2 window. Drop-in replacement for `Screen 0` and the Windows CMD console —
with the things that always should have worked: real blinking text, correct CP437
characters, scrollback history, fullscreen with integer scaling, and reliable key input.

Zero SDL2 knowledge required. One include, and you write code that feels like QBasic.

```freebasic
#include once "vt/vt.bi"

vt_init(VT_MODE_80x25)
vt_color(VT_YELLOW, VT_BLUE)
vt_print_center(12, "Hello, World!")
vt_present()
vt_sleep()
vt_shutdown()
```

---

## Requirements

- **FreeBASIC 1.10.1** (Windows)
- **SDL2.dll** — can grab from my library archive: https://github.com/rbreitinger/fb-lib-archive/tree/main/libraries/SDL2/SDL2-2.0.14 )

No other dependencies. The CP437 font is embedded — no external font files needed.

---

## Features

- Classic 80x25 and other DOS screen modes, or any custom grid size
- Authentic CGA/DOS palette — not the washed-out modern CMD colours
- CP437 character set — box drawing, shade blocks, all 256 glyphs
- Blinking text via `VT_BLINK` attribute
- Scrollback buffer with Shift+PgUp / Shift+PgDn
- Windowed or fullscreen with integer scaling and nearest-neighbor rendering
- Resizable window that snaps to cell grid — no blurry scaling ever
- Buffered key input via `vt_inkey` — nothing missed, nothing floods
- Real-time key state via `vt_key_held` — for game loops
- `vt_view_print` scroll regions — fixed status bars, split screen layouts
- Page save / restore — PCOPY equivalent *(coming soon)*
- Mouse support *(coming soon)*

---

## Status

Early but functional. Core rendering, input, scrollback and scroll regions are
complete and tested. The API is still evolving — breaking changes are possible
until a 1.0 tag is made.

---

## License

MIT License
Copyright (c) 2025 René Breitinger (yorokobi)

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
