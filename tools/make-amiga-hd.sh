#!/bin/sh
# The A1200's second hard drive, DH1: "Work", 20 MB, formatted FFS (an
# A590's size), as a hardfile: work/out/home/personalities/a1200/Work.hdf,
# which deploy-dell.sh copies to ~/personalities/a1200 only if none is there
# (so what is on it stays).  Made by amitools' xdftool, in a venv of its own.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work
[ -x $W/amitools/bin/xdftool ] || { python3 -m venv $W/amitools && $W/amitools/bin/pip install -q amitools; }
O=$W/out/home/personalities/a1200; mkdir -p $O
[ -f $O/Work.hdf ] || $W/amitools/bin/xdftool $O/Work.hdf create size=20Mi + format Work ffs
$W/amitools/bin/xdftool $O/Work.hdf info
