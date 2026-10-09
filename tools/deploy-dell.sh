#!/bin/sh
# Put the personalities on a K4510 machine's SAVED partition (p4), from here.
# Run with the machine booted into the K4510 (its Linux, not Fedora):
#
#   tools/deploy-dell.sh [user@host]       (default: DEPLOY_HOST in local.cfg)
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
HOST=${1:-${DEPLOY_HOST:?give user@host, or set DEPLOY_HOST in local.cfg}}
OUT=$HERE/work/out
[ -f "$OUT/personalities/vice.squashfs" ] || { echo "no images: tools/make-images.sh first"; exit 1; }
tar -C "$OUT" -cf - personalities home | ssh "$HOST" '
    set -e; T=$(mktemp -d); tar -C $T -xf -
    P=; for d in /run/live/persistence/*; do [ -w "$d" ] || sudo -n test -d "$d/home" && { P=$d; break; }; done
    [ -n "$P" ] || { echo "no persistence partition mounted: is this the K4510 side?"; exit 1; }
    sudo -n mkdir -p "$P/personalities"
    for f in $T/personalities/*; do b=$(basename $f)
        [ -f "$P/personalities/$b" ] && sudo -n cp -p "$P/personalities/$b" "$P/personalities/$b.prev"
        sudo -n cp "$f" "$P/personalities/$b.tmp" && sudo -n mv "$P/personalities/$b.tmp" "$P/personalities/$b"
    done
    mkdir -p ~/personalities && cp -rn $T/home/personalities/. ~/personalities/
    sync; rm -rf $T
    echo "on $(hostname): $P/personalities:"; ls -la "$P/personalities"; du -sh ~/personalities/*'
