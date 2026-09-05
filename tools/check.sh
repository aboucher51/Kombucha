#!/usr/bin/env bash
# Everything that can say "this build is broken", in one command.
#
#   tools/check.sh              tests + a plain boot + every scenario
#   tools/check.sh --quick      tests + a plain boot (no display needed)
#
# Exits non-zero if anything fails, and prints a summary naming what did.
# Scenarios need a display (WSLg); --quick is the headless-only subset.
#
# OWNED BY MICROBIOME (tools/tooling-manifest.txt) and overwritten by
# /sync-godot-tooling. Project-specific checks go in tools/check.local.sh,
# which runs between the boot and the scenarios and is never synced over.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

FAILED=()
pass_or_fail() { # name, status
	if [[ $2 -eq 0 ]]; then printf '  ok    %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; FAILED+=("$1"); fi
}

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
/usr/bin/time -f "%M" -o "$LOG.rss" timeout 8 godot4 --headless --path "$ROOT" >"$LOG" 2>&1
BOOT=$?
ERRORS=$(grep -cE "SCRIPT ERROR|Parse Error" "$LOG")
RSS_KB=$(tail -1 "$LOG.rss" 2>/dev/null || echo 0)
[[ $BOOT -ne 124 || $ERRORS -ne 0 ]] && cat "$LOG"
rm -f "$LOG" "$LOG.rss"
[[ $BOOT -eq 124 && $ERRORS -eq 0 ]]
pass_or_fail "headless boot (clean, $ERRORS engine errors)" $?

# Generous headroom over what a healthy boot uses: this catches eager
# loading, not normal growth. Raise CHECK_RSS_BUDGET_KB as the game does.
BUDGET_KB=${CHECK_RSS_BUDGET_KB:-400000}
[[ $RSS_KB -gt 0 && $RSS_KB -lt $BUDGET_KB ]]
pass_or_fail "boot memory $(( RSS_KB / 1024 )) MB (budget $(( BUDGET_KB / 1024 )) MB)" $?

# The project's own checks (sims, balance gates, linters). It prints lines
# in the same shape and its exit code is the verdict; QUICK tells it whether
# a display is available.
if [[ -x tools/check.local.sh ]]; then
	echo "── local ──"
	QUICK=$QUICK tools/check.local.sh
	pass_or_fail "local checks (tools/check.local.sh)" $?
fi

if [[ $QUICK -eq 0 ]]; then
	shopt -s nullglob
	SCENARIOS=(scenarios/*.txt)
	echo "── scenarios ──"
	if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
		printf '  ok    no scenarios yet\n'
	else
		OUT="$(SHOOT_SEED=${SHOOT_SEED:-1} SHOOT_TIMEOUT=${SHOOT_TIMEOUT:-300} \
			tools/shoot.sh "${SCENARIOS[@]}" 2>&1)"
		STATUS=$?
		if [[ $STATUS -eq 0 ]]; then
			printf '  ok    %d scenario(s)\n' "${#SCENARIOS[@]}"
		else
			printf '%s\n' "$OUT" | tail -20
			pass_or_fail "scenarios" $STATUS
		fi
	fi
fi

# A nudge, never a failure: the tooling here is a copy of Microbiome's, and
# a stale copy quietly misses the fixes every other project already has.
# Only commits that touched an owned path count, so unrelated Microbiome
# work does not nag.
TOOLING_SRC="${GODOT_TOOLING:-/mnt/c/Users/Alex/godot-projects/Microbiome}"
if [[ -f tools/TOOLING_VERSION && -f tools/tooling-manifest.txt \
		&& -d "$TOOLING_SRC/.git" && "$ROOT" != "$TOOLING_SRC" ]]; then
	SYNCED="$(head -1 tools/TOOLING_VERSION)"
	mapfile -t OWNED < <(grep -vE '^\s*(#|$)' tools/tooling-manifest.txt)
	BEHIND="$(git -C "$TOOLING_SRC" rev-list --count "$SYNCED"..HEAD -- "${OWNED[@]}" 2>/dev/null || echo "?")"
	if [[ "$BEHIND" == "?" ]]; then
		echo "note: tools/TOOLING_VERSION names a commit Microbiome does not have"
	elif [[ "$BEHIND" -gt 0 ]]; then
		echo "note: tooling is $BEHIND Microbiome commit(s) behind — run /sync-godot-tooling"
	fi
fi

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
	echo "check: all green"
	exit 0
fi
echo "check: ${#FAILED[@]} failure(s): ${FAILED[*]}" >&2
exit 1
