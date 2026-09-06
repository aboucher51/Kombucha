#!/usr/bin/env bash
# Copies the tooling Kombucha owns (tools/tooling-manifest.txt) into a
# project, seeds the project's extension files if absent, stamps the
# Kombucha commit it came from, and runs the project's quick check.
#
#   tools/sync-tooling.sh <project-dir>            sync, then check --quick
#   tools/sync-tooling.sh <project-dir> --check    report drift only, no writes
#   tools/sync-tooling.sh <project-dir> --no-check sync without running check
#
# Run from Kombucha (this script's own repo), or from anywhere via the
# /sync-godot-tooling skill. Drift in an owned file means the project edited
# tooling in place: back the change up to Kombucha first (or move it into
# dev_hooks.gd / check.local.sh), because the sync overwrites it.
set -uo pipefail
GODOT="${GODOT:-godot4}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-}"
MODE="${2:-}"
if [[ -z "$DEST" || ! -f "$DEST/project.godot" ]]; then
	echo "usage: tools/sync-tooling.sh <godot-project-dir> [--check|--no-check]" >&2
	exit 2
fi
DEST="$(cd "$DEST" && pwd)"
if [[ "$DEST" == "$SRC" ]]; then
	echo "sync-tooling: '$DEST' is the source; nothing to sync" >&2
	exit 2
fi

mapfile -t OWNED < <(grep -vE '^\s*(#|$)' "$SRC/tools/tooling-manifest.txt")

# A dirty source would stamp a commit the copied files do not match.
if [[ "$MODE" != "--check" ]] && [[ -n "$(git -C "$SRC" status --porcelain -- "${OWNED[@]}")" ]]; then
	echo "sync-tooling: Kombucha has uncommitted changes to owned files — commit them first" >&2
	exit 2
fi

drift=0
for entry in "${OWNED[@]}"; do
	if [[ "$entry" == */ ]]; then
		if [[ -d "$DEST/$entry" ]]; then
			diff -rq "$SRC/$entry" "$DEST/$entry" >/dev/null 2>&1 || { echo "  drift  $entry"; drift=1; }
		else
			echo "  new    $entry"; drift=1
		fi
	elif [[ -f "$DEST/$entry" ]]; then
		cmp -s "$SRC/$entry" "$DEST/$entry" || { echo "  drift  $entry"; drift=1; }
	else
		echo "  new    $entry"; drift=1
	fi
done
[[ $drift -eq 0 ]] && echo "  same   every owned path matches Kombucha"

if [[ "$MODE" == "--check" ]]; then
	exit $drift
fi

for entry in "${OWNED[@]}"; do
	mkdir -p "$DEST/$(dirname "$entry")"
	if [[ "$entry" == */ ]]; then
		rsync -a --delete "$SRC/$entry" "$DEST/$entry"
	else
		cp -p "$SRC/$entry" "$DEST/$entry"
	fi
done

# The execute bit travels with the copy (cp -p, rsync -a), but a project
# checked out on a mode-blind filesystem may have lost it on its own
# scripts; every tool script must be runnable or check.sh cannot even start.
find "$DEST/tools" -name '*.sh' -exec chmod +x {} +

# Extension files: created once, never overwritten.
seed() { # seed-file, destination
	if [[ ! -e "$DEST/$2" ]]; then
		mkdir -p "$DEST/$(dirname "$2")"
		cp -p "$SRC/tools/seeds/$1" "$DEST/$2"
		echo "  seeded $2"
	fi
}
seed dev_hooks.gd scripts/dev/dev_hooks.gd
seed console_commands.project.json data/console_commands.project.json
seed check.local.sh tools/check.local.sh

{
	git -C "$SRC" rev-parse HEAD
	echo "synced $(date -u +%Y-%m-%dT%H:%M:%SZ) from $SRC"
	echo "Owned paths are in tools/tooling-manifest.txt; refresh with /sync-godot-tooling."
} > "$DEST/tools/TOOLING_VERSION"
echo "sync-tooling: stamped $(head -c 12 "$DEST/tools/TOOLING_VERSION")"

if [[ "$MODE" == "--no-check" ]]; then
	exit 0
fi
cd "$DEST" || exit 2
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
tools/check.sh --quick
