#!/bin/sh
# The K4532 personality: the K4510 with a 4532 CPU mode (RISC-V RV32IM),
# Doc's own ~/Projects/K4532 (private).  Runs on the HOST (not inside the
# builder), in three steps:
#
#   1. a clone of K4532 at K4532_REF (local.cfg; default a34e72c, phase 1)
#      in work/k4532-src, its k4510 submodule from K4510_MIRROR, and K4532's
#      own `make` there: the patched tree work/k4532-src/work/k4510 with the
#      K/OS ROM, the programs, K32 and the 4532 demos.  The host has what
#      that needs (cc65 in ~/opt/cc65/bin, riscv64-unknown-elf-gcc and
#      picolibc); the builder has neither.
#   2. the emulator itself (sdl/k4510, SDL2) and the Tube's BBC BASIC
#      compiled again inside personalities-builder -- trixie, the K4510x's
#      own Debian -- from a copy of that tree, so it links against the
#      machine's libraries.
#   3. work/stage/k4532: what goes in the image (tools/make-images.sh k4532
#      makes k4532.squashfs from it and bundles the libraries the base lacks).
#
#   tools/build-k4532.sh && tools/make-images.sh k4532
#
# A newer K4532: K4532_REF=<commit> in local.cfg (or the environment), and
# run both again.  The clone fetches from K4532_REPO first.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work
[ -f "$HERE/local.cfg" ] && . "$HERE/local.cfg"
REF=${K4532_REF:-a34e72c}
REPO=${K4532_REPO:-$HOME/Projects/K4532}                    # read only: cloned, never built in
MIRROR=${K4510_MIRROR:-$HOME/LocalRepositories/k4510.git}   # or https://github.com/mlongval/k4510.git
export PATH=$HOME/opt/cc65/bin:$PATH
S=$W/k4532-src; T=$W/k4532-trixie; ST=$W/stage/k4532

# --- 1. K4532 at REF, built by its own make, on the host
[ -d "$S/.git" ] || git clone -q "$REPO" "$S"
git -C "$S" fetch -q origin
git -C "$S" -c advice.detachedHead=false checkout -q --force "$REF"
git -C "$S" config submodule.k4510.url "$MIRROR"
git -C "$S" -c protocol.file.allow=always submodule update -q --init --force
full=$(git -C "$S" rev-parse HEAD)
# another commit: its work tree from scratch (mktree.sh would otherwise
# refuse a tree it cannot account for)
[ "$(cat "$S/.built-ref" 2>/dev/null)" = "$full" ] || rm -rf "$S/work"
make -C "$S" -j"$(nproc)" >"$W/k4532-host-make.log" 2>&1 || { tail -30 "$W/k4532-host-make.log"; exit 1; }
echo "$full" > "$S/.built-ref"
K=$S/work/k4510
PIN=$(git -C "$S/k4510" rev-parse --short=7 HEAD)
BUILD=0.9-$PIN-K32                           # K4532's Makefile's: the version register
for f in rom/kernal.bin fs/SYSTEM/BIN/k32.prg fs/APPS/K4532/HELLO.K32; do
    [ -f "$K/$f" ] || { echo "build-k4532.sh: $f was not built"; exit 1; }
done

# --- 2. the emulator, compiled for trixie (the host built one for itself)
rm -rf "$T"; cp -a "$K" "$T"
find "$T" -type f \( -name '*.o' -o -name '*.d' \) -delete
rm -f "$T/sdl/k4510" "$T/sdl/k4510-chooser" "$T/sdl/libk4510side.so" "$T/tube/bbcbasic"
podman run --rm -v "$W:/work:Z" personalities-builder sh -c "
    set -e
    command -v nasm >/dev/null || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends nasm >/dev/null; }   # the Tube (tools/Containerfile has it now)
    cd /work/k4532-trixie
    make -j\$(nproc) K4510_BUILD=$BUILD sdl/k4510 >/work/k4532-trixie-make.log 2>&1 || { tail -30 /work/k4532-trixie-make.log; exit 1; }
    make -C tube >>/work/k4532-trixie-make.log 2>&1 || { tail -30 /work/k4532-trixie-make.log; exit 1; }
    ldd sdl/k4510 | grep -q 'libSDL2' "

# --- 3. the stage
rm -rf "$ST"; mkdir -p "$ST/bin" "$ST/rom" "$ST/data" "$ST/tube" "$ST/fs"
cp "$T/sdl/k4510" "$ST/bin/k4532"
cp "$K/rom/kernal.bin" "$ST/rom/"
cp -a "$K/data/fonts" "$ST/data/"
cp "$T/tube/bbcbasic" "$ST/tube/"
# the disk it starts from: k4510's fs as git carries it (with K32 and the
# 4532 programs, committed by mktree.sh --built), and the K4532's own
# STARTUP.BAT.  run/k4532 copies it to ~/personalities/k4532/fs.
(cd "$K" && git ls-files -z fs | xargs -0 tar cf -) | tar -C "$ST" -xf -
cp "$HERE/machine/k4532/STARTUP.BAT" "$ST/fs/STARTUP.BAT"
(cd "$ST/fs" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do sha256sum "$f"; done) > "$ST/fs.sha256"
printf 'K4532 %s (%s)\nk4510 %s\nbuild %s\n' "$(git -C "$S" rev-parse --short=7 HEAD)" \
    "$(git -C "$S" log -1 --format='%cs %s' HEAD | cut -c1-60)" "$PIN" "$BUILD" > "$ST/VERSION"
cat "$ST/VERSION"
du -sh "$ST"
