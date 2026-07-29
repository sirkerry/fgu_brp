#!/usr/bin/env bash
# Restore live extension from a backup snapshot or from extension/ baseline.
# Usage: ./restore.sh [backup-timestamp|baseline]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FGDATA="${FGDATA:-$HOME/.smiteworks/fgdata}"
LIVE="$FGDATA/extensions/brp-effects"
SOURCE="${1:-}"

if [ -z "$SOURCE" ] || [ "$SOURCE" = "baseline" ]; then
	SRC="$REPO/extension"
elif [ -d "$REPO/backups/$SOURCE" ]; then
	SRC="$REPO/backups/$SOURCE"
else
	echo "error: unknown source '$SOURCE'" >&2
	echo "Use: baseline, or a timestamp from backups/" >&2
	ls -1 "$REPO/backups" 2>/dev/null || true
	exit 1
fi

mkdir -p "$LIVE"
rsync -a --delete "$SRC/" "$LIVE/"
echo "Restored $SRC -> $LIVE"
