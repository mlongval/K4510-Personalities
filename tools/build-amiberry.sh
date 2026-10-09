#!/bin/sh
# Amiberry (SDL3) for the Amiga personalities.  Runs INSIDE the builder.
# Prefix /opt/personalities/amiga: its data dir is compiled in from it.
# No OpenGL: the machine has no X or Wayland, only KMS, and SDL's own
# renderer is the path that is sure to work there.  No PCem/PPC/pcap: an
# A500 and an A1200 need none of them.
set -e
VER=${AMIBERRY_VER:-8.3.0}
PREFIX=/opt/personalities/amiga
cd /work
[ -f amiberry-$VER.tar.gz ] || curl -fsSL -o amiberry-$VER.tar.gz \
    "https://github.com/BlitterStudio/amiberry/archive/refs/tags/v$VER.tar.gz"
rm -rf amiberry-$VER && tar xzf amiberry-$VER.tar.gz && cd amiberry-$VER
# 8.3.0's non-OpenGL renderer names an SDL3 type that does not exist (the
# OpenGL build never compiles this file, so upstream did not notice).
sed -i 's/\bSDL_LogicalPresentation lmode/SDL_RendererLogicalPresentation lmode/' src/osdep/sdl_renderer.cpp
# The K4510's picture placement (K4510_PLACEMENT=left, K4510_SCALE=integer).
python3 /tools/patches/amiberry/apply.py
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DUSE_OPENGL=OFF -DUSE_PCEM=OFF -DUSE_PPC=OFF -DUSE_QEMU_PPC=OFF \
    -DUSE_UAENET_PCAP=OFF -DUSE_UAENET_TAP=OFF -DUSE_IPC_SOCKET=OFF \
    -DUSE_LIBENET=OFF -DUSE_PORTMIDI=OFF -DUSE_LIBSERIALPORT=OFF >/work/amiberry-cmake.log
cmake --build build >/work/amiberry-make.log 2>&1
rm -rf /work/stage/amiga && DESTDIR=/work/stage/amiga cmake --install build >/work/amiberry-install.log
find /work/stage/amiga -maxdepth 4 | head -30
