#!/bin/sh
# The Commander X16 emulator (x16emu, SDL2) for the X16 personality.  Runs
# INSIDE the builder.  The emulator is built from source against the
# builder's (= the machine's) SDL2; the ROM (x16-rom, with the CBM KERNAL
# and BASIC licensed for the X16) comes from the same release's Linux zip.
# Nothing is compiled-in about paths: run/x16 passes -rom.
set -e
VER=${X16_VER:-r49}
cd /work
[ -f x16-emulator-$VER.tar.gz ] || curl -fsSL -o x16-emulator-$VER.tar.gz \
    "https://github.com/X16Community/x16-emulator/archive/refs/tags/$VER.tar.gz"
[ -f x16emu_linux-x86_64-$VER.zip ] || curl -fsSL -o x16emu_linux-x86_64-$VER.zip \
    "https://github.com/X16Community/x16-emulator/releases/download/$VER/x16emu_linux-x86_64-$VER.zip"
rm -rf x16-emulator-$VER && tar xzf x16-emulator-$VER.tar.gz && cd x16-emulator-$VER
# Fullscreen at the display's own mode (as the K4510 does), not a switch to
# a 640x480 mode the laptop's panel may not have.
sed -i 's/SDL_WINDOW_FULLSCREEN\b/SDL_WINDOW_FULLSCREEN_DESKTOP/g' src/video.c
grep -q SDL_WINDOW_FULLSCREEN_DESKTOP src/video.c
make -j"$(nproc)" GIT_REV=$VER x16emu >/work/x16-make.log 2>&1 || { tail -30 /work/x16-make.log; exit 1; }
rm -rf /work/stage/x16 && mkdir -p /work/stage/x16/bin
cp x16emu /work/stage/x16/bin/
python3 -c "import zipfile,sys; open(sys.argv[2],'wb').write(zipfile.ZipFile(sys.argv[1]).read('rom.bin'))" \
    /work/x16emu_linux-x86_64-$VER.zip /work/stage/x16/rom.bin   # no unzip in the builder
ls -l /work/stage/x16 /work/stage/x16/bin
