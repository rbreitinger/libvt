# VT — Virtual Text Screen Library for FreeBASIC

A self-contained library that gives you a DOS-style text screen in a real SDL2
window — or directly in a raw Linux console. One include, no SDL2 knowledge
required. Feels like QBasic, works like 2026.

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

## Backends

| Target | Backend | How |
|---|---|---|
| Windows desktop | SDL2 (default) | no `#define` needed |
| Linux desktop (X11 / Wayland) | SDL2 (default) | no `#define` needed |
| Linux raw console (Ctrl+Alt+F1–F6) | VT_TTY | `#Define VT_TTY` before include |

**VT_TTY is Linux raw console only.** It requires `TERM=linux` at runtime and
will print an error and exit otherwise. On Windows and Linux desktops, use the
SDL2 backend — same API, consistent rendering everywhere.

`VT_TTY` implies `VT_USE_ANSI` automatically. `VT_USE_ANSI` alone enables the
ANSI escape parser inside `vt_print` while staying on the SDL2 backend.

---

## Requirements

**SDL2 backend:** FreeBASIC 1.10.1 + SDL2.

- **Windows:** place `SDL2.dll` alongside your compiled executable.
  Get it from the [FreeBASIC library archive](https://github.com/rbreitinger/fb-lib-archive/tree/main/libraries/SDL2/SDL2-2.0.14).
- **Linux:** install via package manager (`libsdl2-dev` / `SDL2-devel` / `sdl2`).

**VT_TTY backend:** FreeBASIC 1.10.1, no SDL2 required, Linux only.

---

## Installation

Copy the `vt` folder into FreeBASIC's `inc` directory:

- **Windows:** `C:\FreeBASIC\inc\vt\`
- **Linux:** `/usr/local/share/freebasic/inc/vt/`

Then in any source file: `#include once "vt/vt.bi"`

---

## Distributing programs

**SDL2 backend:** ship `SDL2.dll` alongside your executable (Windows).
Linux users have `libsdl2` system-wide.

**VT_TTY backend:** no DLLs. The compiled executable is self-contained.

If shipping source, note the dependency in your readme:
```
Requires: libvt — https://github.com/rbreitinger/libvt
```

---

## Screen Modes

| Constant | Cols × Rows | Font | Canvas | Original |
|---|---|---|---|---|
| `VT_SCREEN_0` | 80 × 25 | 8×16 | 640×400 | VGA text (default) |
| `VT_SCREEN_2` | 80 × 25 | 8×8 | 640×200 | CGA hi-res |
| `VT_SCREEN_9` | 80 × 25 | 8×14 | 640×350 | EGA |
| `VT_SCREEN_12` | 80 × 30 | 8×16 | 640×480 | VGA hi-res |
| `VT_SCREEN_13` | 40 × 25 | 8×8 | 320×200 | VGA Mode 13h |
| `VT_SCREEN_EGA43` | 80 × 43 | 8×8 | 640×344 | EGA 43-line |
| `VT_SCREEN_VGA50` | 80 × 50 | 8×8 | 640×400 | VGA 50-line |
| `VT_SCREEN_TILES` | 40 × 25 | 16×16 | 640×400 | Square tiles |

In `VT_TTY` mode, screen mode constants only affect the logical column/row count —
the terminal is not resized. Window flags (`VT_FULLSCREEN_ASPECT` etc.) are
silently ignored in TTY mode.

---

## Features & Extensions

Optional extensions are pulled in by a single `#define` before the include —
zero overhead if unused.

| Feature / Extension | `#define` | SDL2 | VT_TTY |
|---|---|---|---|
| CP437 fonts (8×8, 8×14, 8×16 embedded) | — | ✅ | — |
| CGA 16-colour palette + manipulation | — | ✅ | ✅ ANSI mapped |
| All 256 CP437 glyphs | — | ✅ | ⚠️ raw bytes, works on raw VT |
| Blinking text (`VT_BLINK`) | — | ✅ | ⚠️ emitted, raw console may ignore |
| Windowed / fullscreen / maximized | — | ✅ | — |
| Scrollback buffer + Shift+PgUp/Dn | — | ✅ | ✅ Alt+minus/period |
| Scroll regions | — | ✅ | ✅ |
| Key input (`vt_inkey`, `vt_key_held`) | — | ✅ | ⚠️ `vt_key_held` always 0 |
| Blocking line editor (`vt_input`) | — | ✅ | ✅ |
| Mouse | — | ✅ | ❌ no-op |
| Copy / paste | — | ✅ | ❌ no-op |
| Multiple display pages | — | ✅ | ✅ |
| Custom font loading (`vt_loadfont`) | — | ✅ | ❌ no-op |
| Screen save/load `.vts` (`vt_bsave/bload`) | — | ✅ | ✅ |
| Close-button callback (`vt_on_close`) | — | ✅ | — |
| **Sound** — QBasic-style audio | `VT_USE_SOUND` | ✅ | ❌ compile error |
| **Sort** — Shellsort + shuffle for all types | `VT_USE_SORT` | ✅ | ✅ |
| **Math** — grid/game math, LOS, Bresenham | `VT_USE_MATH` | ✅ | ✅ |
| **Strings** — split, wrap, pad, replace | `VT_USE_STRINGS` | ✅ | ✅ |
| **File** — exists, copy, list, rmdir | `VT_USE_FILE` | ✅ | ✅ |
| **TUI** — DOS-style widgets + menubar | `VT_USE_TUI` | ✅ | ✅ |
| **Net** — sockets wrapper (wip) | `VT_USE_NET` | ✅ | ✅ |

`VT_USE_TUI` automatically pulls in `VT_USE_STRINGS` and `VT_USE_FILE`.
Sort, Math, Strings, File have no SDL2 or open screen dependency — usable in
any FreeBASIC project.

---

## Examples

![VTetris running in fullscreen](docs/screenshot1.png)

The `examples/` directory contains runnable examples for most features.
VTetris is a complete Tetris game demonstrating sound, math and string extensions
working together — run `vtetris-bake.bas` once first to generate the screen assets.

---

## API Reference

Full function reference, constants and parameter details:
**[rbreitinger.github.io/libvt/vt_api.html](https://rbreitinger.github.io/libvt/vt_api.html)**

---

## License

MIT License — Copyright (c) 2026 Rene Breitinger (yorokobi)
[read LICENSE here](https://github.com/rbreitinger/libvt/LICENSE)