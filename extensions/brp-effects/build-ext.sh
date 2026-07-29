#!/usr/bin/env bash
# Package the live extension into a distributable .ext file (a zip with
# extension.xml at its root, not nested in a folder) for FG Forge / manual
# install. forge/ logos stay in the repo only (never live); FG Forge rejects .svg inside .ext.
# Run ./sync-to-repo.sh first if you want the repo mirror updated
# too - this builds straight from the live folder, the source of truth.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FGDATA="${FGDATA:-$HOME/.smiteworks/fgdata}"
LIVE="$FGDATA/extensions/brp-effects"
DIST="$REPO/dist"

if [ ! -d "$LIVE" ]; then
	echo "error: live extension not found at $LIVE" >&2
	exit 1
fi

OUT="$DIST/brp-effects.ext"

mkdir -p "$DIST"
rm -f "$OUT"

( cd "$LIVE" && zip -r -X "$OUT" . -x '.*' -x 'forge/*' -x 'forge/**' -x '*.svg' )

echo "Built $OUT"
unzip -l "$OUT"
