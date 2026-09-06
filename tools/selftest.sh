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
#      and refuses a dirty source — against a scratch source and project;
#   4. a plain engine `ERROR:` line (a ConfigFile key with no default, a
#      freed lambda capture) turns the boot gate and the scenario gate
#      red — 738 of them once sat under an all-green check.
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

# 2b. A named run is EXACTLY what was named — an exact name beats a
#     prefix (`test_campaign` used to drag in `test_campaign_flow`, and
#     the verdict was the union) — and several names run in one process.
printf 'extends GutTest\nfunc test_sibling() -> void:\n\tassert_true(true)\n' > "$SCRATCH/tests/test_smoke_sibling.gd"
OUT="$(cd "$SCRATCH" && tools/test.sh test_smoke 2>&1)"
if grep -q '^Ran 1 script(s): test_smoke.gd$' <<<"$OUT"; then
	say ok "an exact name runs one script, not its prefix siblings"
else
	say FAIL "a named run dragged in a sibling ($(grep -m1 '^Ran ' <<<"$OUT"))"; FAILED=1
fi
OUT="$(cd "$SCRATCH" && tools/test.sh test_smoke test_cmdline 2>&1)"
if grep -q '^Ran 2 script(s):' <<<"$OUT" && grep -q 'test_cmdline.gd' <<<"$OUT"; then
	say ok "several named scripts run in one process"
else
	say FAIL "several names did not run together"; FAILED=1
fi
rm -f "$SCRATCH/tests/test_smoke_sibling.gd"

# 2c. A failing assertion is repeated where it can be read: GUT prints it
#     hundreds of lines above its own summary.
cp "$SCRATCH/tests/test_smoke.gd" "$SCRATCH/smoke.bak"
printf '\n\nfunc test_planted_for_the_selftest() -> void:\n\tassert_eq(2 + 2, 5, "planted by the selftest")\n' >> "$SCRATCH/tests/test_smoke.gd"
OUT="$(cd "$SCRATCH" && tools/test.sh test_smoke 2>&1)"
if grep -q 'failing assertions' <<<"$OUT" && grep -q 'planted by the selftest' <<<"$OUT"; then
	say ok "a red run repeats its failing assertion"
else
	say FAIL "a red run did not repeat its failing assertion"; FAILED=1
fi
mv "$SCRATCH/smoke.bak" "$SCRATCH/tests/test_smoke.gd"

# 2d. A parse error is LOCATED. The engine names the class and never the
#     file, in every log, and finding it cost a round trip per guess.
cp "$SCRATCH/scripts/util/save_compat.gd" "$SCRATCH/save_compat.bak"
printf '\n\nfunc _selftest_broken() -> void:\n\tvar x = 1 if true\n' >> "$SCRATCH/scripts/util/save_compat.gd"
OUT="$(cd "$SCRATCH" && tools/test.sh test_smoke 2>&1)"
if grep -qE 'parse error: scripts/util/save_compat\.gd:[0-9]+' <<<"$OUT"; then
	say ok "a parse error is named by file and line"
else
	say FAIL "a parse error was not located past 'could not resolve class'"; FAILED=1
fi
mv "$SCRATCH/save_compat.bak" "$SCRATCH/scripts/util/save_compat.gd"

# 4. A gate must be proven able to fail: plant one plain engine ERROR in
#    the scratch copy's boot scene and watch both gates go red on it. The
#    scratch's test runner and local check are stubbed for this run: the
#    suite was just proven above, and the local check is THIS script.
printf '\n\nfunc _plant_engine_error() -> void:\n\tConfigFile.new().get_value("no", "such_key")\n' >> "$SCRATCH/scripts/main.gd"
sed -i 's/^\t_build_rows()$/\t_build_rows()\n\t_plant_engine_error()/' "$SCRATCH/scripts/main.gd"
printf '#!/usr/bin/env bash\necho "Passing Tests 0"\n' > "$SCRATCH/tools/test.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SCRATCH/tools/check.local.sh"
OUT="$(cd "$SCRATCH" && tools/check.sh --quick 2>&1)"; CODE=$?
if [[ $CODE -ne 0 ]] && grep -qE 'FAIL +headless boot \(clean, [1-9][0-9]* engine errors\)' <<<"$OUT"; then
	say ok "boot gate is red on a plain engine ERROR line"
else
	say FAIL "boot gate stayed green on a plain engine ERROR line (exit $CODE)"; FAILED=1
fi
if [[ "${QUICK:-0}" -eq 0 ]]; then
	# TWO scenarios: the boot error falls before the first header, so a
	# one-scenario run cannot prove that an error is placed by scenario.
	OUT="$(cd "$SCRATCH" && SHOOT_JOBS=1 tools/shoot.sh scenarios/example.txt scenarios/console.txt 2>&1)"; CODE=$?
	if [[ $CODE -ne 0 ]] && grep -q 'engine error(s)' <<<"$OUT"; then
		say ok "scenario gate is red on a plain engine ERROR line"
	else
		say FAIL "scenario gate stayed green on a plain engine ERROR line (exit $CODE)"; FAILED=1
	fi
	# ...and the error is placed: an unattributed one cost four minutes of
	# re-running a batch to learn which scenario raised it.
	if grep -qE '^  scenarios/[a-z_]+\.txt: ' <<<"$OUT"; then
		say ok "an engine error is named by its scenario"
	else
		say FAIL "an engine error was reported without its scenario"; FAILED=1
	fi
else
	say -- "scenario gate on an engine ERROR line (no display)"
fi

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
# 3b. The scaffolder, from the scratch source: Kombucha-only paths stay
#     behind, the fenced sections are gone, the project is named, stamped
#     and committed once.
DEST3="$(mktemp -d)/Scaffolded"
trap 'rm -rf "$SCRATCH" "$SRC2" "$DEST2" "$(dirname "$DEST3")"' EXIT
OUT="$("$SRC2/tools/new-project.sh" "$DEST3" "Self Test" --no-check 2>&1)"; CODE=$?
if [[ $CODE -eq 0 && -f "$DEST3/tools/TOOLING_VERSION" && -f "$DEST3/scripts/dev/dev_hooks.gd" \
		&& ! -e "$DEST3/skills" && ! -e "$DEST3/.claude-plugin" && ! -e "$DEST3/tools/selftest.sh" \
		&& ! -e "$DEST3/tests/test_dev_hooks.gd" && ! -e "$DEST3/scenarios/hooks.txt" \
		&& ! -e "$DEST3/docs/roadmap.md" && ! -e "$DEST3/docs/feedback" ]] \
		&& ! grep -q 'What this repo is' "$DEST3/CLAUDE.md" && ! grep -q 'kombucha-only' "$DEST3/CLAUDE.md" \
		&& grep -q 'docs/godot-tooling.md' "$DEST3/CLAUDE.md" && ! grep -q 'itself is MIT' "$DEST3/LICENSES.md" \
		&& grep -q 'config/name="Self Test"' "$DEST3/project.godot" && ! grep -q SelftestDriver "$DEST3/project.godot" \
		&& [[ "$(git -C "$DEST3" rev-list --count HEAD)" == "1" ]] && [[ -z "$(git -C "$DEST3" status --porcelain)" ]]; then
	say ok "new-project.sh scaffolds a named, stamped, committed project without the Kombucha-only paths"
else
	say FAIL "new-project.sh scaffold is wrong (exit $CODE): $(tail -3 <<<"$OUT")"; FAILED=1
fi

echo "# dirty" >> "$SRC2/tools/shoot.sh"
if "$SRC2/tools/sync-tooling.sh" "$DEST2" --no-check >/dev/null 2>&1; then
	say FAIL "sync accepted a source with uncommitted owned changes"; FAILED=1
else
	say ok "sync refuses a dirty source"
fi
# 4. An installed plugin is the source without .git: the stamp must be
#    the sha Claude Code recorded for that install, never "unknown".
rm -rf "$SRC2/.git"
PLUGINS_JSON="$(mktemp)"
printf '{"version":2,"plugins":{"kombucha@kombucha":[{"installPath":"%s","gitCommitSha":"feedfacefeedfacefeedfacefeedfacefeedface"}]}}\n' "$SRC2" > "$PLUGINS_JSON"
OUT="$(GODOT_TEMPLATE=/nonexistent INSTALLED_PLUGINS_JSON="$PLUGINS_JSON" "$SRC2/tools/sync-tooling.sh" "$DEST2" --no-check 2>&1)"; CODE=$?
rm -f "$PLUGINS_JSON"
if [[ $CODE -eq 0 && "$(head -1 "$DEST2/tools/TOOLING_VERSION")" == "feedfacefeedfacefeedfacefeedfacefeedface" ]]; then
	say ok "a git-less plugin source stamps the installed sha"
else
	say FAIL "a git-less source stamped '$(head -1 "$DEST2/tools/TOOLING_VERSION" 2>/dev/null)' (exit $CODE): $(tail -2 <<<"$OUT")"; FAILED=1
fi
exit $FAILED
