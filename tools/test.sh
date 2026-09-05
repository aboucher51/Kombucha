#!/usr/bin/env bash
# Runs the GUT test suite headless.
#
#   tools/test.sh                    all tests
#   tools/test.sh test_smoke         one script (name or path fragment)
#
# Unlike tools/shoot.sh this needs no display — everything under tests/ is
# pure logic by design. Anything needing a rendered frame belongs in a
# scenario instead.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARGS=(-s addons/gut/gut_cmdln.gd)
if [[ $# -gt 0 ]]; then
	MATCH="$(basename "$1" .gd)"
	ARGS+=("-gselect=${MATCH}")
fi

LOG="$(mktemp)"
timeout "${TEST_TIMEOUT:-180}" godot4 --headless --path "$ROOT" "${ARGS[@]}" >"$LOG" 2>&1
STATUS=$?
# GUT paints its summary; strip the reset codes that survive grep-free output.
sed -E 's/\x1b\[0m$//' "$LOG"
rm -f "$LOG"

if [[ $STATUS -eq 124 ]]; then
	echo "test: timed out — a test is probably awaiting something that never comes" >&2
fi
exit $STATUS
