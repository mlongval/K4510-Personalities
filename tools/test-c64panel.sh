#!/bin/sh
# The C64's own sidebar (tools/patches/vice/k4510c64.c), driven by the mouse
# under Xvfb and checked in VICE's log -- no pictures taken:
#   DISKS lists ~/personalities/c64, a folder opens, a .D64 goes in drive 8,
#   a program in its directory is loaded and run, EJECT takes the disk out.
#   tools/test-c64panel.sh      (after tools/make-images.sh vice)
# Needs the image k4510-base-xdo: k4510-base-test with xdotool added
# (FROM localhost/k4510-base-test; apt-get install xdotool).
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work
rm -rf $W/test-vice $W/test-c64home
unsquashfs -q -d $W/test-vice $W/out/personalities/vice.squashfs
mkdir -p $W/test-c64home/personalities/c64/GAMES $W/test-c64home/personalities/c64/DEMOS
# 10 PRINT"HI", twice on a disk
printf '\001\010\013\010\012\000\231\042\110\111\042\000\000\000' > $W/test-c64home/hi.prg
podman run --rm -v $W/test-vice:/opt/personalities/vice:ro,Z -v $W/test-c64home:/home/k4510:Z \
    -e HOME=/home/k4510 -e SDL_AUDIODRIVER=dummy -e K4510_PLACEMENT=left k4510-base-xdo sh -c '
V=/opt/personalities/vice; export LD_LIBRARY_PATH=$V/lib
cd ~ && $V/bin/c1541 -format "panel test,01" d64 personalities/c64/GAMES/TEST.D64 -write hi.prg hi -write hi.prg second >/dev/null
Xvfb :1 -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 1; export DISPLAY=:1
cd ~/personalities/c64
# windowed, then made as large as the screen: under Xvfb (no window manager) a
# fullscreen SDL window is 1x1 and gets no clicks
stdbuf -oL $V/bin/x64sc -sounddev dummy +VICIIfull >~/log 2>&1 &
sleep 5; w=$(xdotool search --name VICE | head -1); xdotool windowmove $w 0 0 windowsize $w 1920 1080
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do grep -q "k4510c64: the panel" ~/log && break; sleep 1; done; sleep 2
set -- $(sed -n "s/.*k4510c64: the panel at \([0-9]*\),\([0-9]*\), \([0-9]*\)x\([0-9]*\) machine pixels x\([0-9]*\).*/\1 \2 \3 \4 \5/p" ~/log | tail -1)
[ -n "$5" ] || { cat ~/log; echo "test-c64panel: FAILED: no panel"; exit 1; }
X=$1 Y=$2 H=$4 K=$5 rows=$(($4 / 8))
at() { xdotool mousemove $((X + ($1 * 8 + 4) * K)) $((Y + ($2 * 8 + 4) * K)); sleep 0.3; xdotool click 1; sleep ${3:-1}; }
fail() { cat ~/log; echo "test-c64panel: FAILED: $1"; exit 1; }
at 2 $((rows - 15))                                   # DISKS
grep -q "k4510c64: disks in /home/k4510/personalities/c64, 2" ~/log || fail "DISKS did not list the two folders"
at 2 11                                               # GAMES/ (folders in order: DEMOS, GAMES)
at 2 11                                               # TEST.D64 (after ^ UP)
grep -q "k4510c64: drive 8: /home/k4510/personalities/c64/GAMES/TEST.D64" ~/log || fail "the disk did not go in"
at 2 11 5                                             # "SECOND", the second program
grep -q "k4510c64: .*TEST.D64, program 2: load and run" ~/log || fail "a click on the directory did not run its program"
grep -q "AUTOSTART: Resetting the machine to autostart .SECOND." ~/log || fail "VICE did not autostart SECOND (the directory shown was not this disk)"
at 10 $((rows - 15))                                  # EJECT (after DISKS)
grep -q "k4510c64: eject" ~/log || fail "EJECT"
grep "k4510c64\|AUTOSTART: Resetting" ~/log
echo "test-c64panel: OK (DISKS, a folder, a disk in drive 8, a program run, EJECT)"
'
