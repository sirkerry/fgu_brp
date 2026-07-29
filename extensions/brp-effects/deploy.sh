#!/usr/bin/env bash
# Deploy git-tracked extension/ to the live FGU extensions folder (no .pak, no symlink).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FGDATA="${FGDATA:-$HOME/.smiteworks/fgdata}"
LIVE="$FGDATA/extensions/brp-effects"
SRC="$REPO/extension"

if [ ! -d "$SRC" ]; then
	echo "error: $SRC not found" >&2
	exit 1
fi

mkdir -p "$LIVE"
rsync -a "$SRC/" "$LIVE/"

echo "Deployed to $LIVE"
du -sh "$LIVE"
