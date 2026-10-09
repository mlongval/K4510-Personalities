# K4510 Personalities

Other machines for the K4510x, picked at power-on like a MiSTer/MEGA65 core:
hold **SPACE** at power-on and, just before the K4510 starts, a menu lists
K4510, Commodore 64, 128, PET, Amiga 500, Amiga 1200. The chosen machine
runs from RAM, and quitting it (F12 -> Quit) brings up the K4510. No space:
the K4510, one second later. (A GRUB-entry version came first, but was dropped
the same day: Doc wants Debian to show the choice.)
(Started 2026-10-08 as "could BMC64 run in a container?" — BMC64 itself is
Pi bare-metal glue around VICE 3.3; upstream VICE's SDL UI is the better fit.)

| Personality | Emulator | Image |
|---|---|---|
| c64 (+512K REU), c128, pet (4032, 40 columns) | VICE 3.10, SDL2 UI (x64sc, x128, xpet) | `vice.squashfs` ~5 MB |
| a500 (KS 1.3, WB 1.3 in DF0), a1200 (KS 3.1, WB 3.1 on DH0) | Amiberry 8.3.0, SDL3, no OpenGL | `amiga.squashfs` ~18 MB |
| x16 (Commander X16, ROM r49; drive 8 = `~/personalities/x16`) | x16emu r49, SDL2 | `x16.squashfs` ~0.2 MB |

Quitting back to the K4510: VICE and Amiberry F12 -> Quit; the X16 F12 ->
Exit to the K4510 (our menu: also Reset, Warp, Placement, Scale), Alt+F4, or
`POWEROFF` at its BASIC prompt.

**Placement** (all three emulators, build-time patches in `tools/patches/`):
`K4510_PLACEMENT=left|centre`, `K4510_SCALE=fit|integer`, defaults from
`~/personalities/display.cfg` (`placement=left`, `scale=integer`; the X16's
F12 menu writes it). Left puts the picture flush left at full height and
leaves `{pic right edge, 0, rest of width, full height}` free for a sidebar
(the K4510's savers.c, later: a pixel-buffer library each emulator dlopens).

**C128**, placement left: the other display lives in the sidebar (the VDC
with its borders cropped off), F12 -> Video settings -> VICII/VDC swaps them.
C128 keys on the PC: ESC = F9 (so ESC X = F9 then X, switching the BASIC
screen), 40/80 DISPLAY = keypad `/`, or F12 -> Video settings -> 40/80 key
(latched; the C128 reads it at reset, so down + reset = 80 columns).
F12 -> Video settings -> VDC borders off: the VDC as the main display shows
the same cropped text area, scaled up (saved as `vdcborders=off` in
display.cfg; the X16's menu keeps that line when it saves).
`K4510_C128_DUAL=0` / `K4510_VDC_CROP=0` turn the dual display / the crop off.

**Software** in `~/personalities/` (on p4, where each file browser starts):
the C64 library curated from Doc's collection by `tools/curate-c64.sh`
(GAMES DEMOS UTILS LANGUAGES DOCS; MANIFEST.txt says where each came from),
and Attack of the PETSCII Robots, the free shareware editions from the 8-Bit
Guy's site (`tools/get-robots.sh`), for the C64 (+REU), C128, PET, Amiga, X16.

VIC-20 and Plus/4 are sidelined (Doc, 2026-10-08).

## Build (ubuntu-s1, rootless podman)

    podman build -t personalities-builder -f tools/Containerfile tools
    podman build -t k4510-base-mimic -f tools/Containerfile.base tools   # trixie + K4510 packages.list
    podman build -t k4510-base-test  -f tools/Containerfile.test tools   # + Xvfb
    podman run --rm -v $PWD/work:/work:Z -v $PWD/tools:/tools:ro personalities-builder sh /tools/build-vice.sh
    podman run --rm -v $PWD/work:/work:Z -v $PWD/tools:/tools:ro personalities-builder sh /tools/build-amiberry.sh
    podman run --rm -v $PWD/work:/work:Z -v $PWD/tools:/tools:ro personalities-builder sh /tools/build-x16.sh
    tools/curate-c64.sh; tools/get-robots.sh   # software for ~/personalities
    tools/make-images.sh             # -> work/out/{personalities,home}
    tools/test-personality.sh c64    # -> work/shots/c64.jpg (Xvfb on the base stand-in)
    tools/deploy-dell.sh             # images to p4, starting files to ~/personalities

Libraries the K4510x base lacks are found by asking `k4510-base-mimic` and
bundled into each image's `lib/`. Refresh `tools/k4510-base.packages` from
the K4510 repo's `linux/packages.list` when the base changes.

Two upstream bugs patched at build time: VICE 3.10 crashes at the banner when
stdout is not a terminal (`src/log.c`); Amiberry 8.3.0's non-OpenGL renderer
does not compile (`sdl_renderer.cpp`, a misnamed SDL3 type). And one change:
x16emu's fullscreen becomes FULLSCREEN_DESKTOP (the panel's own mode, as the
K4510 does) instead of a switch to a 640x480 mode the panel may not have.

## The K4510 side (K4510 repo, master: 745d8e8 + spacebar menu a5cdeb0 + X16 words 39a0cb7)

- `linux/config/includes.chroot/usr/local/bin/k4510-personality` — copy the image to /run, mount, run
- `linux/config/includes.chroot/usr/local/bin/k4510-boot-menu` — 1 s wait for a held space, then the menu
- `etc/profile.d/k4510.sh` — runs k4510-boot-menu on tty1 (or `k4510.personality=` from /proc/cmdline, once a boot)
- `docs/STORAGE.md` §3b

## Where things live on the machine

- p4 `/personalities/*.squashfs` + `*.list` — the images (copied to RAM only when chosen)
- `~/personalities/<name>/` — floppies, DH0, `.uae`; VICE settings in `~/.config/vice/vicerc`
- Kickstarts/Workbench came from `/media/doc/Internal_3TB/Emulation/Amiga` and
  `Internal_2TB/.../Documents/Amiga` (KS 1.3 crc c4f0f55f, KS 3.1 A1200 crc 1483a091).
