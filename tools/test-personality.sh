#!/bin/sh
# Photograph one personality running on the base stand-in, under Xvfb:
#   tools/test-personality.sh c64 [seconds [args...]]  -> work/shots/c64.jpg
# (args go to the machine, e.g. a disk to autostart; paths under ~ are
# /home/k4510/...)
# The image is unsquashed (rootless podman cannot loop-mount) to the path the
# machine mounts it at; HOME is a copy of work/out/home.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work
name=$1; secs=${2:-8}; shift; [ $# -gt 0 ] && shift
# Xvfb has no mode to switch to: VICE's fullscreen photographs black there
# (on the machine's KMS display the window IS the screen), and no sound card.
case $name in
c64)  extra="-sounddev dummy +VICIIfull" ;;
c128) extra="-sounddev dummy +VICIIfull +VDCfull" ;;
pet)  extra="-sounddev dummy +CRTCfull" ;;
*)    extra="" ;;
esac
shot=${SHOT:-$name}
fam=$(grep -l "^$name	" $W/out/personalities/*.list | xargs basename | sed 's/\.list$//')
mkdir -p $W/shots; rm -rf $W/test-$fam $W/test-home
unsquashfs -q -d $W/test-$fam $W/out/personalities/$fam.squashfs
mkdir -p $W/test-home && cp -a $W/out/home/personalities $W/test-home/
podman run --rm -v $W/test-$fam:/opt/personalities/$fam:ro,Z -v $W/test-home:/home/k4510:Z \
    -v $W/shots:/shots:Z -e HOME=/home/k4510 -e SDL_AUDIODRIVER=dummy k4510-base-test sh -c "

    Xvfb :1 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 1; export DISPLAY=:1
    /opt/personalities/$fam/run/$name $extra \"\$@\" >/shots/$shot.log 2>&1 & sleep $secs
    xwd -root -silent | convert xwd:- -resize 50% -strip /shots/$shot.jpg" sh "$@"   # the args, quoting intact
echo "work/shots/$shot.jpg"
