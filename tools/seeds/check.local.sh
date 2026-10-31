#!/usr/bin/env bash
# Project-specific checks. tools/check.sh runs this file between the
# headless boot and the scenarios. This file is yours. Kombucha owns check.sh.
#
# Print one `  ok    <name>` / `  FAIL  <name>` line per check. Exit
# non-zero if any check failed. QUICK=1 means no display is available.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

# ── which scenarios check.sh renders ───────────────────────────────────────
# check.sh first calls this file with `--scenarios`. Print the scenario
# paths to render, one per line, or the one word `none` to render nothing.
# Print nothing (or exit non-zero) to render all of scenarios/*.txt.
# check.sh then says "N of M scenario(s), chosen by tools/check.local.sh".
# A listed path that does not exist fails the check. Answer and exit here,
# before any check below, or every check runs twice.
if [[ "${1:-}" == "--scenarios" ]]; then
	exit 0
fi

FAILED=0

# ── the target screens ─────────────────────────────────────────────────────
# SCREEN_SIZES lists the sizes the game must fit (a Steam Deck, 1080p, an
# ultrawide). This block runs one layout scenario at each size: `window`
# first, then `assert_zone` lines. The window manager may refuse a size
# (WSLg does above its virtual screen). The scenario's `window` reply is
# the size the window manager gave. A refused size prints as `--` with that
# size, never as a silent pass. In one project a HUD bar fit at 1280, then
# went off the right edge when someone added a button. Only a named size
# caught it. Edit the sizes, and write the scenario.
SCREEN_SIZES="${SCREEN_SIZES:-1280x800 1920x1080 3440x1440}"
LAYOUT_SCENARIO="${LAYOUT_SCENARIO:-scenarios/layout.txt}"
if [[ ! -f "$LAYOUT_SCENARIO" ]]; then
	printf '  --    layout at the target sizes (no %s yet)\n' "$LAYOUT_SCENARIO"
elif [[ "${QUICK:-0}" != "1" ]]; then
	STEM="$(basename "$LAYOUT_SCENARIO" .txt)"
	for size in $SCREEN_SIZES; do
		if SHOOT_RESOLUTION="$size" SHOOT_JOBS=1 SHOOT_KEEP=1 tools/shoot.sh "$LAYOUT_SCENARIO" > ".godot/layout_$size.log" 2>&1; then
			got="$(grep -o '"reply": *"window [0-9x]*"' "shots/$STEM.jsonl" 2>/dev/null | grep -o '[0-9]*x[0-9]*' | head -1)"
			if [[ "$got" == "$size" ]]; then
				printf '  ok    layout at %s\n' "$size"
			else
				printf '  --    layout at %s (the window manager gave %s; rules checked at that size)\n' "$size" "${got:-?}"
			fi
		else
			printf '  FAIL  layout at %s (see .godot/layout_%s.log)\n' "$size" "$size"; FAILED=1
		fi
	done
else
	printf '  --    layout at the target sizes (no display)\n'
fi

exit $FAILED
