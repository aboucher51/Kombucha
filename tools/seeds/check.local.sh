#!/usr/bin/env bash
# Project-specific checks, run by tools/check.sh between the headless boot
# and the scenarios. This file is yours; check.sh is owned by Kombucha.
#
# Print one `  ok    <name>` / `  FAIL  <name>` line per check and exit
# non-zero if any failed. QUICK=1 means no display is available.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
FAILED=0

# ── the target screens ─────────────────────────────────────────────────────
# Name the sizes the game must fit (a Steam Deck, 1080p, an ultrawide) and
# run one layout scenario (`assert_zone` lines, `window` first) at each.
# The window manager may refuse a size (WSLg does above its virtual
# screen): the scenario's `window` reply is the size it GOT, and a refused
# size reads as `--` with that size, never as a silent pass. A HUD bar that
# fit at 1280 was off the right edge the moment a button was added, and
# only a named size caught it. Uncomment and name your scenario.
#if [[ "${QUICK:-0}" != "1" ]]; then
#	for size in 1280x800 1920x1080 3440x1440; do
#		if SHOOT_RESOLUTION="$size" SHOOT_JOBS=1 SHOOT_KEEP=1 tools/shoot.sh scenarios/layout.txt > ".godot/layout_$size.log" 2>&1; then
#			got="$(grep -o '"reply": *"window [0-9x]*"' shots/layout.jsonl 2>/dev/null | grep -o '[0-9]*x[0-9]*' | head -1)"
#			if [[ "$got" == "$size" ]]; then
#				printf '  ok    layout at %s\n' "$size"
#			else
#				printf '  --    layout at %s (the window manager gave %s; rules checked at that size)\n' "$size" "${got:-?}"
#			fi
#		else
#			printf '  FAIL  layout at %s (see .godot/layout_%s.log)\n' "$size" "$size"; FAILED=1
#		fi
#	done
#else
#	printf '  --    layout at the target sizes (no display)\n'
#fi

exit $FAILED
