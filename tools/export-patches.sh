#!/bin/sh
# Export the build-time changes as ordinary unified diffs, one per emulator,
# for anyone who wants them without this repo's build:
#
#   tools/export-patches.sh            -> patches/*.patch (README.md beside them)
#
# Each is made the way the build makes its tree: the release tarball unpacked
# twice, one copy changed exactly as tools/build-*.sh changes it (its sed
# lines, then tools/patches/<emu>/apply.py), and `diff -ruN` between them.
# Apply with:  cd vice-3.10 && patch -p1 < vice-3.10-k4510.patch
# Needs the tarballs in work/ (the build scripts download them).
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work; P=$HERE/tools/patches
OUT=$HERE/patches; mkdir -p "$OUT"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

one() {   # tarball dir patchname -- then the changes, run in the changed copy
    tgz=$1 dir=$2 name=$3; shift 3
    rm -rf "$T/a" "$T/b"; mkdir -p "$T/a" "$T/b"
    tar xzf "$W/$tgz" -C "$T/a"; tar xzf "$W/$tgz" -C "$T/b"
    (cd "$T/b/$dir" && "$@" >/dev/null)
    (cd "$T" && diff -ruN "a/$dir" "b/$dir" > "$OUT/$name") || [ $? -eq 1 ]
    # paths relative to the source tree (patch -p1), and no dates: the same diff every time
    sed -i -e "s#^\(---\|+++\) \([ab]\)/$dir/\([^\t]*\).*#\1 \2/\3#" \
           -e "s#^diff -ruN a/$dir/\([^ ]*\) b/$dir/.*#diff -ruN a/\1 b/\1#" "$OUT/$name"
    echo "$OUT/$name: $(grep -c '^+++ ' "$OUT/$name") files"
}

vice() {
    sed -i 's/if ((log_to_file) || (!log_colorize)) {/if (1) {/' src/log.c
    python3 "$P/vice/apply.py"
}
amiberry() {
    sed -i 's/\bSDL_LogicalPresentation lmode/SDL_RendererLogicalPresentation lmode/' src/osdep/sdl_renderer.cpp
    python3 "$P/amiberry/apply.py"
}
x16() {
    sed -i 's/SDL_WINDOW_FULLSCREEN\b/SDL_WINDOW_FULLSCREEN_DESKTOP/g' src/video.c
    python3 "$P/x16/apply.py"
}
one vice-3.10.tar.gz vice-3.10 vice-3.10-k4510.patch vice
one amiberry-8.3.0.tar.gz amiberry-8.3.0 amiberry-8.3.0-k4510.patch amiberry
one x16-emulator-r49.tar.gz x16-emulator-r49 x16emu-r49-k4510.patch x16
