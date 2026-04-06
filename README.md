# VT — Virtual Text Screen Library for FreeBASIC

A self-contained library that gives you a proper DOS-style text screen in a real
SDL2 window. One include, no SDL2 knowledge required. Feels like QBasic, works like 2026.

```freebasic
#include once "vt/vt.bi"

vt_title "My Program"
vt_screen VT_SCREEN_0
vt_color VT_YELLOW, VT_BLUE
vt_print_center 12, "Hello, World!"
vt_sleep
vt_shutdown
```

---

## Requirements

- **FreeBASIC 1.10.1**
- **SDL2** — platform-specific, see below

### Windows

Get **SDL2.dll** from the
[FreeBASIC library archive](https://github.com/rbreitinger/fb-lib-archive/tree/main/libraries/SDL2/SDL2-2.0.14)
and place it alongside your compiled executable. If you are running the examples,
`SDL2.dll` must go inside the `examples/` folder, not the project root.

### Linux

Install SDL2 via your package manager — FreeBASIC links against the system library automatically.

```bash
# Debian / Ubuntu
sudo apt install libsdl2-dev

# Fedora
sudo dnf install SDL2-devel

# Arch
sudo pacman -S sdl2
```

No `.so` file needs to be bundled; the user's system provides it.
Primary development and testing is done on Windows. Linux has not been
formally tested, but no Windows-specific code is used — all SDL2 calls,
FreeBASIC built-ins, and file I/O are cross-platform.

---

No other dependencies. All CP437 fonts are embedded — no external files needed.

---

## Installation

Clone or download this repository and copy the `vt` folder into FreeBASIC's `inc`
directory. This makes the library available to any project on your machine without
keeping copies in each project folder.

**Windows** (default FreeBASIC install path):
```
C:\FreeBASIC\inc\vt\
```

**Linux** (typical path):
```
/usr/local/share/freebasic/inc/vt/
```

Then in any source file:
```freebasic
#include once "vt/vt.bi"
```

---

## Distributing programs that use VT

### Shipping an executable

Your compiled `.exe` has no dependency on the VT source files, but it does require
**SDL2.dll** at runtime. Place `SDL2.dll` in the same folder as your executable and
include it in any release archive you distribute.

### Shipping source code

Add a note in your readme that your project depends on libvt and point users to the
repository so they can install it:

```
Requires: libvt — https://github.com/rbreitinger/libvt
```

---

## Screen Modes

| Constant          | Cols × Rows | Font  | Canvas  | Original               |
|-------------------|-------------|-------|---------|------------------------|
| `VT_SCREEN_0`     | 80 × 25     | 8×16  | 640×400 | VGA text (default)     |
| `VT_SCREEN_2`     | 80 × 25     | 8×8   | 640×200 | CGA hi-res             |
| `VT_SCREEN_9`     | 80 × 25     | 8×14  | 640×350 | EGA                    |
| `VT_SCREEN_12`    | 80 × 30     | 8×16  | 640×480 | VGA hi-res             |
| `VT_SCREEN_13`    | 40 × 25     | 8×8   | 320×200 | VGA Mode 13h           |
| `VT_SCREEN_EGA43` | 80 × 43     | 8×8   | 640×344 | EGA 43-line            |
| `VT_SCREEN_VGA50` | 80 × 50     | 8×8   | 640×400 | VGA 50-line            |
| `VT_SCREEN_TILES` | 40 × 25     | 16×16 | 640×400 | Square tiles, game use |

Mode constants match original QBasic `SCREEN` numbers where applicable.

---

## Features

- Authentic IBM CP437 fonts — 8×8, 8×14 and 8×16, all embedded
- Authentic CGA/DOS 16-colour palette with full palette manipulation
- All 256 CP437 glyphs — box drawing, shade blocks, symbols, the works
- Blinking text via `VT_BLINK`
- Windowed, fullscreen, maximized — integer scaling, nearest-neighbour rendering
- Scrollback buffer (`vt_scrollback`) with Shift+PgUp / Shift+PgDn
- Scroll regions — fixed headers, status bars, split-screen layouts
- Buffered key input (`vt_inkey`) and real-time key state (`vt_key_held`)
- Blocking line editor (`vt_input`)
- Mouse support with optional cursor and real-time position/button query
- Keyboard and mouse copy/paste
- Multiple display pages with PCOPY equivalent
- Custom BMP font loading at runtime (`vt_loadfont`)
- Screen save/load in `.vts` format (`vt_bsave` / `vt_bload`)

---

## API Reference

Full function reference, constants, and parameter details:
**[rbreitinger.github.io/libvt/vt_api.html](https://rbreitinger.github.io/libvt/vt_api.html)**

---

## Basic Setup

```freebasic
vt_title "Window Title"    ' optional, before or after vt_screen
vt_screen VT_SCREEN_0      ' open window -- VT_WINDOWED is the default flag
vt_scrollback 200          ' optional scrollback, call after vt_screen
```

Pass an init flag as the second argument to `vt_screen`:

```freebasic
vt_screen VT_SCREEN_0, VT_FULLSCREEN_ASPECT   ' integer-scaled fullscreen
vt_screen VT_SCREEN_0, VT_WINDOWED_MAX        ' start maximized
vt_screen VT_SCREEN_0, VT_WINDOWED Or VT_VSYNC
```

To change mode mid-program, call `vt_screen` again — it closes and reopens cleanly.

---

## License

MIT License — Copyright (c) 2026 Rene Breitinger (yorokobi)

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
