# K4510 Personalities: emulator patches

Patches that adapt three emulators to the K4510 Fantasy Computer's
"personalities": the emulator's picture flush **left** at full height, and the
free space on the **right** used as a sidebar. Each one is a plain unified
diff against an unmodified upstream release, so you need neither this repo
nor its build to use them.

| Patch | Applies to | Upstream |
|---|---|---|
| `vice-3.10-k4510.patch` | VICE 3.10 release tarball, SDL2 UI (`--enable-sdl2ui`) | https://vice-emu.sourceforge.io |
| `amiberry-8.3.0-k4510.patch` | Amiberry 8.3.0 (SDL3, the non-OpenGL renderer) | https://github.com/BlitterStudio/amiberry |
| `x16emu-r49-k4510.patch` | Commander X16 emulator r49 | https://github.com/X16Community/x16-emulator |

Apply from the top of the unpacked source, then build as upstream says:

    tar xzf vice-3.10.tar.gz && cd vice-3.10
    patch -p1 < ../vice-3.10-k4510.patch

Each patch is tied to that exact release. On another version, expect rejected
hunks: the changes are small, but they are not written for it.

## What they change

**All three**
- `K4510_PLACEMENT=left` puts the picture flush left at full height. The rest
  of the screen width is free for a sidebar. With `centre`, or with the
  variable unset, the picture is placed the way the emulator always placed it.
- `K4510_SCALE=integer` scales by whole multiples only, so pixels stay
  sharp. `fit` (the default) fills the height.
- The sidebar: with `K4510_SIDEBAR_LIB` naming `libk4510side.so` (built from the
  K4510 repo, https://github.com/mlongval/k4510, `make sdl/libk4510side.so`) and
  `K4510_SIDEBAR="antfarm state=/some/dir"`, an animated scene fills the free
  area. The scenes are none, antfarm, matrix, space, river, dreamfall, tetris,
  halloween and christmas. Without the library the area stays black, and
  nothing else changes. The glue code is `k4510host.c` and
  `k4510host_sdl2.c`, added to each tree.

**VICE (`src/arch/sdl/video_sdl2.c`, `menu_video.c`, `src/vdc/vdc.c`)**
- With the picture on the left, the C128 shows both displays: the active one
  on the left and the other one, live, in the sidebar. F12 -> Video settings
  -> VICII / VDC swaps them. The VDC's wide borders are cropped off in the
  sidebar (`K4510_VDC_CROP=0` keeps them). `K4510_C128_DUAL=0` turns the second
  display off.
- F12 -> Video settings -> **VDC borders** on/off. With them off, the VDC as
  the main display shows only its text area, scaled up. While the F12 menu is
  open, the whole frame is shown. The setting is saved as `vdcborders=on|off`
  in the file named by `K4510_DISPLAY_CFG`, if it is set.
- F12 -> Video settings -> **40/80 key**: the C128's DISPLAY key, latched like
  the real one. The C128 reads it at reset.
- An upstream bug fix in `src/log.c`: VICE 3.10 crashes at its banner when
  stdout is not a terminal.

**Amiberry (`src/osdep/sdl_renderer.cpp`)**
- The placement, scaling and sidebar above. SDL3 composites its logical
  presentation at present time, so the patch switches it off for the frame
  and restores it afterwards. `K4510_DEBUG=1` prints the placement.
- An upstream compile fix: a misnamed SDL3 type
  (`SDL_LogicalPresentation` -> `SDL_RendererLogicalPresentation`).

**x16emu (`src/video.c`, `Makefile`, `src/rendertext.c`, new `src/k4510menu.c`)**
- An **F12 menu**: Resume, Reset, Warp, Placement, Scale, Sidebar, Exit. The
  machine pauses while it is open. Alt+F4 and `POWEROFF` still quit as
  before.
- The menu's choices are kept in the file named by `K4510_X16_SETTINGS`, as
  `placement=`, `scale=` and `sidebar=` lines. Other lines in that file are
  left alone.
- Full screen is `SDL_WINDOW_FULLSCREEN_DESKTOP`, the panel's own mode,
  rather than a switch to 640x480.

## Made from

`tools/export-patches.sh` in the K4510-Personalities repo writes these files.
It unpacks each release twice and changes one copy exactly as the build does
(`tools/build-*.sh`, then `tools/patches/<emulator>/apply.py`). The diff
between the two copies is the patch. Run again, it writes the same bytes.

## License

Each patch is offered under the license of the project it changes: VICE
GPL-2.0-or-later, Amiberry GPL-3.0, the X16 emulator BSD-2-Clause.  The new
files they add (`k4510host*`, `k4510menu*`) are also MIT (the repo's `LICENSE`).
