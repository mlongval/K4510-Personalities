#!/bin/sh
# Put the personalities on a K4510 machine's SAVED partition (p4), from here.
# Run with the machine booted into the K4510 (its Linux, not Fedora):
#
#   tools/deploy-dell.sh [-n] [--only FAM[,FAM...]] [user@host]
#                                          (default: DEPLOY_HOST in local.cfg)
#   -n          a dry run: list what would be copied, and where; no ssh
#   --only FAM  only those families' images (e.g. --only k4532), and only
#               their names' starting files
#
#   images  -> /run/live/persistence/<p4>/personalities/   (root's; the old
#              ones kept as *.prev for one rollback)
#   files   -> ~/personalities/<name>/ (floppies, the A1200's DH0); anything
#              already there is kept, never overwritten
# Touches nothing in RAM, the layer, or GRUB, and reboots nothing.  The
# Personality Chooser (k4510-chooser, k4510-session) and k4510-personality come
# with the K4510 repo's layer; a new family shows in the Chooser as soon as its
# .list is here.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$HERE/local.cfg" ] && . "$HERE/local.cfg"
DRY=; ONLY=
while [ $# -gt 0 ]; do case $1 in
    -n|--dry-run) DRY=1; shift ;;
    --only) ONLY=$(echo "$2" | tr , ' '); shift 2 ;;
    *) break ;;
esac; done
HOST=${1:-${DEPLOY_HOST:?give user@host, or set DEPLOY_HOST in local.cfg}}
OUT=$HERE/work/out
if [ -n "$ONLY" ]; then
    set --
    for fam in $ONLY; do
        [ -f "$OUT/personalities/$fam.squashfs" ] || { echo "no $fam image: tools/make-images.sh $fam first"; exit 1; }
        set -- "$@" personalities/$fam.squashfs personalities/$fam.list
        for n in $(cut -f1 "$OUT/personalities/$fam.list"); do
            [ -d "$OUT/home/personalities/$n" ] && set -- "$@" home/personalities/$n
        done
    done
else
    [ -f "$OUT/personalities/vice.squashfs" ] || { echo "no images: tools/make-images.sh first"; exit 1; }
    set -- personalities home
fi
if [ -n "$DRY" ]; then
    echo "deploy-dell.sh -n: to $HOST, nothing sent"
    (cd "$OUT" && for p in "$@"; do find "$p" -type f -o -type l; done) | sort | while read -r f; do
        case $f in
        personalities/*) echo "  $f ($(du -h "$OUT/$f" | cut -f1)) -> <p4>/personalities/${f#personalities/}  (one already there kept as .prev)" ;;
        home/*)          echo "  $f -> ~/${f#home/}  (only if not there already)" ;;
        esac
    done
    exit 0
fi
tar -C "$OUT" -cf - "$@" | ssh "$HOST" '
    set -e; T=$(mktemp -d); tar -C $T -xf -
    P=; for d in /run/live/persistence/*; do [ -w "$d" ] || sudo -n test -d "$d/home" && { P=$d; break; }; done
    [ -n "$P" ] || { echo "no persistence partition mounted: is this the K4510 side?"; exit 1; }
    sudo -n mkdir -p "$P/personalities"
    for f in $T/personalities/*; do [ -f "$f" ] || continue; b=$(basename $f)
        [ -f "$P/personalities/$b" ] && sudo -n cp -p "$P/personalities/$b" "$P/personalities/$b.prev"
        sudo -n cp "$f" "$P/personalities/$b.tmp" && sudo -n mv "$P/personalities/$b.tmp" "$P/personalities/$b"
    done
    mkdir -p ~/personalities && { [ ! -d $T/home/personalities ] || cp -rn $T/home/personalities/. ~/personalities/; }
    sync; rm -rf $T
    echo "on $(hostname): $P/personalities:"; ls -la "$P/personalities"; du -sh ~/personalities/*'
