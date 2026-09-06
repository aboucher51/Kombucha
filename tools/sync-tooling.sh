#!/usr/bin/env bash
# Copies the tooling Kombucha owns (tools/tooling-manifest.txt) into a
# project, seeds the project's extension files if absent, stamps the
# Kombucha commit it came from, and runs the project's quick check.
#
#   tools/sync-tooling.sh <project-dir>            sync, then check --quick
#   tools/sync-tooling.sh <project-dir> --check    report drift only, no writes:
#                                                  each drifted file is measured
#                                                  against the Kombucha or
#                                                  Template commit its copy is
#                                                  closest to, so the lines the
#                                                  PROJECT added stand alone
#   tools/sync-tooling.sh <project-dir> --check --diff   ...and print those lines
#   tools/sync-tooling.sh <project-dir> --no-check sync without running check
#   tools/sync-tooling.sh <project-dir> --kit       the KIT report, no writes:
#                                                  for every Template kit file
#                                                  (scripts/autoloads, util,
#                                                  ui) the Template version the
#                                                  project's copy is closest
#                                                  to, its own lines beyond
#                                                  it, and the Template
#                                                  commits since — what there
#                                                  is to cherry-pick. Kit is
#                                                  never synced: games edit it.
#
# Run from Kombucha (this script's own repo), or from anywhere via the
# /sync-godot-tooling skill. Drift in an owned file means the project edited
# tooling in place: back the change up to Kombucha first (or move it into
# dev_hooks.gd / check.local.sh), because the sync overwrites it.
set -uo pipefail
GODOT="${GODOT:-godot4}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-}"
MODE=""
SHOW_DIFF=0
for arg in "${@:2}"; do
	case "$arg" in
		--check|--no-check|--kit) MODE="$arg" ;;
		--diff) SHOW_DIFF=1 ;;
		*) echo "usage: tools/sync-tooling.sh <godot-project-dir> [--check [--diff]|--no-check]" >&2; exit 2 ;;
	esac
done
if [[ -z "$DEST" || ! -f "$DEST/project.godot" ]]; then
	echo "usage: tools/sync-tooling.sh <godot-project-dir> [--check [--diff]|--no-check]" >&2
	exit 2
fi
TEMPLATE="${GODOT_TEMPLATE:-/home/alex/godot-projects/Template}"
DEST="$(cd "$DEST" && pwd)"
if [[ "$DEST" == "$SRC" ]]; then
	echo "sync-tooling: '$DEST' is the source; nothing to sync" >&2
	exit 2
fi

mapfile -t OWNED < <(grep -vE '^\s*(#|$)' "$SRC/tools/tooling-manifest.txt")

# ── the kit report ────────────────────────────────────────────────────────
# Kit (autoloads, util, ui) lives in the Template and travels by
# cherry-pick, because every game edits these files in place. The report
# answers, per file: which Template version is this copy, what did the
# project add, and what has the Template done to the file since.
if [[ "$MODE" == "--kit" ]]; then
	if [[ ! -d "$TEMPLATE/.git" ]]; then
		echo "sync-tooling: no Template at $TEMPLATE (set GODOT_TEMPLATE)" >&2
		exit 2
	fi
	tmp="$(mktemp)"
	behind_total=0
	while read -r file; do
		# owned paths are synced, not cherry-picked
		printf '%s\n' "${OWNED[@]}" | grep -qxF "$file" && continue
		if [[ ! -f "$DEST/$file" ]]; then
			printf '  absent %s\n' "$file"
			continue
		fi
		best=999999; best_ref=""
		while read -r commit; do
			git -C "$TEMPLATE" show "$commit:$file" > "$tmp" 2>/dev/null || continue
			n=$(diff "$tmp" "$DEST/$file" | grep -cE '^[<>]')
			if (( n < best )); then best=$n; best_ref="$commit"; fi
		done < <(git -C "$TEMPLATE" log --format=%H -- "$file")
		[[ -z "$best_ref" ]] && continue
		git -C "$TEMPLATE" show "$best_ref:$file" > "$tmp"
		plus=$(diff "$tmp" "$DEST/$file" | grep -E '^>' | grep -vcE '^>\s*#')
		minus=$(diff "$tmp" "$DEST/$file" | grep -E '^<' | grep -vcE '^<\s*#')
		newer=$(git -C "$TEMPLATE" rev-list --count "$best_ref"..HEAD -- "$file")
		behind_total=$(( behind_total + newer ))
		if (( newer == 0 && plus == 0 && minus == 0 )); then
			printf '  same   %s\n' "$file"
		else
			printf '  kit    %s  at Template@%s, own +%d -%d, %d newer Template commit(s)\n' \
				"$file" "$(git -C "$TEMPLATE" rev-parse --short "$best_ref")" "$plus" "$minus" "$newer"
			git -C "$TEMPLATE" log --format='           %h %ad %s' --date=short "$best_ref"..HEAD -- "$file"
		fi
	done < <(git -C "$TEMPLATE" ls-files scripts/autoloads scripts/util scripts/ui | grep -vE '\.uid$')
	rm -f "$tmp"
	echo "kit: $behind_total Template commit(s) to consider across the kit"
	exit 0
fi

# A dirty source would stamp a commit the copied files do not match.
if [[ "$MODE" != "--check" ]] && [[ -n "$(git -C "$SRC" status --porcelain -- "${OWNED[@]}")" ]]; then
	echo "sync-tooling: Kombucha has uncommitted changes to owned files — commit them first" >&2
	exit 2
fi

# Non-comment lines of a diff, one side: what a project ADDED to a file
# (">") or removed from it ("<") beyond a given version of it.
added_lines() { diff "$1" "$2" | grep -E "^$3" | grep -vE "^$3\s*(#|$)" || true; }

# The version of an owned file a project's copy is closest to, searched
# across Kombucha's history and the Template's: a project scaffolded months
# ago diverged from THAT file, and measuring against today's copy would
# count every Kombucha improvement as the project's drift.
explain_drift() { # entry
	local entry="$1" best=999999 best_ref="" best_repo="" tmp
	tmp="$(mktemp)"
	for repo in "$SRC" "$TEMPLATE"; do
		[[ -d "$repo/.git" ]] || continue
		while read -r commit; do
			git -C "$repo" show "$commit:$entry" > "$tmp" 2>/dev/null || continue
			local n
			n=$(( $(added_lines "$tmp" "$DEST/$entry" '>' | wc -l) + $(added_lines "$tmp" "$DEST/$entry" '<' | wc -l) ))
			if (( n < best )); then best=$n; best_ref="$commit"; best_repo="$repo"; fi
		done < <(git -C "$repo" log --format=%H -- "$entry")
	done
	if [[ -z "$best_ref" ]]; then
		echo "  drift  $entry"
		rm -f "$tmp"; return
	fi
	git -C "$best_repo" show "$best_ref:$entry" > "$tmp"
	local plus minus
	plus=$(added_lines "$tmp" "$DEST/$entry" '>' | wc -l)
	minus=$(added_lines "$tmp" "$DEST/$entry" '<' | wc -l)
	printf '  drift  %s  +%d -%d lines beyond %s@%s\n' "$entry" "$plus" "$minus" \
		"$(basename "$best_repo")" "$(git -C "$best_repo" rev-parse --short "$best_ref")"
	if [[ $SHOW_DIFF -eq 1 ]]; then
		added_lines "$tmp" "$DEST/$entry" '[<>]' | sed 's/^/         /'
	fi
	rm -f "$tmp"
}

drift=0
for entry in "${OWNED[@]}"; do
	if [[ "$entry" == */ ]]; then
		if [[ -d "$DEST/$entry" ]]; then
			diff -rq "$SRC/$entry" "$DEST/$entry" >/dev/null 2>&1 || { echo "  drift  $entry"; drift=1; }
		else
			echo "  new    $entry"; drift=1
		fi
	elif [[ -f "$DEST/$entry" ]]; then
		if ! cmp -s "$SRC/$entry" "$DEST/$entry"; then
			drift=1
			if [[ "$MODE" == "--check" ]]; then explain_drift "$entry"; else echo "  drift  $entry"; fi
		fi
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

# The tooling rules are one owned text (docs/godot-tooling.md) that a
# project's CLAUDE.md imports; without the import line the project reads
# stale rules from before the ownership split.
if [[ -f "$DEST/CLAUDE.md" ]] && ! grep -q '^@docs/godot-tooling.md' "$DEST/CLAUDE.md"; then
	echo "note: CLAUDE.md does not import the tooling rules — replace its tooling sections with a line reading @docs/godot-tooling.md"
fi

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
