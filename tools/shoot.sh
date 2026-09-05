#!/usr/bin/env bash
# Runs screenshot scenarios and reports where the PNGs landed.
#
#   tools/shoot.sh                        all of scenarios/*.txt
#   tools/shoot.sh scenarios/example.txt  just one
#
# Optional env vars:
#   SHOOT_RESOLUTION=1280x720   window size (layout bugs are often
#                               height-dependent — check more than one)
#   SHOOT_SEED=1                repeatable randomness, so two runs of the
#                               same scenario are actually comparable
#   SHOOT_TIMEOUT=<n>           seconds before giving up (default scales
#                               with the batch: 30 + 10 per scenario)
#   SHOOT_KEEP=1                keep existing shots instead of clearing
#
# Needs a display — under WSL that means WSLg (DISPLAY=:0). Headless cannot
# be used: --headless has no renderer, so the viewport texture would come
# back blank.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCENARIOS=("$@")
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
	shopt -s nullglob
	SCENARIOS=(scenarios/*.txt)
fi
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
	echo "usage: tools/shoot.sh [<scenario-file> ...]" >&2
	exit 2
fi
for scenario in "${SCENARIOS[@]}"; do
	if [[ ! -f "$ROOT/$scenario" && ! -f "$scenario" ]]; then
		echo "shoot: no such scenario '$scenario'" >&2
		exit 2
	fi
done

# The watchdog exists for error loops, not to cap honest work — the budget
# scales with the batch so a growing suite is not killed mid-scenario.
TIMEOUT="${SHOOT_TIMEOUT:-$((30 + 10 * ${#SCENARIOS[@]}))}"

export DISPLAY="${DISPLAY:-:0}"
[[ -z "${SHOOT_KEEP:-}" ]] && rm -f "$ROOT"/shots/*.png 2>/dev/null

GODOT_ARGS=(--path "$ROOT")
[[ -n "${SHOOT_RESOLUTION:-}" ]] && GODOT_ARGS+=(--resolution "$SHOOT_RESOLUTION")
# Every scenario goes to ONE process: booting Godot dominates the cost.
HARNESS_ARGS=()
for scenario in "${SCENARIOS[@]}"; do HARNESS_ARGS+=(--scenario "$scenario"); done
[[ -n "${SHOOT_SEED:-}" ]] && HARNESS_ARGS+=(--seed "$SHOOT_SEED")

# Piping godot's stdout swallows it; redirect to a file and read afterwards.
# The log is only ever grepped, never slurped into a variable — an engine
# stuck in an error loop can write hundreds of MB inside the timeout.
LOG="$(mktemp)"
timeout "$TIMEOUT" godot4 "${GODOT_ARGS[@]}" -- "${HARNESS_ARGS[@]}" >"$LOG" 2>&1
STATUS=$?

LOG_LIMIT="${SHOOT_LOG_LIMIT:-$((2 * 1024 * 1024))}"
LOG_SIZE=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
if [[ $LOG_SIZE -le $LOG_LIMIT ]]; then
	cat "$LOG"
	KEEP_LOG=""
else
	head -n 200 "$LOG"
	echo "  [... shoot: log truncated — $LOG_SIZE bytes, full log kept at $LOG ...]"
	tail -n 200 "$LOG"
	KEEP_LOG=1
fi

if [[ $STATUS -eq 124 ]]; then
	echo "shoot: timed out after ${TIMEOUT}s — scenario never reached its end" >&2
elif [[ $STATUS -ne 0 ]]; then
	echo "shoot: exited $STATUS" >&2
fi

# The harness only knows about failures its commands report back, so an
# engine-level error (a bad type, a null call) would otherwise let a run
# pass while the game was visibly broken behind the screenshots.
ENGINE_ERRORS=$(grep -cE "SCRIPT ERROR|Parse Error" "$LOG")
if [[ $ENGINE_ERRORS -gt 0 ]]; then
	echo "shoot: $ENGINE_ERRORS engine error(s) — a green scenario does not mean a clean run" >&2
	grep -E "SCRIPT ERROR|Parse Error" "$LOG" | sort -u | head -5 >&2
	[[ $STATUS -eq 0 ]] && STATUS=1
fi
[[ -z "${KEEP_LOG:-}" ]] && rm -f "$LOG"

shopt -s nullglob
SHOTS=("$ROOT"/shots/*.png)
echo "shoot: ${#SHOTS[@]} shot(s) in $ROOT/shots"
exit $STATUS
