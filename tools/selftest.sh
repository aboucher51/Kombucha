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
#   2. the sharded run and the single-process run count the same tests;
#   3. the sync script stamps, seeds, sets the execute bit, reports drift
#      (with the project's own lines), notes a missing CLAUDE.md import,
#      and refuses a dirty source — against a scratch source and project.
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

# 3. The sync script. A scratch SOURCE (the working tree committed into a
#    fresh repo, so the script under test is this one and HEAD is known)
#    and a scratch PROJECT (a copy with one owned file edited, the stamp
#    and seeds removed, an execute bit dropped, and a CLAUDE.md without
#    the import).
SRC2="$(mktemp -d)"; DEST2="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" "$SRC2" "$DEST2"' EXIT
rsync -a --exclude '.git' --exclude '.godot' --exclude 'shots/*.png' "$ROOT/" "$SRC2/"
git -C "$SRC2" init -q -b main && git -C "$SRC2" -c user.name=selftest -c user.email=selftest@example.invalid add -A >/dev/null \
	&& git -C "$SRC2" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm scratch
rsync -a --exclude '.git' --exclude '.godot' "$SRC2/" "$DEST2/"
rm -f "$DEST2/tools/TOOLING_VERSION" "$DEST2/tools/check.local.sh" "$DEST2/scripts/dev/dev_hooks.gd" "$DEST2/data/console_commands.project.json"
printf '\n# a project-local edit that a sync must report\nPROJECT_EDIT=1\n' >> "$DEST2/tools/check.sh"
chmod -x "$DEST2/tools/test.sh"
printf '# a project\n' > "$DEST2/CLAUDE.md"
OUT="$(GODOT_TEMPLATE=/nonexistent "$SRC2/tools/sync-tooling.sh" "$DEST2" --check --diff 2>&1)"; CODE=$?
if [[ $CODE -ne 0 ]] && grep -qE 'drift  tools/check.sh  \+1 -0 lines beyond' <<<"$OUT" && grep -q 'PROJECT_EDIT=1' <<<"$OUT"; then
	say ok "sync --check --diff names the drifted file and the project's line"
else
	say FAIL "sync --check --diff did not report the edit (exit $CODE): $(head -3 <<<"$OUT")"; FAILED=1
fi
OUT="$(GODOT_TEMPLATE=/nonexistent "$SRC2/tools/sync-tooling.sh" "$DEST2" --no-check 2>&1)"; CODE=$?
HEAD2="$(git -C "$SRC2" rev-parse HEAD)"
if [[ $CODE -eq 0 && "$(head -1 "$DEST2/tools/TOOLING_VERSION")" == "$HEAD2" && -f "$DEST2/tools/check.local.sh" \
		&& -f "$DEST2/scripts/dev/dev_hooks.gd" && -x "$DEST2/tools/test.sh" ]] \
		&& ! grep -q PROJECT_EDIT "$DEST2/tools/check.sh" && grep -q 'does not import' <<<"$OUT"; then
	say ok "sync stamps HEAD, seeds, sets +x, overwrites drift, notes the missing import"
else
	say FAIL "sync did not do all of stamp/seed/+x/overwrite/note (exit $CODE)"; FAILED=1
fi
if "$SRC2/tools/sync-tooling.sh" "$DEST2" --check >/dev/null 2>&1; then
	say ok "sync --check is clean after a sync"
else
	say FAIL "sync --check still reports drift after a sync"; FAILED=1
fi
echo "# dirty" >> "$SRC2/tools/shoot.sh"
if "$SRC2/tools/sync-tooling.sh" "$DEST2" --no-check >/dev/null 2>&1; then
	say FAIL "sync accepted a source with uncommitted owned changes"; FAILED=1
else
	say ok "sync refuses a dirty source"
fi
exit $FAILED
