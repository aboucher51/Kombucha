#!/usr/bin/env bash
# The tooling's own gate: proves tools/test.sh catches what it claims to,
# against a scratch copy of this project. Kombucha-only (the fixture's,
# not owned): a game project has nothing to prove here.
#
#   tools/selftest.sh      exit 0 when every guard fires and the shards agree
#
# What it checks, each of which has silently passed in a real project:
#   1. a test script that fails to PARSE makes the run red (GUT drops the
#      file and exits 0 on its own);
#   2. the sharded run and the single-process run count the same tests.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
FAILED=0
say() { printf '  %-5s %s\n' "$1" "$2"; }

# .godot comes along so the copy needs no import; shots and timings do not.
rsync -a --exclude 'shots/*.png' --exclude '.git' --exclude '.godot/test-timings' "$ROOT/" "$SCRATCH/"
count() { grep -E '^Tests ' | awk '{print $NF}'; }

# 1. A broken test file must turn the run red, in both modes.
printf 'extends GutTest\nfunc test_broken() -> void:\n\tthis is not gdscript\n' > "$SCRATCH/tests/test_zz_broken.gd"
for jobs in 1 2; do
	OUT="$(cd "$SCRATCH" && TEST_JOBS=$jobs tools/test.sh 2>&1)"; CODE=$?
	if [[ $CODE -ne 0 ]] && grep -q 'did not load' <<<"$OUT"; then
		say ok "broken test file is red (TEST_JOBS=$jobs)"
	else
		say FAIL "broken test file passed or was not named (TEST_JOBS=$jobs, exit $CODE)"; FAILED=1
	fi
done
rm -f "$SCRATCH/tests/test_zz_broken.gd" "$SCRATCH/tests/test_zz_broken.gd.uid"

# 2. Shards must agree with the single process on what ran.
ONE="$(cd "$SCRATCH" && TEST_JOBS=1 tools/test.sh 2>&1)"; ONE_CODE=$?
TWO="$(cd "$SCRATCH" && TEST_JOBS=2 tools/test.sh 2>&1)"; TWO_CODE=$?
if [[ $ONE_CODE -eq 0 && $TWO_CODE -eq 0 && -n "$(count <<<"$ONE")" && "$(count <<<"$ONE")" == "$(count <<<"$TWO")" ]]; then
	say ok "shards agree with one process ($(count <<<"$ONE") tests)"
else
	say FAIL "shard counts differ or a run failed (1: $(count <<<"$ONE") exit $ONE_CODE; 2: $(count <<<"$TWO") exit $TWO_CODE)"; FAILED=1
fi
[[ -f "$SCRATCH/.godot/test-timings" ]] && say ok "timings written for the next deal" || { say FAIL "no .godot/test-timings after a full run"; FAILED=1; }
exit $FAILED
