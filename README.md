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
| c64 (+512K REU), c128, pet (4032, 40 columns) | VICE 3.10, SDL2 UI (x64sc, x128, xpet) | `vice.squashfs` ~5 MB |
| a500 (KS 1.3, WB 1.3 in DF0), a1200 (KS 3.1, WB 3.1 on DH0) | Amiberry 8.3.0, SDL3, no OpenGL | `amiga.squashfs` ~18 MB |
| x16 (Commander X16, ROM r49; drive 8 = `~/personalities/x16`) | x16emu r49, SDL2 | `x16.squashfs` ~0.2 MB |
| k4532 (the K4510 with a 4532 CPU mode, RISC-V RV32IM: `K32 HELLO`; disk `~/personalities/k4532/fs`) | Doc's K4532 (`K4532_REF`, default a34e72c), SDL2 | `k4532.squashfs` ~1.3 MB |

Quitting back to the K4510: VICE and Amiberry F12 -> Quit; the X16 F12 ->
Exit to the K4510 (our menu: also Reset, Warp, Placement, Scale, Sidebar), Alt+F4, or
`POWEROFF` at its BASIC prompt; the K4532 F12 -> Machine -> Quit the emulator
(or Shift+Esc), as on the K4510 -- its Power off and Save and power off turn
the machine off, as the K4510's do.

**K4532** (`machine/k4532/run`): Doc's [K4532](https://github.com/mlongval/K4532)
(private), the K4510 with a RISC-V CPU mode, run the way k4510-session runs
the K4510 (full screen on the KMS display, the same F12 menu) but from a
directory of its own, `~/personalities/k4532`: its settings (`k4510.cfg`,
`k4510-menu.cfg`, copied from the K4510's on the first run, its own after
that), save states, shots, and its disk `fs/`. The disk is copied from the
image on the first run; a newer image adds the files it ships that are new,
updates a shipped file only where yours is still the one shipped before, and
leaves your edits, your own files and any shipped file you deleted alone
(`fs.sha256` in the image, `.shipped` on the disk). Its `STARTUP.BAT` says
what it is and to type `K32 HELLO` (also `K32 BIG`, `K32 VICKY`, `K32 TRAP
NULL`; the programs are in `/APPS/K4532`). The banner's build is
`0.9-<k4510 pin>-K32`. K/OS's ROM is k4510's own, unchanged (K4532 does not
patch it).

**Placement** (all three emulators, build-time patches in `tools/patches/`):
`K4510_PLACEMENT=left|centre`, `K4510_SCALE=fit|integer`, defaults from
`~/personalities/display.cfg`, shared by all three: `placement=left|centre`,
`scale=fit|integer`, `sidebar=NAME`, `vdcborders=on|off` (starting file:
left, fit, antfarm). The X16's F12 menu writes the first three, the C128's
the last; each keeps the other lines. Left puts the picture flush left at
full height and leaves the rest of the width free for a **sidebar**: the
K4510's scenes (`~/k4510/sdl/libk4510side.so`, dlopened via
`tools/patches/common/k4510host.c`): none antfarm matrix space river
dreamfall tetris halloween christmas.

**C128**, placement left: the other display lives in the sidebar, live (the
VDC with its borders cropped off: its 80x25 text area plus 8 pixels, so the
80-column text is readable), F12 -> Video settings -> VICII/VDC swaps them.
At power-on the screen the C128 did not start on is blank (black on black)
until something is printed to it.
C128 keys on the PC: ESC = F9 (so ESC X = F9 then X, switching the BASIC
screen), 40/80 DISPLAY = keypad `/`, or F12 -> Video settings -> 40/80 key
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
    tools/build-k4532.sh             # on the HOST: needs cc65 (~/opt/cc65/bin), riscv64-unknown-elf-gcc + picolibc
    tools/curate-c64.sh; tools/get-robots.sh   # software for ~/personalities
    tools/make-images.sh             # -> work/out/{personalities,home}  (make-images.sh k4532: that image alone)
    tools/test-personality.sh c64    # -> work/shots/c64.jpg (Xvfb on the base stand-in)
    K4510_KEYS="$(printf '~~~~~~~~K32 HELLO\r')" SHOT=k4532-hello tools/test-personality.sh k4532 14
    tools/export-patches.sh          # -> patches/*.patch: the same changes as plain diffs (patches/README.md)
    tools/deploy-dell.sh             # images to p4, starting files to ~/personalities
    tools/deploy-dell.sh -n --only k4532   # what one family's deploy would copy, sending nothing

`tools/build-k4532.sh` clones `K4532_REPO` (local.cfg: your K4532 checkout or its git URL) into
`work/k4532-src` at `K4532_REF` (local.cfg; default a34e72c, phase 1), takes
its k4510 submodule from `K4510_MIRROR` (default
https://github.com/mlongval/k4510.git), and runs K4532's own `make` there on the
host (the ROM, K32 and the 4532 programs need cc65 and the RISC-V GCC, which
the builder lacks); then it compiles the emulator and the Tube's BBC BASIC
again inside personalities-builder from a copy of that tree, for trixie's
libraries. A newer K4532: set `K4532_REF` and run `tools/build-k4532.sh &&
tools/make-images.sh k4532` again.

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
- `~/personalities/<name>/` — floppies, DH0, `.uae`; VICE settings in `~/.config/vice/vicerc`;
  the K4532's settings, disk and save states in `~/personalities/k4532/`
- Kickstarts and Workbench are your own, named in `local.cfg` (copy
  `local.cfg.example`; it is not tracked): KS 1.3 crc c4f0f55f, KS 3.1 A1200
  crc 1483a091.  The C64 collection (`C64_COLLECTION`) and the machine to
  deploy to (`DEPLOY_HOST`) are named there too.

The K4532 shows up in the Chooser from its `.list` alone (after the others,
with the plain screen badge, its title cut at " (" to "K4532"); its place
after the K4510 and a badge of its own are a small change to the K4510
repo's `sdl/chooser.c`.

## License

MIT (`LICENSE`) for this repo's own code: the scripts, the sidebar glue
(`tools/patches/common/`) and the X16's F12 menu (`tools/patches/x16/k4510menu.*`).
The patches in `patches/` change VICE (GPL-2.0-or-later), Amiberry (GPL-3.0)
and the X16 emulator (BSD-2-Clause); a patched tree is under its project's
license.  The K4532 is not patched here: `tools/build-k4532.sh` builds Doc's
own K4532 (a private repo; GPL-2.0, as the K4510 it is made from) as it is,
and its build -- emulator, K/OS ROM, K/OS's files, K32 and its demos (with
picolibc, BSD) -- is in `k4532.squashfs`, an image made on and for Doc's
machine, not put in this repo.  No ROMs, Kickstarts or games are in this repo: the X16 ROM and the
PETSCII Robots shareware are downloaded from their official sources at build
time, and the Amiga and C64 files come from your own (`local.cfg`).
