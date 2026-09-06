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
# Run from Kombucha (this script's own repo: a clone, or the installed
# plugin), or from anywhere via the /sync-godot-tooling skill. Drift in an owned file means the project edited
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
TEMPLATE="${GODOT_TEMPLATE:-$HOME/godot-projects/Template}"
DEST="$(cd "$DEST" && pwd)"
if [[ "$DEST" == "$SRC" ]]; then
	echo "sync-tooling: '$DEST' is the source; nothing to sync" >&2
	exit 2
fi

mapfile -t OWNED < <(grep -vE '^\s*(#|$)' "$SRC/tools/tooling-manifest.txt")

# ── the kit report ────────────────────────────────────────────────────────
# Kit (autoloads, util, ui) lives here and travels by cherry-pick, because
# every game edits these files in place. The report answers, per file:
# which Kombucha version is this copy, what did the project add, and what
# has Kombucha done to the file since. A project scaffolded from the old
# Template repo is measured against that history too, where a clone of it
# exists ($GODOT_TEMPLATE); the source needs git either way.
if [[ "$MODE" == "--kit" ]]; then
	if [[ ! -d "$SRC/.git" ]]; then
		echo "sync-tooling: the kit report needs a clone of Kombucha with its history (set GODOT_TOOLING)" >&2
		exit 2
	fi
	repos=("$SRC")
	[[ -d "$TEMPLATE/.git" ]] && repos+=("$TEMPLATE")
	tmp="$(mktemp)"
	behind_total=0
	while read -r file; do
		# owned paths are synced, not cherry-picked
		printf '%s\n' "${OWNED[@]}" | grep -qxF "$file" && continue
		if [[ ! -f "$DEST/$file" ]]; then
			printf '  absent %s\n' "$file"
			continue
		fi
		best=999999; best_ref=""; best_repo=""
		for repo in "${repos[@]}"; do
			while read -r commit; do
				git -C "$repo" show "$commit:$file" > "$tmp" 2>/dev/null || continue
				n=$(diff "$tmp" "$DEST/$file" | grep -cE '^[<>]')
				if (( n < best )); then best=$n; best_ref="$commit"; best_repo="$repo"; fi
			done < <(git -C "$repo" log --format=%H -- "$file")
		done
		[[ -z "$best_ref" ]] && continue
		git -C "$best_repo" show "$best_ref:$file" > "$tmp"
		plus=$(diff "$tmp" "$DEST/$file" | grep -E '^>' | grep -vcE '^>\s*#')
		minus=$(diff "$tmp" "$DEST/$file" | grep -E '^<' | grep -vcE '^<\s*#')
		# What is newer: Kombucha's commits to the file since the version
		# the copy matches (all of them, when the match was in the Template).
		if [[ "$best_repo" == "$SRC" ]]; then
			newer=$(git -C "$SRC" rev-list --count "$best_ref"..HEAD -- "$file")
			since="$best_ref"
		else
			newer=$(git -C "$SRC" rev-list --count HEAD -- "$file")
			since=""
		fi
		behind_total=$(( behind_total + newer ))
		if (( newer == 0 && plus == 0 && minus == 0 )); then
			printf '  same   %s\n' "$file"
		else
			printf '  kit    %s  at %s@%s, own +%d -%d, %d newer Kombucha commit(s)\n' \
				"$file" "$(basename "$best_repo")" "$(git -C "$best_repo" rev-parse --short "$best_ref")" "$plus" "$minus" "$newer"
			git -C "$SRC" log --format='           %h %ad %s' --date=short ${since:+"$since"..HEAD} -- "$file"
		fi
	done < <(git -C "$SRC" ls-files scripts/autoloads scripts/util scripts/ui | grep -vE '\.uid$')
	rm -f "$tmp"
	echo "kit: $behind_total Kombucha commit(s) to consider across the kit"
	exit 0
fi

# The commit the source is at. A clone answers from git. An installed
# plugin is a checkout WITHOUT .git, so the answer is the sha Claude Code
# recorded when it installed it (installed_plugins.json, overridable for
# the self-test), else the manifest's version: the stamp must always say
# something a person can act on.
source_commit() {
	if [[ -d "$SRC/.git" ]]; then git -C "$SRC" rev-parse HEAD; return; fi
	local sha
	sha="$(python3 - "$SRC" "${INSTALLED_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}" <<-'PY' 2>/dev/null
		import json, os, sys
		src = os.path.realpath(sys.argv[1])
		for installs in json.load(open(sys.argv[2]))["plugins"].values():
		    for inst in installs:
		        if os.path.realpath(inst.get("installPath", "")) == src and inst.get("gitCommitSha"):
		            print(inst["gitCommitSha"]); raise SystemExit
	PY
	)"
	if [[ -n "$sha" ]]; then echo "$sha"; return; fi
	echo "plugin-$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$SRC/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)"
}

# A dirty source would stamp a commit the copied files do not match.
if [[ "$MODE" != "--check" && -d "$SRC/.git" ]] && [[ -n "$(git -C "$SRC" status --porcelain -- "${OWNED[@]}")" ]]; then
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

# What this sync PULLS, as headlines: the Kombucha commits between the
# project's old stamp and the new one, so the project knows which of its
# own notes ("blocked on the next sync") just went stale. Needs a source
# with history; a plugin install prints nothing here.
OLD_STAMP="$(head -1 "$DEST/tools/TOOLING_VERSION" 2>/dev/null || true)"
if [[ -d "$SRC/.git" && "$OLD_STAMP" =~ ^[0-9a-f]{40}$ ]] && git -C "$SRC" cat-file -e "$OLD_STAMP" 2>/dev/null; then
	PULLED="$(git -C "$SRC" log --oneline "$OLD_STAMP..HEAD" 2>/dev/null | head -30)"
	if [[ -n "$PULLED" ]]; then
		echo "pulled $(wc -l <<<"$PULLED") Kombucha commit(s) since ${OLD_STAMP:0:7}:"
		sed 's/^/  /' <<<"$PULLED"
	fi
fi

{
	source_commit
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
