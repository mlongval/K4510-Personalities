#!/bin/sh
# Attack of the PETSCII Robots -- the free shareware editions only, from the
# 8-Bit Guy's own shareware page
# (https://www.the8bitguy.com/25753/petscii-robot-shareware-available/),
# one for each personality we have.  Into work/robots/zip; make-images.sh
# puts them where each machine's file browser starts.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); Z=$HERE/work/robots/zip
mkdir -p "$Z"; cd "$Z"
U=https://www.the8bitguy.com/wp-content/uploads
for f in 2022/06/C64-Robots-Shareware-06-04-2022.zip 2022/07/C64-REU-Shareware-07-07-2022.zip \
         2022/07/C128-shareware-07-07-2022.zip 2022/03/Pet-Robots-Shareware-03-29-2022.zip \
         2022/03/Amiga-Robots-Shareware-03-22-2022.zip 2024/12/X16Robots-12-19-2024.zip; do
    [ -f "$(basename $f)" ] || curl -fsSL -A "Mozilla/5.0" -O "$U/$f"
done
ls -l "$Z"
