#!/bin/sh
# Dir Browser (Francesco Gramignani "Graham", 2025; https://graham-it.itch.io/dirbrowser,
# https://github.com/graham-it/DirBrowser): the file browser on the C64's and
# the C128's SD volume, drive 9.  Its builds for VICE (its "vice" folder:
# the "root" command speaks VICE's virtual filesystem) into work/dirbrowser;
# make-images.sh puts them in the VICE image, and the run script copies them
# onto the SD volume as DB64 and DB128.  Its terms allow downloading from its
# own sites, not redistribution: so it is fetched here, never kept in this
# repository.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); D=$HERE/work/dirbrowser
rm -rf "$D.src"; git clone -q --depth 1 https://github.com/graham-it/DirBrowser.git "$D.src"
mkdir -p "$D"; cp "$D.src/vice/db64" "$D/DB64"; cp "$D.src/vice/db128" "$D/DB128"; cp "$D.src/README.md" "$D/README.md"
rm -rf "$D.src"; ls -l "$D"
