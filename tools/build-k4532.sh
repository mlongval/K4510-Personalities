#!/bin/sh
# The K4532 personality: the K4510 with a 4532 CPU mode (RISC-V RV32IM),
# Doc's own K4532 repo (private; K4532_REPO in local.cfg).  Runs on the HOST (not inside the
# builder), in three steps:
#
#   1. a clone of K4532 at K4532_REF (local.cfg; default a34e72c, phase 1)
#      in work/k4532-src and K4532's own `make` there: the K/OS ROM, the
#      programs, K32 and the 4532 demos (a commit before 2026-10-12 is a
#      thin repository: its k4510 submodule from K4510_MIRROR, the patched
#      tree in work/k4532-src/work/k4510).  The host has what
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
REPO=${K4532_REPO:?set K4532_REPO in local.cfg}             # read only: cloned, never built in
MIRROR=${K4510_MIRROR:-https://github.com/mlongval/k4510.git}   # a local mirror is faster
export PATH=$HOME/opt/cc65/bin:$PATH
S=$W/k4532-src; T=$W/k4532-trixie; ST=$W/stage/k4532

# --- 1. K4532 at REF, built by its own make, on the host
[ -d "$S/.git" ] || git clone -q "$REPO" "$S"
git -C "$S" fetch -q origin
git -C "$S" -c advice.detachedHead=false checkout -q --force "$REF"
full=$(git -C "$S" rev-parse HEAD)
if [ -f "$S/.gitmodules" ]; then
    # before 2026-10-12, a thin repository: k4510 as a submodule, built in
    # work/k4510 (a commit of that time still builds this way)
    git -C "$S" config submodule.k4510.url "$MIRROR"
    git -C "$S" -c protocol.file.allow=always submodule update -q --init --force
    [ "$(cat "$S/.built-ref" 2>/dev/null)" = "$full" ] || rm -rf "$S/work"
    K=$S/work/k4510
    BUILD=0.9-$(git -C "$S/k4510" rev-parse --short=7 HEAD)-K32
else
    # one tree (K4532's PLAN.md, step 1): built where it is
    rm -rf "$S/k4510" "$S/work"                # a thin commit's leftovers
    K=$S
    BUILD=0.9-$(git -C "$S" rev-parse --short=7 HEAD)
fi
make -C "$S" -j"$(nproc)" K4510_BUILD="$BUILD" >"$W/k4532-host-make.log" 2>&1 || { tail -30 "$W/k4532-host-make.log"; exit 1; }
echo "$full" > "$S/.built-ref"
PIN=${BUILD#0.9-}; PIN=${PIN%-K32}
for f in rom/kos.k32 fs/APPS/K4532/HELLO.K32; do
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

# --- 2b. the compilers PAS and CC run on the Linux beneath (k4532-pas,
# k4532-cc, through the Tube's `!`): trixie's RISC-V GCC, binutils and
# picolibc, cut down to the one multilib the 4532 uses (rv32imfd/ilp32d), at
# /opt/personalities/k4532/rvgcc (picolibc's specs name that prefix); kept in
# work/k4532-rvgcc between runs.  Free Pascal's cross-compiler (static) and
# its RTL come from the host's K4532_FPC (tools/fpc-k4532.sh in K4532).
X=/opt/personalities/k4532; G=$W/k4532-rvgcc
FPCK=${K4532_FPC:-$HOME/opt/fpc-k4532}
[ -x "$FPCK/bin/ppcrv32" ] || { echo "build-k4532.sh: no Free Pascal for the 4532 at $FPCK (K4532's tools/fpc-k4532.sh)"; exit 1; }
if [ ! -f "$G/STAMP" ]; then
    rm -rf "$G"; mkdir -p "$G"
    podman run --rm -v "$W:/work:Z" personalities-builder sh -c "
        set -e; cd /tmp
        apt-get update -qq >/dev/null
        apt-get download gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf picolibc-riscv64-unknown-elf >/dev/null
        for d in *.deb; do dpkg -x \$d /tmp/x; done
        U=/tmp/x/usr; L=\$U/lib/gcc/riscv64-unknown-elf/*; P=\$U/lib/picolibc/riscv64-unknown-elf
        rm -f \$U/bin/*-c++ \$U/bin/*-g++ \$U/bin/*-lto-dump; rm -rf \$U/share
        rm -rf \$L/cc1plus \$L/lto1 \$L/g++-mapper-server \$L/plugin \$L/install-tools
        for d in \$L/rv* \$P/lib/rv* \$P/lib/release; do [ \$d != \$(dirname \$d)/rv32imfd ] && rm -rf \$d; done
        for d in \$L/rv32imfd/* \$P/lib/rv32imfd/*; do [ \$(basename \$d) = ilp32d ] || rm -rf \$d; done
        sed -i 's|/usr/lib/picolibc|$X/rvgcc/lib/picolibc|g' \$P/*.specs
        cp \$P/*.specs \$L/                 # gcc looks for a specs file in its own directory (Debian's found /usr/lib/picolibc's)
        cp -a \$U/. /work/k4532-rvgcc/
        ls /tmp/*.deb | sed 's|.*/||' > /work/k4532-rvgcc/STAMP"
fi

# --- 3. the stage
rm -rf "$ST"; mkdir -p "$ST/bin" "$ST/rom" "$ST/data" "$ST/tube" "$ST/fs"
cp "$T/sdl/k4510" "$ST/bin/k4532"
cp "$K/rom/kos.k32" "$ST/rom/"               # K/OS, the machine's ROM (the 4510's kernal.bin went, K4532 PLAN.md step 3)
cp -a "$K/data/fonts" "$ST/data/"
cp "$T/tube/bbcbasic" "$ST/tube/"
# the compilers (2b), and what they need of the K4532 tree: their scripts
# (run/k4532 links tools/ beside fs/, which the Tube puts on PATH) and rv32/
# (crt0.S, glue.c, k4532.ld, the headers, the Pascal units)
cp -a "$G" "$ST/rvgcc"; rm -f "$ST/rvgcc/STAMP"
mkdir -p "$ST/fpc/bin" "$ST/tools"
cp "$FPCK/bin/ppcrv32" "$ST/fpc/bin/"; cp -a "$FPCK/units" "$ST/fpc/"
for t in k4532-cc k4532-pas mk4532.py port4510.py; do cp "$K/tools/$t" "$ST/tools/"; done
(cd "$K" && tar cf - --exclude=rv32/build --exclude='*.o' --exclude='*.elf' rv32) | tar -C "$ST" -xf -
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
