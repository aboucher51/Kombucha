#!/usr/bin/env bash
# Everything that can say "this build is broken", in one command.
#
#   tools/check.sh              tests + a plain boot + local checks + scenarios
#   tools/check.sh --quick      everything that needs no display
#   tools/check.sh --ci         everything, with scenarios on a virtual
#                               display (SHOOT_DISPLAY=xvfb) and CHECK_CI=1
#                               for check.local.sh
#
# Exits non-zero if anything fails, and prints a summary naming what did.
# Scenarios need a display (WSLg); --quick is the headless-only subset.
# GODOT=/path/to/binary picks the engine (booting through WSL's /mnt/c
# bridge costs seconds per process; a native or Windows binary does not).
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt) and overwritten by
# /sync-godot-tooling. Project-specific checks go in tools/check.local.sh,
# which runs between the boot and the scenarios and is never synced over.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
GODOT="${GODOT:-godot4}"
export GODOT

QUICK=0
CI_MODE=0
for arg in "$@"; do
	case "$arg" in
		--quick) QUICK=1 ;;
		--ci) CI_MODE=1; export SHOOT_DISPLAY=xvfb ;;
		*) echo "usage: tools/check.sh [--quick|--ci]" >&2; exit 2 ;;
	esac
done
export CHECK_CI=$CI_MODE

# Where the project lives is the single biggest cost of the whole loop:
# through WSL's /mnt/c bridge a real project boots in ~11 s per process,
# from the Linux filesystem in under a second (measured on a 428 MB game:
# 10.8 s vs 0.8 s). Every test shard, boot check and scenario shard pays it.
if [[ "$ROOT" == /mnt/* ]]; then
	echo "note: this checkout is on /mnt — a clone under the Linux filesystem boots ~10x faster (or point GODOT at a Windows binary)"
fi

FAILED=()
pass_or_fail() { # name, status
	if [[ $2 -eq 0 ]]; then printf '  ok    %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; FAILED+=("$1"); fi
}

echo "── scripts ──"
# Git records the execute bit, and a filesystem that does not honour modes
# (WSL's /mnt/c, Git Bash) makes every file look executable, so a script
# committed without the bit works everywhere until the checkout lands on a
# real filesystem: then this very script is "Permission denied", and a
# non-executable check.local.sh below would read as "no local checks".
# Fix: chmod +x <file> && git update-index --chmod=+x <file>.
NOEXEC=()
for script in tools/*.sh; do
	[[ -x "$script" ]] || NOEXEC+=("$script")
done
[[ ${#NOEXEC[@]} -eq 0 ]]
pass_or_fail "tool scripts executable${NOEXEC[*]:+ (missing +x: ${NOEXEC[*]})}" $?

# The project map (godot-map, its own repo) is committed so a checkout
# reads without the tool. With the tool here a stale map is a failure:
# Claude reads PROJECT_MAP.md first, and a wrong map sends it to a node
# that moved. No map at all is a note — adopting it is one command.
echo "── map ──"
if ! command -v godot-map >/dev/null 2>&1; then
	printf '  --    project map (godot-map not installed: uv tool install --editable ~/godot-projects/godot-map)\n'
elif [[ ! -f PROJECT_MAP.md ]]; then
	printf '  --    no project map yet (run godot-map . and commit PROJECT_MAP.md + .godot-map/)\n'
else
	OUT="$(godot-map . --check 2>&1)"
	STATUS=$?
	if [[ $STATUS -eq 0 ]]; then
		printf '  ok    project map up to date\n'
	else
		printf '%s\n' "$OUT" | sed 's/^/        /'
		pass_or_fail "project map (run godot-map . and commit)" $STATUS
	fi
fi


echo "── tests ──"
OUT="$(tools/test.sh 2>&1)"; STATUS=$?
printf '  %s\n' "$(grep -E 'Passing Tests|Failing Tests' <<<"$OUT" | tr -s ' ' | paste -sd'  ' -)"
[[ $STATUS -ne 0 ]] && printf '%s\n' "$OUT" | tail -30
pass_or_fail "unit tests" $STATUS

echo "── boot ──"
# Exit 124 is success here: the game ran the full duration without crashing.
# Peak RSS is measured at the same time, to catch something loading the
# world eagerly at startup — invisible to every other check here.
LOG="$(mktemp)"
RSS_KB=0
# GNU time is not everywhere (Git Bash on Windows, ubuntu-latest), and a
# missing measuring tool must not read as a failing boot — the boot is
# still checked, the budget is simply skipped.
if [[ -x /usr/bin/time ]]; then
	/usr/bin/time -f "%M" -o "$LOG.rss" timeout 8 "$GODOT" --headless --path "$ROOT" >"$LOG" 2>&1
	BOOT=$?
	RSS_KB=$(tail -1 "$LOG.rss" 2>/dev/null || echo 0)
else
	timeout 8 "$GODOT" --headless --path "$ROOT" >"$LOG" 2>&1
	BOOT=$?
fi
# Shader compile errors are not SCRIPT ERRORs; software GL surfaces ones a
# GPU driver forgives.
ERRORS=$(grep -cE "SCRIPT ERROR|Parse Error|shader" "$LOG")
[[ $BOOT -ne 124 || $ERRORS -ne 0 ]] && cat "$LOG"
rm -f "$LOG" "$LOG.rss"
[[ $BOOT -eq 124 && $ERRORS -eq 0 ]]
pass_or_fail "headless boot (clean, $ERRORS engine errors)" $?

# Generous headroom over what a healthy boot uses: this catches eager
# loading, not normal growth. Raise CHECK_RSS_BUDGET_KB as the game does.
BUDGET_KB=${CHECK_RSS_BUDGET_KB:-400000}
if [[ $RSS_KB -gt 0 ]]; then
	[[ $RSS_KB -lt $BUDGET_KB ]]
	pass_or_fail "boot memory $(( RSS_KB / 1024 )) MB (budget $(( BUDGET_KB / 1024 )) MB)" $?
else
	printf '  --    boot memory (no /usr/bin/time here to measure it)\n'
fi

# The project's own checks (sims, balance gates, linters). It prints lines
# in the same shape and its exit code is the verdict; QUICK tells it whether
# a display is available.
# A present but non-executable file is a FAILURE, not "no local checks":
# skipping it silently would drop the project's gates from the verdict.
if [[ -f tools/check.local.sh ]]; then
	echo "── local ──"
	if [[ -x tools/check.local.sh ]]; then
		QUICK=$QUICK tools/check.local.sh
		pass_or_fail "local checks (tools/check.local.sh)" $?
	else
		pass_or_fail "local checks (tools/check.local.sh is not executable)" 1
	fi
fi

if [[ $QUICK -eq 0 ]]; then
	shopt -s nullglob
	SCENARIOS=(scenarios/*.txt)
	echo "── scenarios ──"
	if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
		printf '  ok    no scenarios yet\n'
	else
		# No pinned SHOOT_TIMEOUT: shoot.sh scales its own budget with the
		# scenario count, and a pinned 300 broke two projects the day their
		# suites grew past ~45 scenarios.
		OUT="$(SHOOT_SEED=${SHOOT_SEED:-1} tools/shoot.sh "${SCENARIOS[@]}" 2>&1)"
		STATUS=$?
		if [[ $STATUS -eq 0 ]]; then
			printf '  ok    %d scenario(s)\n' "${#SCENARIOS[@]}"
			printf '%s\n' "$OUT" | grep -E '^scenario ok:' | sed 's/^scenario ok: /        /'
			printf '%s\n' "$OUT" | grep -m1 '^harness: renderer' | sed 's/^harness: /        /'
			# The frame-time budget rides inside the scenario run; going over
			# fails that scenario like any other assertion. Surfacing the
			# number here too is what makes the TREND legible.
			echo "── frames ──"
			FRAMES="$(printf '%s\n' "$OUT" | grep -m1 'frames:' || true)"
			if [[ -n "$FRAMES" ]]; then
				printf '  ok    %s\n' "${FRAMES#*frames: }"
				printf '  note  a regression tripwire on this renderer, not a device target\n'
			else
				printf '  --    no frame measurement in this run\n'
			fi
		else
			printf '%s\n' "$OUT" | tail -20
			pass_or_fail "scenarios" $STATUS
		fi
	fi
fi

# A nudge, never a failure: the tooling here is a copy of Kombucha's, and
# a stale copy quietly misses the fixes every other project already has.
# Only commits that touched an owned path count, so unrelated Kombucha
# work does not nag.
# Where the copy came from: GODOT_TOOLING, else the path the last sync
# stamped ("synced <date> from <dir>", the plugin checkout as a rule).
TOOLING_SRC="${GODOT_TOOLING:-}"
if [[ -z "$TOOLING_SRC" && -f tools/TOOLING_VERSION ]]; then
	TOOLING_SRC="$(sed -n '2s/^synced .* from //p' tools/TOOLING_VERSION)"
fi
if [[ -n "$TOOLING_SRC" && -f tools/TOOLING_VERSION && -f tools/tooling-manifest.txt \
		&& -d "$TOOLING_SRC/.git" && "$ROOT" != "$TOOLING_SRC" ]]; then
	SYNCED="$(head -1 tools/TOOLING_VERSION)"
	mapfile -t OWNED < <(grep -vE '^\s*(#|$)' tools/tooling-manifest.txt)
	BEHIND="$(git -C "$TOOLING_SRC" rev-list --count "$SYNCED"..HEAD -- "${OWNED[@]}" 2>/dev/null || echo "?")"
	if [[ "$BEHIND" == "?" ]]; then
		echo "note: tools/TOOLING_VERSION names a commit Kombucha does not have"
	elif [[ "$BEHIND" -gt 0 ]]; then
		echo "note: tooling is $BEHIND Kombucha commit(s) behind — run /sync-godot-tooling"
	fi
fi

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
	echo "check: all green"
	exit 0
fi
echo "check: ${#FAILED[@]} failure(s): ${FAILED[*]}" >&2
exit 1
