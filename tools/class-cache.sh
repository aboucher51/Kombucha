#!/usr/bin/env bash
# Re-imports the project when Godot's class cache is stale.
#
#   tools/class-cache.sh            prints nothing when the cache matches
#   tools/class-cache.sh --report   also prints an "ok" line (check.sh)
#
# Godot keeps the list of class_name scripts in
# .godot/global_script_class_cache.cfg. A headless run reads that list and
# never rebuilds it. After a pull that adds, renames or moves a class_name
# script, or in a fresh worktree with no .godot/ at all, the list is wrong.
# Every run then fails with parse errors ("Identifier Cmdline not
# declared") though the code is fine. One project's cache on a server was
# a week old and listed no classes, and a red gate in a worktree with no
# import left three served engines running for 3 hours.
#
# So this compares the (class, path) pairs in the cache with the
# class_name lines on disk, and imports when they differ. It skips what
# the engine skips: hidden files and folders, folders with a .gdignore,
# and a folder holding another project.godot. It walks the disk, not git,
# because the engine sees untracked and ignored files too. check.sh,
# test.sh and shoot.sh call it before their first engine starts.
#
# Exit 0 when the cache matches (or matches after the import), 1 when it
# still differs. A caller never fails on 1: its own run says whether the
# code is broken, and a difference that survives an import means this
# comparison missed an engine rule.
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt); do not edit in a project.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
GODOT="${GODOT:-godot4}"
REPORT=0
[[ "${1:-}" == "--report" ]] && REPORT=1

on_disk() {
	local skip
	skip="$(find . -mindepth 2 \( -name .gdignore -o -name project.godot \) -not -path '*/.*/*' 2>/dev/null | sed 's#/[^/]*$#/#')"
	find . -mindepth 1 -name '.*' -prune -o -type f -name '*.gd' -print0 2>/dev/null \
		| { if [[ -n "$skip" ]]; then grep -zv -F -f <(printf '%s\n' "$skip"); else cat; fi; } \
		| xargs -0 -r awk '
			FNR == 1 { found = 0 }
			!found && match($0, /^(@[a-z_]+[ \t]+)*class_name[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
				n = split(substr($0, RSTART, RLENGTH), w, /[ \t]+/)
				f = FILENAME; sub(/^\.\//, "", f)
				print w[n] "\t" f
				found = 1
			}' | sort
}
in_cache() {
	[[ -f .godot/global_script_class_cache.cfg ]] || return 0
	grep -oE '"class": &"[A-Za-z0-9_]+"|"path": "res://[^"]+"' .godot/global_script_class_cache.cfg \
		| sed -E 's/"class": &"([^"]+)"/\1/; s#"path": "res://([^"]+)"#\1#' | paste - - | sort
}

DIFF="$(diff <(in_cache) <(on_disk))"
if [[ -z "$DIFF" ]]; then
	[[ $REPORT -eq 1 ]] && printf '  ok    class cache matches the class_name scripts (%s classes)\n' "$(on_disk | grep -c .)"
	exit 0
fi
if [[ -f .godot/global_script_class_cache.cfg ]]; then
	printf 'note: %s line(s) of the class cache differ from the class_name scripts on disk. Re-importing the project.\n' \
		"$(grep -c '^[<>]' <<<"$DIFF")"
else
	printf 'note: this checkout has no class cache yet. Importing the project.\n'
fi
# The import can rewrite project.godot (one project lost a setting on
# every import), so say so when a clean file came out changed.
WAS_CLEAN=0
git diff --quiet -- project.godot 2>/dev/null && WAS_CLEAN=1
mkdir -p .godot
"$GODOT" --headless --path . --import > .godot/class-cache-import.log 2>&1
STATUS=$?
if [[ $WAS_CLEAN -eq 1 ]] && ! git diff --quiet -- project.godot 2>/dev/null; then
	printf 'note: the import changed project.godot. Check git diff project.godot before you commit.\n'
fi
DIFF="$(diff <(in_cache) <(on_disk))"
if [[ -z "$DIFF" ]]; then
	[[ $REPORT -eq 1 ]] && printf '  ok    class cache re-imported (%s classes)\n' "$(on_disk | grep -c .)"
	exit 0
fi
printf '  --    class cache still differs after the import (exit %s, log in .godot/class-cache-import.log). < is the cache, > is the disk:\n' "$STATUS"
printf '%s\n' "$DIFF" | grep '^[<>]' | head -10 | sed 's/^/        /'
exit 1
