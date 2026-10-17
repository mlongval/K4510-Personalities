# K4510 Personalities

Other machines for the K4510x, picked at power-on like a MiSTer/MEGA65 core:
hold **SPACE** at power-on and, just before the K4510 starts, a menu lists
K4510, K4532, Commodore 64, 128, PET, Amiga 500, Amiga 1200, Commander X16. The
chosen machine runs from RAM, and quitting it (F12 -> Quit) brings up the
K4510. No space: the K4510, one second later. (A GRUB-entry version came first, but was dropped
the same day: Doc wants Debian to show the choice.)
(Started 2026-10-08 as "could BMC64 run in a container?" — BMC64 itself is
Pi bare-metal glue around VICE 3.3; upstream VICE's SDL UI is the better fit.)

| Personality | Emulator | Image |
|---|---|---|
| c64, c128 (+16 MB REU, SD volume on drive 9), pet (4032, 40 columns) | VICE 3.10, SDL2 UI (x64sc, x128, xpet) | `vice.squashfs` ~5 MB |
| a1200 (KS 3.1, WB 3.1 on DH0, Work 20 MB on DH1; the A500 went 2026-10-12) | Amiberry 8.3.0, SDL3, no OpenGL | `amiga.squashfs` ~18 MB |
| x16 (Commander X16, ROM r49; drive 8 = `~/personalities/x16`) | x16emu r49, SDL2 | `x16.squashfs` ~0.2 MB |

Quitting back to the K4510: VICE and Amiberry F12 -> Quit; the X16 F12 ->
Exit to the K4510 (our menu: also Reset, Warp, Placement, Scale, Sidebar), Alt+F4, or
`POWEROFF` at its BASIC prompt; the K4532 F12 -> Machine -> Quit the emulator
(or Shift+Esc), as on the K4510 -- its Power off and Save and power off turn
the machine off, as the K4510's do.

**The K4532** is no longer a personality (2026-10-12, K4532's PLAN.md step
6): it is the machine itself, the layer's `~/k4532`, and the one these
personalities come back to.  Its image, `machine/k4532` and
`tools/build-k4532.sh` went; their history is in git.

**K4532 vi-ui (experiment)** (`machine/k4532vi`, 2026-10-16): the K4532
with the programs of K4532's branch `vi-ui` -- one vi-style grammar, Space
the leader, `:name` with Tab -- to try before it goes into the machine.
The machine's own emulator, run from `~/personalities/k4532vi` with a copy
of its disk made the first time; the branch's programs are laid over it at
every start.  `tools/build-k4532vi.sh && tools/deploy-dell.sh --only k4532vi`.

**Placement** (all three emulators, build-time patches in `tools/patches/`):
`K4510_PLACEMENT=left|centre`, `K4510_SCALE=fit|integer`, defaults from
`~/personalities/display.cfg`, shared by all three: `placement=left|centre`,
`scale=fit|integer`, `sidebar=NAME`, `vdcborders=on|off` (starting file:
left, fit, antfarm). The X16's F12 menu writes the first three, the C128's
the last; each keeps the other lines. Left puts the picture flush left at
full height and leaves the rest of the width free for a **sidebar**: the
K4532's scenes (`~/k4532/sdl/libk4532side.so`, dlopened via
`tools/patches/common/k4510host.c`): none antfarm matrix space river
dreamfall tetris halloween christmas.

**C64 and C128**, placement left: the sidebar is the machine's own panel
instead of a K4532 scene (`tools/patches/vice/k4510c64.c`), in its case's
colour -- the breadbin's brown beige, the C128's light beige -- and lettered
in its own character ROM: a 1541 (the C128: a 1571) whose red LED lights while
it works and whose head moves track by track, the disk's directory as
`LOAD"$",8` lists it, the SD volume, and the keys on the PC's.  It works with
the mouse (it draws its own pointer; VICE shows none in fullscreen): click a
program in the directory to load and run it, DISKS for the disks in
`~/personalities/<name>` and its folders (a disk goes in drive 8; a .PRG, .T64
or .CRT runs at once), EJECT to take the disk out, BROWSE for Dir Browser on
the SD volume; the wheel scrolls.  On the C128 the screen it is not showing
(VDC or VIC-II) is along the bottom of the sidebar, the panel above it.
`K4510_C64_PANEL=0` gives the scene back.  `tools/test-c64panel.sh` clicks
through it under Xvfb (xdotool) and reads VICE's log.

Both machines (run/vice): the keyboard by symbol (`-keymap 0`: a PC key types
what is printed on it; the PET stays positional), a 16 MB REU (VICE's
largest), and drive 9 an **SD volume**: the folder `~/personalities/SD`,
shared, as VICE's filesystem device (which takes SD2IEC's `CD` commands), with
[Dir Browser](https://graham-it.itch.io/dirbrowser) on it as DB64 and DB128
(`tools/get-dirbrowser.sh` fetches its VICE builds; its terms do not allow
redistribution, so it is never in this repository, only in the image built
here).  The C64 powers on white on dark blue: the stock KERNAL with three
bytes changed (`make-images.sh`, kernal-k4532.bin).

**Amiga 1200**, placement left: the sidebar is the A1200's own panel
(`tools/patches/amiberry/k4510amiga.c`), in its off-white and lettered in
Topaz 8 taken from the Kickstart (`tools/topaz.py`): the power, floppy and
hard-drive LEDs, the disk in DF0: with its track, DH0: and DH1:, how the
touchpad clicks, and the Amiga's keys on the PC's.  It only shows (the mouse
is the Amiga's).  DH1: is **Work, a 20 MB hardfile** (FFS, made by
`tools/make-amiga-hd.sh` with amitools; copied to the machine only if none is
there; run/amiga adds it to a configuration written before it).  The
**touchpad** works as the mouse (`tools/patches/amiberry/touchpad.py`): on
the bare console SDL3 reports it as fingers, which Amiberry used only for a
finger id SDL3 never gives; now a finger moves the pointer, a tap clicks, two
fingers tap the right button, and a tap then a held finger drags.

**C128**, placement left: the other display lives along the bottom of the
sidebar, below its panel, live (the
VDC with its borders cropped off: its 80x25 text area plus 8 pixels, so the
80-column text is readable), F12 -> Video settings -> VICII/VDC swaps them.
At power-on the screen the C128 did not start on is blank (black on black)
until something is printed to it.
C128 keys on the PC (symbolic, sdl_sym.vkm): Esc = RUN/STOP, F9 = ESC (so
ESC X = F9 then X, switching the BASIC screen), 40/80 DISPLAY = keypad `/`, or F12 -> Video settings -> 40/80 key
(latched; the C128 reads it at reset, so down + reset = 80 columns).
F12 -> Video settings -> VDC borders off: the VDC as the main display shows
the same cropped text area, scaled up (saved as `vdcborders=off` in
display.cfg). While the F12 menu is open the VDC is shown whole, borders and
all, because VICE lays the menu out on the whole frame (cropped, its top rows
were lost).
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
    tools/make-images.sh             # -> work/out/{personalities,home}  (make-images.sh amiga: that image alone)
    tools/test-personality.sh c64    # -> work/shots/c64.jpg (Xvfb on the base stand-in)
    tools/export-patches.sh          # -> patches/*.patch: the same changes as plain diffs (patches/README.md)
    tools/deploy-dell.sh             # images to p4, starting files to ~/personalities
    tools/deploy-dell.sh -n --only amiga   # what one family's deploy would copy, sending nothing

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
  and `*.prev`, the ones before the last deploy. The RAM copy
  (`/run/k4510-personalities/<fam>.squashfs`, mounted at
  `/opt/personalities/<fam>`) stays until a reboot, so a new image deployed
  while the K4510 runs takes effect after a reboot, or after (machine closed)
  `sudo umount /opt/personalities/<fam>; sudo rm /run/k4510-personalities/<fam>.squashfs`.
  Copy to p4 on battery under `sudo -n systemd-inhibit`.
- `~/personalities/<name>/` — floppies, DH0, `.uae`; VICE settings in `~/.config/vice/vicerc`
- Kickstarts and Workbench are your own, named in `local.cfg` (copy
  `local.cfg.example`; it is not tracked): KS 1.3 (no longer used: the A500 went), KS 3.1 A1200
  crc 1483a091.  The C64 collection (`C64_COLLECTION`) and the machine to
  deploy to (`DEPLOY_HOST`) are named there too.

## License

MIT (`LICENSE`) for this repo's own code: the scripts, the sidebar glue
(`tools/patches/common/`) and the X16's F12 menu (`tools/patches/x16/k4510menu.*`).
The patches in `patches/` change VICE (GPL-2.0-or-later), Amiberry (GPL-3.0)
and the X16 emulator (BSD-2-Clause); a patched tree is under its project's
license.  No ROMs, Kickstarts or games are in this repo: the X16 ROM and the
PETSCII Robots shareware are downloaded from their official sources at build
time, and the Amiga and C64 files come from your own (`local.cfg`).
