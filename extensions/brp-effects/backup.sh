#!/usr/bin/env bash
# Snapshot the live FGU extension folder into this extension's backups/ before editing.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FGDATA="${FGDATA:-$HOME/.smiteworks/fgdata}"
LIVE="$FGDATA/extensions/brp-effects"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$REPO/backups/$STAMP"

if [ ! -d "$LIVE" ]; then
	echo "error: live extension not found at $LIVE" >&2
	echo "Run ./deploy.sh first to create it." >&2
	exit 1
fi

mkdir -p "$DEST"
rsync -a --delete "$LIVE/" "$DEST/"
echo "Backed up $LIVE"
echo "  -> $DEST"
echo ""
du -sh "$DEST"
