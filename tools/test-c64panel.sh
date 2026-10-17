#!/bin/sh
# The C64's own sidebar (tools/patches/vice/k4510c64.c), driven by the mouse
# under Xvfb and checked in VICE's log -- no pictures taken -- started by
# run/vice as the machine starts it:
#   DISKS lists ~/personalities/c64, a folder opens, a .D64 goes in drive 8,
#   a program in its directory is loaded and run, EJECT takes the disk out,
#   BROWSE runs Dir Browser from the SD volume;
#   and the rest of run/vice: the symbolic keymap, the 16 MB REU, the SD
#   volume as drive 9 (BASIC writes a file there) and the KERNAL's colours
#   (white on dark blue: BASIC PEEKs them into that file).
#   Then the C128: its panel above the other screen.
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
ln -s $V/run/vice /tmp/c64; ln -s $V/run/vice /tmp/c128
stdbuf -oL /tmp/c64 -sounddev dummy +VICIIfull -keybuf "open1,9,1,\"cols\":print#1,peek(646);peek(53281)and15;peek(53280)and15:close1\n" >~/log 2>&1 &
sleep 5; w=$(xdotool search --name VICE | head -1); xdotool windowmove $w 0 0 windowsize $w 1920 1080
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do grep -q "k4510c64: the panel" ~/log && break; sleep 1; done; sleep 2
set -- $(sed -n "s/.*k4510c64: the panel at \([0-9]*\),\([0-9]*\), \([0-9]*\)x\([0-9]*\) machine pixels x\([0-9]*\).*/\1 \2 \3 \4 \5/p" ~/log | tail -1)
[ -n "$5" ] || { cat ~/log; echo "test-c64panel: FAILED: no panel"; exit 1; }
X=$1 Y=$2 H=$4 K=$5 rows=$(($4 / 8))
at() { xdotool mousemove $((X + ($1 * 8 + 4) * K)) $((Y + ($2 * 8 + 4) * K)); sleep 0.3; xdotool click 1; sleep ${3:-1}; }
fail() { cat ~/log; echo "test-c64panel: FAILED: $1"; exit 1; }
grep -q "sdl_sym.vkm" ~/log || fail "not the symbolic keymap"
grep -q "REU.*16384" ~/log || grep -qi "reu.*16 *MB\|16384KiB\|16384 *kB" ~/log || { grep -i reu ~/log; fail "no 16 MB REU"; }
sleep 3; ls -la ~/personalities/SD
c=$(cat ~/personalities/SD/cols* 2>/dev/null | tr -d "\r\000")
echo "colours: $c"
[ "$(echo $c)" = "1 6 6" ] || fail "the KERNAL colours (646, 53281, 53280) are not 1 6 6, or BASIC did not write to drive 9"
B=$((rows - 14))                                      # DISKS and EJECT: above the 11 keys
at 2 $B                                               # DISKS
grep -q "k4510c64: disks in /home/k4510/personalities/c64, 2" ~/log || fail "DISKS did not list the two folders"
at 2 13                                               # GAMES/ (folders in order: DEMOS, GAMES)
at 2 13                                               # TEST.D64 (after ^ UP)
grep -q "k4510c64: drive 8: /home/k4510/personalities/c64/GAMES/TEST.D64" ~/log || fail "the disk did not go in"
at 2 13 5                                             # "SECOND", the second program
grep -q "k4510c64: .*TEST.D64, program 2: load and run" ~/log || fail "a click on the directory did not run its program"
grep -q "AUTOSTART: Resetting the machine to autostart .SECOND." ~/log || fail "VICE did not autostart SECOND (the directory shown was not this disk)"
at 10 $B                                              # EJECT (after DISKS)
grep -q "k4510c64: eject" ~/log || fail "EJECT"
at 8 9 4                                              # BROWSE, on the SD row
grep -q "k4510c64: browse: /home/k4510/personalities/SD/DB64" ~/log || fail "BROWSE"
grep -q "AUTOSTART.*DB64\|Loading.*DB64\|db64" ~/log || grep -qi "autostart.*prg" ~/log || fail "Dir Browser did not start"
grep "k4510c64\|AUTOSTART: Resetting" ~/log
# the C128: its panel, above the other screen
pkill -f x64sc 2>/dev/null || kill $(pidof x64sc) 2>/dev/null; sleep 1
stdbuf -oL /tmp/c128 -sounddev dummy +VICIIfull +VDCfull >~/log128 2>&1 &
sleep 6; w=$(xdotool search --name VICE | head -1); xdotool windowmove $w 0 0 windowsize $w 1920 1080
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do grep -q "k4510c64: the panel" ~/log128 && break; sleep 1; done
p=$(grep "k4510c64: the panel" ~/log128 | tail -1); echo "C128: $p"
[ -n "$p" ] || { cat ~/log128; echo "test-c64panel: FAILED: no C128 panel"; exit 1; }
h=$(echo "$p" | sed "s/.*, [0-9]*x\([0-9]*\) machine pixels x\([0-9]*\)/\1 \2/")
set -- $h
[ $(($1 * $2)) -le 930 ] || { echo "test-c64panel: FAILED: the C128 panel takes the whole height ($1 x$2): no room for the other screen"; exit 1; }
[ "$2" -ge 2 ] || { echo "test-c64panel: FAILED: the C128 panel at x1, too small to read"; exit 1; }
# the PET: its panel in its screen colours, following a palette changed while
# it runs (as F12 changes it: the resources, here by the remote monitor)
pkill -f x128 2>/dev/null || kill $(pidof x128) 2>/dev/null; sleep 1
mkdir -p ~/personalities/pet && cp ~/personalities/c64/GAMES/TEST.D64 ~/personalities/pet/
cd ~/personalities/pet
ln -s $V/run/vice /tmp/pet
stdbuf -oL /tmp/pet -sounddev dummy +CRTCfull -remotemonitor -remotemonitoraddress ip4://127.0.0.1:6510 >~/logpet 2>&1 &
sleep 5; w=$(xdotool search --name VICE | head -1); xdotool windowmove $w 0 0 windowsize $w 1920 1080
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do grep -q "k4510c64: the panel" ~/logpet && break; sleep 1; done; sleep 1
set -- $(sed -n "s/.*k4510c64: the panel at \([0-9]*\),\([0-9]*\), \([0-9]*\)x\([0-9]*\) machine pixels x\([0-9]*\).*/\1 \2 \3 \4 \5/p" ~/logpet | tail -1)
[ -n "$5" ] || { cat ~/logpet; echo "test-c64panel: FAILED: no PET panel"; exit 1; }
X=$1 Y=$2 K=$5 rows=$(($4 / 8))
grep "k4510c64: the PET" ~/logpet
first=$(grep -c "k4510c64: the PET.s colours" ~/logpet)
[ "$first" -ge 1 ] || { cat ~/logpet; echo "test-c64panel: FAILED: the PET panel did not read the screen colours"; exit 1; }
B=$((rows - 20))                                      # DISKS: above the 17 keys
at 2 $B                                               # DISKS
at 2 10                                               # TEST.D64
grep -q "k4510c64: drive 8: /home/k4510/personalities/pet/TEST.D64" ~/logpet || { cat ~/logpet; echo "test-c64panel: FAILED: the PET disk"; exit 1; }
python3 -c "
import socket,time
s=socket.create_connection((\"127.0.0.1\",6510)); time.sleep(0.5)
for c in (b\"resourceset \\\"CrtcPaletteFile\\\" \\\"amber\\\"\\n\", b\"resourceset \\\"CrtcExternalPalette\\\" \\\"1\\\"\\n\", b\"x\\n\"):
    s.sendall(c); time.sleep(0.5)
"
sleep 2; grep "k4510c64: the PET" ~/logpet
[ $(grep -c "k4510c64: the PET.s colours" ~/logpet) -gt "$first" ] || { echo "test-c64panel: FAILED: the PET panel did not follow the palette"; exit 1; }
echo "test-c64panel: OK (keymap, REU, KERNAL colours, drive 9; DISKS, a folder, a disk in drive 8, a program run, EJECT, BROWSE; the C128 panel above its other screen; the PET panel in its screen colours, following a new palette, a disk in its drive 8)"
'
