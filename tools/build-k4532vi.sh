#!/bin/sh
# The K4532 vi-ui personality's image (machine/k4532vi/run says what it
# is): the K32 programs that K4532's branch vi-ui changed, laid over the
# machine's own disk at every start.  From a checkout of that branch,
# built there (its own `make`):
#
#   tools/build-k4532vi.sh [K4532 checkout of vi-ui]
#   tools/deploy-dell.sh --only k4532vi
#
# Default checkout: ~/Projects/K4532/.claude/worktrees/vi-ui.  What goes in
# is every file under fs/ that differs from main there.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd); W=$HERE/work
B=${1:-$HOME/Projects/K4532/.claude/worktrees/vi-ui}
[ "$(git -C "$B" rev-parse --abbrev-ref HEAD)" = vi-ui ] || { echo "build-k4532vi.sh: $B is not on vi-ui"; exit 1; }
I=$W/img/k4532vi; OUT=$W/out/personalities
rm -rf "$I"; mkdir -p "$I/run" "$I/fs" "$OUT"
git -C "$B" diff --name-only main -- fs | while read -r f; do
    [ -f "$B/$f" ] || continue
    mkdir -p "$I/${f%/*}"; cp "$B/$f" "$I/$f"
done
cp "$HERE/machine/k4532vi/run" "$I/run/k4532vi"; cp "$HERE/machine/k4532vi/list" "$I/list"
printf 'vi-ui %s (%s)\n' "$(git -C "$B" rev-parse --short=7 HEAD)" "$(git -C "$B" log -1 --format='%cs %s' | cut -c1-60)" > "$I/VERSION"
rm -f "$OUT/k4532vi.squashfs"
mksquashfs "$I" "$OUT/k4532vi.squashfs" -all-root -noappend -quiet
cp "$I/list" "$OUT/k4532vi.list"
cat "$I/VERSION"; (cd "$I" && find fs -type f); du -h "$OUT/k4532vi.squashfs"
