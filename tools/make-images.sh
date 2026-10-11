#!/bin/sh
# Assemble the personality images and the user's starting files from what
# build-vice.sh and build-amiberry.sh left in work/stage.
#
#   work/out/personalities/vice.squashfs   x64sc x128 xpet + ROMs + libs
#   work/out/personalities/amiga.squashfs  amiberry + 2 Kickstarts + libs
#   work/out/personalities/x16.squashfs    x16emu + the X16 ROM (r49)
#   work/out/personalities/k4532.squashfs  the K4532 emulator, K/OS ROM, its disk
#                                          (tools/build-k4532.sh stages it)
#   work/out/personalities/*.list          name<TAB>title, one per personality
#   work/out/home/personalities/<name>/    floppies, the A1200's DH0 -- these
#                                          go to the disk (p4), never to RAM
#
# Libraries: whatever the binaries need that the K4510x base does not have
# (asked of k4510-base-mimic, built from the K4510 repo's packages.list) is
# copied from the builder into the image's lib/.  Same Debian, same versions.
#
#   tools/make-images.sh             every family (and the starting files);
#                                    k4532 too once build-k4532.sh has run
#   tools/make-images.sh k4532 ...   only those images: the others, and
#                                    work/out/home, stay as they are
set -e
FAMS="$*"
want() { [ -z "$FAMS" ] || case " $FAMS " in *" $1 "*) ;; *) return 1 ;; esac; }
HERE=$(cd "$(dirname "$0")/.." && pwd)
W=$HERE/work; OUT=$W/out; IMG=$W/img
# Your own Amiga files -- Kickstart ROMs are not ours to give away -- named in
# local.cfg (see local.cfg.example), or in the environment.
[ -f "$HERE/local.cfg" ] && . "$HERE/local.cfg"
KS13=${KS13:-$HOME/Amiga/kick13-a500.rom}          # Kickstart 1.3 (34.5), A500
KS31=${KS31:-$HOME/Amiga/kick31-a1200.rom}         # Kickstart 3.1 (40.68), A1200
WB=${WB:-$HOME/Amiga/Workbench}                    # amiga-os-134-*.adf, amiga-os-310-*.adf
GAMES=${GAMES:-$HOME/Amiga/Floppies}               # optional: more .adf for the A500
if want amiga; then
    for f in "$KS13" "$KS31" "$WB"; do [ -e "$f" ] || { echo "make-images.sh: missing $f (set it in local.cfg)"; exit 1; }; done
fi
if [ -z "$FAMS" ]; then
    FAMS="vice amiga x16"
    if [ -d $W/stage/k4532 ]; then FAMS="$FAMS k4532"; else echo "make-images.sh: no work/stage/k4532 (tools/build-k4532.sh), no k4532 image"; fi
    rm -rf "$IMG" "$OUT"; ALL=1
else
    for fam in $FAMS; do rm -rf "$IMG/$fam" "$OUT/personalities/$fam".*; done; ALL=
fi
mkdir -p "$IMG" "$OUT/personalities" "$OUT/home/personalities"

# --- vice: only the three machines, their data, and the disk tools
if want vice; then
V=$IMG/vice; S=$W/stage/vice/opt/personalities/vice
mkdir -p $V/bin $V/share/vice $V/lib $V/run
cp $S/bin/x64sc $S/bin/x128 $S/bin/xpet $S/bin/c1541 $S/bin/petcat $V/bin/
for d in C64 C128 PET DRIVES PRINTER common hotkeys; do [ -d $S/share/vice/$d ] && cp -a $S/share/vice/$d $V/share/vice/; done
cp "$HERE/machine/vice/run" $V/run/vice; cp "$HERE/machine/vice/list" $V/list
fi

# --- amiga
if want amiga; then
A=$IMG/amiga; S=$W/stage/amiga/opt/personalities/amiga
mkdir -p $A/kickstarts $A/run $A/conf
cp -a $S/bin $S/lib $S/share $A/
cp "$KS13" $A/kickstarts/kick13-a500.rom; cp "$KS31" $A/kickstarts/kick31-a1200.rom
cp "$HERE/machine/amiga/run" $A/run/amiga; cp "$HERE/machine/amiga/conf/"*.uae $A/conf/
cp "$HERE/machine/amiga/list" $A/list
fi

# --- x16
if want x16; then
X=$IMG/x16; S=$W/stage/x16
mkdir -p $X/bin $X/lib $X/run
cp $S/bin/x16emu $X/bin/; cp $S/rom.bin $X/
cp "$HERE/machine/x16/run" $X/run/x16; cp "$HERE/machine/x16/list" $X/list
fi

# --- k4532: the K4532 emulator, K/OS's ROM and fonts, the disk it starts
# from (fs/, with fs.sha256 for run/k4532's copying), the Tube's BASIC
if want k4532; then
K=$IMG/k4532; S=$W/stage/k4532
[ -d $S ] || { echo "make-images.sh: no work/stage/k4532: tools/build-k4532.sh first"; exit 1; }
mkdir -p $K/lib $K/run
cp -a $S/. $K/
cp "$HERE/machine/k4532/run" $K/run/k4532; cp "$HERE/machine/k4532/list" $K/list
fi

for fam in vice amiga; do
    want $fam || continue
    for n in $(cut -f1 $IMG/$fam/list); do ln -s $fam $IMG/$fam/run/$n; done
done

# strip, bundle the missing libraries (until nothing is missing), squash
podman run --rm -v "$W:/work:Z" personalities-builder sh -c '
    cd /work/img && find '"$FAMS"' -type f \( -path "*/bin/*" -o -name "*.so*" \) -exec sh -c "file -b \"\$1\" | grep -q ELF && strip --strip-unneeded \"\$1\"" _ {} \;'
for fam in $FAMS; do
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

# --- the user's starting files (the disk, not RAM): a whole run only (the
# K4532's disk is in its image; run/k4532 copies it)
[ -n "$ALL" ] || exit 0
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

# Where the pictures go, for every personality (the X16's F12 menu changes
# it; deploy-dell.sh never overwrites one already there): left, with the
# K4510's ant farm in the free area -- the C128's other display, on the C128.
printf 'placement=left\nscale=fit\nsidebar=antfarm\n' > $H/display.cfg

# Doc's C64/C128 software, curated (tools/curate-c64.sh -> work/library):
# GAMES DEMOS UTILS LANGUAGES DOCS, where VICE's file browser starts.
if [ -d $W/library ]; then
    cp -a $W/library/c64/. $H/c64/; cp -a $W/library/c128/. $H/c128/
    cp $W/library/MANIFEST.txt $H/c64/MANIFEST.txt
fi

# Attack of the PETSCII Robots, shareware (tools/get-robots.sh): each machine's
# edition where its file browser starts.  The C64 REU edition wants the REU,
# which run/vice turns on for the C64; the PET's wants a 40-column 4032.
R=$W/robots/zip
if [ -d "$R" ]; then
    unz() { python3 - "$@" <<'PY'
import zipfile, sys, os
z, dest = sys.argv[1], sys.argv[2]; os.makedirs(dest, exist_ok=True)
for i in zipfile.ZipFile(z).infolist():
    if i.is_dir() or "__MACOSX" in i.filename: continue
    name = os.path.basename(i.filename)
    if sys.argv[3:] and not any(name.lower().endswith(x) for x in sys.argv[3:]): continue
    open(os.path.join(dest, name), "wb").write(zipfile.ZipFile(z).read(i))
PY
    }
    G="GAMES/PetsciiRobots"
    unz $R/C64-Robots-Shareware-06-04-2022.zip "$H/c64/$G"
    unz $R/C64-REU-Shareware-07-07-2022.zip "$H/c64/$G"
    unz $R/C128-shareware-07-07-2022.zip "$H/c128/$G"
    unz $R/Pet-Robots-Shareware-03-29-2022.zip "$H/pet/$G"
    mv "$H/pet/$G/petrobots-shareware v1.1.d64" "$H/pet/$G/petrobots-shareware-v1.1.d64"
    unz $R/Amiga-Robots-Shareware-03-22-2022.zip "$H/a500/floppies" .adf
    unz $R/Amiga-Robots-Shareware-03-22-2022.zip "$H/a500/manuals" .pdf
    cp $H/a500/floppies/sharewarerobots-*.adf $H/a1200/floppies/
    unz $R/X16Robots-12-19-2024.zip "$H/x16/ROBOTS"
fi
du -sh $H/*
