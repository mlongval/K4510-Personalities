#!/bin/sh
# Assemble the personality images and the user's starting files from what
# build-vice.sh and build-amiberry.sh left in work/stage.
#
#   work/out/personalities/vice.squashfs   x64sc x128 xpet + ROMs + libs
#   work/out/personalities/amiga.squashfs  amiberry + 2 Kickstarts + libs
#   work/out/personalities/x16.squashfs    x16emu + the X16 ROM (r49)
#   work/out/personalities/*.list          name<TAB>title, one per personality
#   work/out/home/personalities/<name>/    floppies, the A1200's DH0 -- these
#                                          go to the disk (p4), never to RAM
#
# Libraries: whatever the binaries need that the K4510x base does not have
# (asked of k4510-base-mimic, built from the K4510 repo's packages.list) is
# copied from the builder into the image's lib/.  Same Debian, same versions.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
W=$HERE/work; OUT=$W/out; IMG=$W/img
EMU=${EMU:-/media/doc/Internal_3TB/Emulation/Amiga}
KS13="$EMU/AmigaStuff/Kickstarts/Kickstart 1.3 (34.5) (A500-A2500-A3000-CDTV) (Commodore) (1987)[!].rom"
KS31="/media/doc/Internal_2TB/User_Storage/Mike/Copied from KDE machine/Documents/Amiga/Kickstarts/Kickstart-v3.1-rev-40.68-1993-Commodore-A1200.rom"
WB="$EMU/Workbench"
GAMES="/media/doc/Internal_2TB/User_Storage/Mike/Copied from KDE machine/Documents/Amiga/Floppies"
rm -rf "$IMG" "$OUT"; mkdir -p "$IMG" "$OUT/personalities" "$OUT/home/personalities"

# --- vice: only the three machines, their data, and the disk tools
V=$IMG/vice; S=$W/stage/vice/opt/personalities/vice
mkdir -p $V/bin $V/share/vice $V/lib $V/run
cp $S/bin/x64sc $S/bin/x128 $S/bin/xpet $S/bin/c1541 $S/bin/petcat $V/bin/
for d in C64 C128 PET DRIVES PRINTER common hotkeys; do [ -d $S/share/vice/$d ] && cp -a $S/share/vice/$d $V/share/vice/; done
cp "$HERE/machine/vice/run" $V/run/vice; cp "$HERE/machine/vice/list" $V/list

# --- amiga
A=$IMG/amiga; S=$W/stage/amiga/opt/personalities/amiga
mkdir -p $A/kickstarts $A/run $A/conf
cp -a $S/bin $S/lib $S/share $A/
cp "$KS13" $A/kickstarts/kick13-a500.rom; cp "$KS31" $A/kickstarts/kick31-a1200.rom
cp "$HERE/machine/amiga/run" $A/run/amiga; cp "$HERE/machine/amiga/conf/"*.uae $A/conf/
cp "$HERE/machine/amiga/list" $A/list

# --- x16
X=$IMG/x16; S=$W/stage/x16
mkdir -p $X/bin $X/lib $X/run
cp $S/bin/x16emu $X/bin/; cp $S/rom.bin $X/
cp "$HERE/machine/x16/run" $X/run/x16; cp "$HERE/machine/x16/list" $X/list

for fam in vice amiga; do
    for n in $(cut -f1 $IMG/$fam/list); do ln -s $fam $IMG/$fam/run/$n; done
done

# strip, bundle the missing libraries (until nothing is missing), squash
podman run --rm -v "$W:/work:Z" personalities-builder sh -c '
    find /work/img -type f \( -path "*/bin/*" -o -name "*.so*" \) -exec sh -c "file -b \"\$1\" | grep -q ELF && strip --strip-unneeded \"\$1\"" _ {} \;'
for fam in vice amiga x16; do
    for pass in 1 2 3 4 5; do
        missing=$(podman run --rm -v "$IMG/$fam:/opt/personalities/$fam:ro,Z" k4510-base-mimic sh -c "
            export LD_LIBRARY_PATH=/opt/personalities/$fam/lib:/opt/personalities/$fam/lib/amiberry
            find /opt/personalities/$fam -type f \( -path '*/bin/*' -o -name '*.so*' \) | while read f; do ldd \"\$f\" 2>/dev/null; done" \
            | awk '/not found/{print $1}' | sort -u)
        missing=$(echo $missing); [ -n "$missing" ] || break
        echo "$fam pass $pass: bundling $(echo $missing | wc -w) libraries"
        podman run --rm -v "$IMG/$fam:/img:Z" personalities-builder sh -c "
            for l in $missing; do p=\$(ldconfig -p | awk -v l=\$l '\$1==l && /x86-64/{print \$NF; exit}');
              [ -n \"\$p\" ] && cp -L \"\$p\" /img/lib/ && strip --strip-unneeded /img/lib/\$l || echo \"  NOT IN BUILDER: \$l\"; done"
    done
    [ -z "$missing" ] || { echo "$fam: still missing: $missing"; exit 1; }
    cp $IMG/$fam/list "$OUT/personalities/$fam.list"
    mksquashfs $IMG/$fam "$OUT/personalities/$fam.squashfs" -comp zstd -Xcompression-level 19 \
        -all-root -noappend -quiet
    echo "$fam.squashfs: $(du -h "$OUT/personalities/$fam.squashfs" | cut -f1)"
done

# --- the user's starting files (the disk, not RAM)
H=$OUT/home/personalities
mkdir -p $H/c64 $H/c128 $H/pet $H/x16 $H/a500/floppies $H/a1200/floppies
cp "$WB"/amiga-os-134-*.adf $H/a500/floppies/
cp "$GAMES"/*.adf $H/a500/floppies/ 2>/dev/null || true
rm -f $H/a500/floppies/wb31-*.adf $H/a500/floppies/EmergencyBootFloppy.adf
cp "$WB"/amiga-os-310-*.adf $H/a1200/floppies/
# Workbench 3.1 on the A1200's hard drive: the six disks unpacked into one
# directory, the way an install by hand copies them.  Every file executable
# on the host, or Amiberry marks it not executable (the 'e' bit) for AmigaDOS.
podman run --rm -v "$H/a1200:/h:Z" personalities-builder sh -c '
    set -e; t=$(mktemp -d); cd $t
    for d in workbench extras fonts locale storage; do mkdir $t/$d; unadf /h/floppies/amiga-os-310-$d.adf -d $t/$d >/dev/null 2>&1; done
    mkdir -p /h/DH0
    cp -a $t/workbench/. /h/DH0/
    cp -an $t/extras/. /h/DH0/
    mkdir -p /h/DH0/Fonts /h/DH0/Locale /h/DH0/Storage
    cp -an $t/fonts/. /h/DH0/Fonts/; cp -an $t/locale/. /h/DH0/Locale/; cp -an $t/storage/. /h/DH0/Storage/
    chmod -R a+rx,u+w /h/DH0'
du -sh $H/*
