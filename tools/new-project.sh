#!/usr/bin/env bash
# Scaffolds a new project from this template.
#
#   tools/new-project.sh ../MyGame "My Game"
#
# Copies everything except editor caches and shot output, sets the project
# name, starts a fresh git history, imports, and runs the quick check so the
# new project starts green.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEST="${1:-}"
NAME="${2:-}"
if [[ -z "$DEST" || -z "$NAME" ]]; then
	echo "usage: tools/new-project.sh <destination-dir> <\"Project Name\">" >&2
	exit 2
fi
if [[ -e "$DEST" ]]; then
	echo "new-project: '$DEST' already exists" >&2
	exit 2
fi

mkdir -p "$DEST"
# rsync if present, else tar — either way skip caches, shots, and any .git.
if command -v rsync >/dev/null; then
	rsync -a --exclude '.godot' --exclude 'shots/*.png' --exclude '.git' "$ROOT/" "$DEST/"
else
	(cd "$ROOT" && tar --exclude .godot --exclude 'shots/*.png' --exclude .git -cf - .) | (cd "$DEST" && tar -xf -)
fi

sed -i "s|^config/name=.*|config/name=\"$NAME\"|" "$DEST/project.godot"

cd "$DEST"
git init -q -b main
# Nothing is configured globally on this machine, so a fresh repo has no
# author identity and the scaffold commit below would fail — inherit the
# template repo's.
if ! git config user.email >/dev/null; then
	git config user.name "$(git -C "$ROOT" config user.name)"
	git config user.email "$(git -C "$ROOT" config user.email)"
fi
godot4 --headless --path . --import >/dev/null 2>&1 || true
# The template's committed project map describes the TEMPLATE; for the
# new project it is stale, and check.sh fails on a stale map when the
# tool is here. Regenerate it, or drop it so the check says "no map yet".
if command -v godot-map >/dev/null 2>&1; then
	godot-map . >/dev/null
else
	rm -rf PROJECT_MAP.md .godot-map
fi
tools/check.sh --quick
git add -A
git commit -qm "Scaffold from Template"

echo "new-project: '$NAME' ready at $DEST"
