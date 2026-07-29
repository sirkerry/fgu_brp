#!/usr/bin/env bash
# After a dev session: copy live extension back into git-tracked extension/ for commit.
# Run ./backup.sh first if you want a timestamped archive as well.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FGDATA="${FGDATA:-$HOME/.smiteworks/fgdata}"
LIVE="$FGDATA/extensions/brp-effects"
DEST="$REPO/extension"

if [ ! -d "$LIVE" ]; then
	echo "error: live extension not found at $LIVE" >&2
	exit 1
fi

rsync -a --delete "$LIVE/" "$DEST/"
echo "Synced $LIVE -> $DEST"
