#!/bin/sh
# VICE with the SDL2 UI (not GTK) for the C64 / C128 / PET personalities.
# Runs INSIDE the builder container; /work is ~/Projects/K4510-Personnalities/work.
#   prefix /opt/personalities/vice is where its squashfs is mounted on the
#   machine, so VICE finds its ROMs and keymaps at the compiled-in path.
set -e
VER=${VICE_VER:-3.10}
PREFIX=/opt/personalities/vice
cd /work
[ -f vice-$VER.tar.gz ] || curl -fsSL -o vice-$VER.tar.gz \
    "https://downloads.sourceforge.net/project/vice-emu/releases/vice-$VER.tar.gz"
rm -rf vice-$VER && tar xzf vice-$VER.tar.gz && cd vice-$VER
# 3.10's log_helper only makes the colourless copy of a message when logging
# to a file or with colours off, then hands that (NULL) copy to stdout when
# stdout is not a terminal -- a crash at the banner whenever the output is
# redirected, which on the machine it always is.  Always make the copy.
sed -i 's/if ((log_to_file) || (!log_colorize)) {/if (1) {/' src/log.c
grep -q 'if (1) {' src/log.c
# The K4510's picture placement (K4510_PLACEMENT=left, K4510_SCALE=integer).
python3 /tools/patches/vice/apply.py
./configure --prefix=$PREFIX --enable-sdl2ui --disable-pdf-docs --disable-html-docs \
    --without-pulse --without-oss --with-alsa --disable-ethernet \
    --without-libieee1284 --disable-catweasel --disable-hardsid --disable-parsid \
    CFLAGS="-O2 -march=x86-64-v2" CXXFLAGS="-O2 -march=x86-64-v2" >/work/vice-configure.log
make -j"$(nproc)" >/work/vice-make.log 2>&1
rm -rf /work/stage/vice && make DESTDIR=/work/stage/vice install >/work/vice-install.log 2>&1
ls -la /work/stage/vice$PREFIX/bin
